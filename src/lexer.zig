const std = @import("std");
const Allocator = std.mem.Allocator;

const Token = union(enum) {
    EOF: void,
    identifier: []const u8,

    // keywords
    initalizer: void,
    const_initalizer: void,
    keyword_if: void,
    keyword_else: void,
    keyword_while: void,
    keyword_for: void,
    keyword_return: void,
    keyword_fn: void,
    keyword_struct: void,

    // lits
    byte: u8,
    int: i64,
    float: f64,
    string: []const u8,
    boolean: bool,

    // type id
    byte_id: void,
    integer32_id: void,
    float32_id: void,
    integer64_id: void,
    float64_id: void,
    bool_id: void,
    string_id: void,

    // ops
    add: void,
    sub: void,
    mul: void,
    div: void,
    modulo: void,

    not: void,
    // _ for taken keywords
    _and: void,
    _or: void,

    bitwise_and: void,
    bitwise_or: void,
    bitwise_xor: void,
    bitwise_not: void,
    shift_left: void,
    shift_right: void,

    // assignment and compound
    eql: void,
    add_eql: void,
    sub_eql: void,
    mul_eql: void,
    div_eql: void,
    modulo_eql: void,
    increment: void,
    decrement: void,

    // comparison ops
    eql_eql: void,
    not_eql: void,
    greater: void,
    less: void,
    greater_eql: void,
    less_eql: void,

    // punc
    colon: void,
    semicolon: void,
    comma: void,
    dot: void,
    at: void,
    question: void,

    // brackets
    paren_o: void,
    paren_c: void,
    sq_brace_o: void,
    sq_brace_c: void,
    cu_brace_o: void,
    cu_brace_c: void,
};

const LexerError = error{
    Expected,
    InvalidNum,
};

const INITALIZER = "let";
const CONST_INITALIZER = "const";
const IF_KEYWORD = "if";
const ELSE_KEYWORD = "else";
const FN_KEYWORD = "fn";
const WHILE_KEYWORD = "while";
const FOR_KEYWORD = "for";
const RETURN_KEYWORD = "ret";
const STRUCT_KEYWORD = "struct";
const INT_ID = "int";
const FLOAT_ID = "float";
const BYTE_ID = "byte";
const STRING_ID = "str";
const BOOL_ID = "bool";


pub const Lexer = struct {
    src: []const u8,
    pos: usize = 0,
    allocator: Allocator,
    tok: Token = undefined,
    line: usize = 0,
    col: usize = 0,
    err_msg: ?[]const u8 = null,

    pub inline fn ended(self: *const Lexer) bool {
        return self.pos >= self.src.len;
    }

    pub inline fn willEnd(self: *const Lexer, n: usize) bool {
        return (self.pos + n) >= self.src.len;
    }

    pub inline fn currentChar(self: *const Lexer) u8 {
        return self.src[self.pos];
    }

    pub inline fn peekChar(self: *const Lexer) ?u8 {
        if (self.willEnd(1)) return null;
        return self.src[self.pos + 1];
    }

    pub inline fn peekNChars(self: *const Lexer, n: usize) ?u8 {
        if (self.willEnd(n)) return null;
        return self.src[self.pos + n];
    }

    pub inline fn advance(self: *Lexer) u8 {
        const char = self.currentChar();
        self.pos += 1;
        self.col += 1;
        if (char == '\n') {
            self.line += 1;
            self.col = 0;
        }
        return char;
    }

    pub inline fn match(self: *Lexer, expected: u8) bool {
        if (self.ended() or self.currentChar() != expected) return false;

        _ = self.advance();
        return true;
    }

    pub inline fn skipComment(self: *Lexer) bool {
        if (self.currentChar() == '/' and self.peekChar() == '/') {
            while (!self.ended() and self.advance() != '\n') { }
            return true;
        }
        return false;
    }

    pub inline fn skipWhitespace(self: *Lexer) void {
        while (!self.ended()) {

            if (std.ascii.isWhitespace(self.src[self.pos])) {
                const char = self.src[self.pos];
                self.pos += 1;
                self.col += 1;
                if (char == '\n') {
                    self.line += 1;
                    self.col = 0;
                }
                continue;
            } 

            if (!self.skipComment()) { break; }
        }
    }

    pub inline fn expect(self: *Lexer, expected: u8) !void {
        if (self.match(expected)) return;

        const found_char = if (self.ended()) ' ' else self.currentChar();
        self.err_msg = try std.fmt.allocPrint(
            self.allocator,
            "{d}:{d}: Expected '{c}' found '{c}'",
            .{ self.line, self.col, expected, found_char }
        );
        return LexerError.Expected;
    }

    pub inline fn scanNumber(self: *Lexer, buff: *std.ArrayList(u8)) !Token {
        var found_point = false;
        while (!self.ended() and (std.ascii.isDigit(self.currentChar()) or self.currentChar() == '.')) {
            const is_point = self.currentChar() == '.';
            if (found_point and is_point) return LexerError.InvalidNum;
            if (is_point) found_point = true;
            try buff.append(self.allocator, self.advance());
        }
        if (found_point) {
            return .{ .float = try std.fmt.parseFloat(f64, try buff.toOwnedSlice(self.allocator)) };
        } else {
            return .{ .int = try std.fmt.parseInt(i64, try buff.toOwnedSlice(self.allocator), 10) };
        }
    }

    pub inline fn processEscapeSequence(self: *Lexer) !u8 {
        if (self.ended()) return LexerError.Expected;
        
        const escaped_char = self.advance();
        return switch (escaped_char) {
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            '\\' => '\\',
            '"' => '\"',
            '\'' => '\'',
            else => LexerError.Expected,
        };
    }

    pub inline fn scanString(self: *Lexer, buff: *std.ArrayList(u8)) !Token {
        while (!self.ended() and self.currentChar() != '\"') {
            if (self.currentChar() == '\\') {
                _ = self.advance();
                const actual_byte = try self.processEscapeSequence();
                try buff.append(self.allocator, actual_byte);
            } else {
                try buff.append(self.allocator, self.advance());
            }
        }
        try self.expect('\"');
        return .{ .string = try buff.toOwnedSlice(self.allocator) };
    }

    pub inline fn scanChar(self: *Lexer) !Token {
        if (self.ended()) return LexerError.Expected;
        
        var char = self.advance();
        
        if (char == '\\') {
            char = try self.processEscapeSequence();
        }
        
        try self.expect('\'');
        return .{ .byte = char };
    }

    pub inline fn getType(id: []const u8) ?Token {
        var size_idx: usize = 0;
        var is_float = false;

        if (std.mem.startsWith(u8, id, INT_ID)) {
            size_idx = INT_ID.len;
        } else if (std.mem.startsWith(u8, id, FLOAT_ID)) {
            size_idx = FLOAT_ID.len;
            is_float = true;
        } else if (std.mem.eql(u8, id, BYTE_ID)) {
            return .byte_id;
        } else if (std.mem.eql(u8, id, STRING_ID)) {
            return .string_id;
        } else if (std.mem.eql(u8, id, BOOL_ID)) {
            return .bool_id;
        } else {
            return null;
        }

        const size = id[size_idx..];

        if (std.mem.eql(u8, size, "32")) {
            return if (is_float) .float32_id else .integer32_id;
        } else if (std.mem.eql(u8, size, "64")) {
            return if (is_float) .float64_id else .integer64_id;
        } else {
            return null;
        }
    }

    pub inline fn readIdentifier(self: *Lexer, buff: *std.ArrayList(u8)) !void {
        while (!self.ended() and (std.ascii.isAlphanumeric(self.currentChar()) or
            self.currentChar() == '_'))
        {
            try buff.append(self.allocator, self.advance());
        }
    }

    pub inline fn scanIdentifier(self: *Lexer, buff: *std.ArrayList(u8)) !Token {
        try self.readIdentifier(buff);

        if (std.mem.eql(u8, buff.items, INITALIZER)) {
            return .initalizer;
        } else if (std.mem.eql(u8, buff.items, CONST_INITALIZER)) {
            return .const_initalizer;
        } else if (std.mem.eql(u8, buff.items, IF_KEYWORD)) {
            return .keyword_if;
        } else if (std.mem.eql(u8, buff.items, ELSE_KEYWORD)) {
            return .keyword_else;
        } else if (std.mem.eql(u8, buff.items, FN_KEYWORD)) {
            return .keyword_fn;
        } else if (std.mem.eql(u8, buff.items, WHILE_KEYWORD)) {
            return .keyword_while;
        } else if (std.mem.eql(u8, buff.items, FOR_KEYWORD)) {
            return .keyword_for;
        } else if (std.mem.eql(u8, buff.items, RETURN_KEYWORD)) {
            return .keyword_return;
        } else if (std.mem.eql(u8, buff.items, STRUCT_KEYWORD)) {
            return .keyword_struct;
        } else if (std.mem.eql(u8, buff.items, "true")) {
            return .{ .boolean = true };
        } else if (std.mem.eql(u8, buff.items, "false")) {
            return .{ .boolean = false };
        } else if (Lexer.getType(buff.items)) |tok| {
            return tok;
        } else {
            return .{ .identifier = try buff.toOwnedSlice(self.allocator) };
        }
    }

    //TODO: line num and col
    pub inline fn next(self: *Lexer) !void {
        self.skipWhitespace();

        if (self.ended()) {
            self.tok = .EOF;
            return;
        }

        const current = self.advance();

        switch (current) {
            '+' => {
                if (self.match('+')) {
                    self.tok = .increment;
                } else if (self.match('=')) {
                    self.tok = .add_eql;
                } else {
                    self.tok = .add;
                }
            },
            '-' => {
                if (self.match('-')) {
                    self.tok = .decrement;
                } else if (self.match('=')) {
                    self.tok = .sub_eql;
                } else {
                    self.tok = .sub;
                }
            },
            '*' => {
                if (self.match('=')) {
                    self.tok = .mul_eql;
                } else {
                    self.tok = .mul;
                }
            },
            '/' => {
                if (self.match('=')) {
                    self.tok = .div_eql;
                } else {
                    self.tok = .div;
                }
            },
            '=' => {
                if (self.match('=')) {
                    self.tok = .eql_eql;
                } else {
                    self.tok = .eql;
                }
            },
            ':' => {
                self.tok = .colon;
            },
            ';' => {
                self.tok = .semicolon;
            },
            '[' => {
                self.tok = .sq_brace_o;
            },
            ']' => {
                self.tok = .sq_brace_c;
            },
            '{' => {
                self.tok = .cu_brace_o;
            },
            '}' => {
                self.tok = .cu_brace_c;
            },
            '(' => {
                self.tok = .paren_o;
            },
            ')' => {
                self.tok = .paren_c;
            },
            '@' => {
                self.tok = .at;
            },
            '.' => {
                self.tok = .dot;
            },
            '?' => {
                self.tok = .question;
            },
            ',' => {
                self.tok = .comma;
            },
            '!' => {
                if (self.match('=')) {
                    self.tok = .not_eql;
                } else {
                    self.tok = .not;
                }
            },
            '>' => {
                if (self.match('=')) {
                    self.tok = .greater_eql;
                } else if (self.match('>')) {
                    self.tok = .shift_right;
                } else {
                    self.tok = .greater;
                }
            },
            '<' => {
                if (self.match('=')) {
                    self.tok = .less_eql;
                } else if (self.match('<')) {
                    self.tok = .shift_left;
                } else {
                    self.tok = .less;
                }
            },
            '%' => {
                if (self.match('=')) {
                    self.tok = .modulo_eql;
                } else {
                    self.tok = .modulo;
                }
            },
            '&' => {
                if (self.match('&')) {
                    self.tok = ._and;
                } else {
                    self.tok = .bitwise_and;
                }
            },
            '|' => {
                if (self.match('|')) {
                    self.tok = ._or;
                } else {
                    self.tok = .bitwise_or;
                }
            },
            '^' => {
                self.tok = .bitwise_xor;
            },
            '~' => {
                self.tok = .bitwise_not;
            },
            else => {
                var buff = 
                    try std.ArrayList(u8).initCapacity(self.allocator, 256);
                defer buff.deinit(self.allocator);

                if (std.ascii.isDigit(current)) {
                    try buff.append(self.allocator, current);
                    self.tok = try self.scanNumber(&buff);
                } else if (current == '\"') {
                    self.tok = try self.scanString(&buff);
                } else if (current == '\'') {
                    self.tok = try self.scanChar();
                } else {
                    try buff.append(self.allocator, current);
                    self.tok = try self.scanIdentifier(&buff);
                }
            },
        }
    }
};

// --- Tests ---
const testing = std.testing;
const TokenTag = std.meta.Tag(Token);

fn expectTokenTags(src: []const u8, expected: []const TokenTag) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var lex = Lexer{
        .allocator = arena.allocator(),
        .src = src,
    };

    for (expected) |expected_tag| {
        try lex.next();
        try testing.expectEqual(expected_tag, std.meta.activeTag(lex.tok));
    }
    
    // Ensure the next token is EOF
    try lex.next();
    try testing.expectEqual(TokenTag.EOF, std.meta.activeTag(lex.tok));
}

test "Lexer: Keywords and Identifiers" {
    const src = "let const if else while for ret fn struct my_var";
    const expected = [_]TokenTag{
        .initalizer,
        .const_initalizer,
        .keyword_if,
        .keyword_else,
        .keyword_while,
        .keyword_for,
        .keyword_return,
        .keyword_fn,
        .keyword_struct,
        .identifier,
    };
    try expectTokenTags(src, &expected);
}

test "Lexer: Types" {
    const src = "byte str bool int32 int64 float32 float64";
    const expected = [_]TokenTag{
        .byte_id,
        .string_id,
        .bool_id,
        .integer32_id,
        .integer64_id,
        .float32_id,
        .float64_id,
    };
    try expectTokenTags(src, &expected);
}

test "Lexer: Numbers (Integers & Floats)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var lex = Lexer{
        .allocator = arena.allocator(),
        .src = "42 3.14 0",
    };

    try lex.next();
    try testing.expectEqual(TokenTag.int, std.meta.activeTag(lex.tok));
    try testing.expectEqual(@as(i64, 42), lex.tok.int);

    try lex.next();
    try testing.expectEqual(TokenTag.float, std.meta.activeTag(lex.tok));
    try testing.expectEqual(@as(f64, 3.14), lex.tok.float);

    try lex.next();
    try testing.expectEqual(TokenTag.int, std.meta.activeTag(lex.tok));
    try testing.expectEqual(@as(i64, 0), lex.tok.int);
}

test "Lexer: Strings and Characters" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var lex = Lexer{
        .allocator = arena.allocator(),
        .src = "\"hello\\nworld\" '\\t'",
    };

    try lex.next();
    try testing.expectEqual(TokenTag.string, std.meta.activeTag(lex.tok));
    try testing.expectEqualStrings("hello\nworld", lex.tok.string);

    try lex.next();
    try testing.expectEqual(TokenTag.byte, std.meta.activeTag(lex.tok));
    try testing.expectEqual(@as(u8, '\t'), lex.tok.byte);
}

test "Lexer: Operators" {
    const src = "+ += - -= * *= / /= % %= == != > >= < <= << >> & && | || ^ ~";
    const expected = [_]TokenTag{
        .add, .add_eql, 
        .sub, .sub_eql, 
        .mul, .mul_eql, 
        .div, .div_eql, 
        .modulo, .modulo_eql, 
        .eql_eql, .not_eql, 
        .greater, .greater_eql, 
        .less, .less_eql, 
        .shift_left, .shift_right, 
        .bitwise_and, ._and, 
        .bitwise_or, ._or, 
        .bitwise_xor, .bitwise_not,
    };
    try expectTokenTags(src, &expected);
}

test "Lexer: Punctuation" {
    const src = "{ } [ ] ( ) : ; , . = ! ? @";
    const expected = [_]TokenTag{
        .cu_brace_o, .cu_brace_c, 
        .sq_brace_o, .sq_brace_c, 
        .paren_o, .paren_c, 
        .colon, .semicolon, 
        .comma, .dot, 
        .eql, .not, .question, .at,
    };
    try expectTokenTags(src, &expected);
}

test "Lexer: Error InvalidNum" {
    var lex = Lexer{
        .allocator = testing.allocator,
        .src = "1.2.3",
    };
    try testing.expectError(LexerError.InvalidNum, lex.next());
}

test "Lexer: Error Unclosed String" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var lex = Lexer{
        .allocator = arena.allocator(),
        .src = "\"hello",
    };
    try testing.expectError(LexerError.Expected, lex.next());
}

test "Lexer: Error Invalid Character" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var lex = Lexer{
        .allocator = arena.allocator(),
        .src = "'ab'",
    };
    try testing.expectError(LexerError.Expected, lex.next());
}

test "Lexer: Error Invalid Escape" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var lex = Lexer{
        .allocator = arena.allocator(),
        .src = "'\\x'",
    };
    try testing.expectError(LexerError.Expected, lex.next());
}

test "Lexer: Line and Column Tracking" {
    @setEvalBranchQuota(10000);
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var lex = Lexer{
        .allocator = arena.allocator(),
        .src = 
            \\let a = 1;
            \\  let b = 2;
            \\
            \\let c = 3;
        ,
    };

    // "let"
    try lex.next();
    try testing.expectEqual(@as(usize, 0), lex.line);
    try testing.expectEqual(@as(usize, 3), lex.col);

    // "a"
    try lex.next();
    try testing.expectEqual(@as(usize, 0), lex.line);
    try testing.expectEqual(@as(usize, 5), lex.col);

    // "="
    try lex.next();
    try testing.expectEqual(@as(usize, 0), lex.line);
    try testing.expectEqual(@as(usize, 7), lex.col);

    // "1"
    try lex.next();
    // ";"
    try lex.next();
    try testing.expectEqual(@as(usize, 0), lex.line);
    try testing.expectEqual(@as(usize, 10), lex.col);

    // Next line "let" (after \n and 2 spaces)
    try lex.next();
    try testing.expectEqual(@as(usize, 1), lex.line);
    try testing.expectEqual(@as(usize, 5), lex.col);

    // Skip to next line
    try lex.next(); // b
    try lex.next(); // =
    try lex.next(); // 2
    try lex.next(); // ;

    // "let" after 2 newlines
    try lex.next();
    try testing.expectEqual(@as(usize, 3), lex.line);
    try testing.expectEqual(@as(usize, 3), lex.col);
}

test "Lexer: Error Message Formatting" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var lex = Lexer{
        .allocator = arena.allocator(),
        .src = "let c = 'a;",
    };

    try lex.next(); // let
    try lex.next(); // c
    try lex.next(); // =
    
    // Expect error on `'a;` missing closing quote
    const err = lex.next();
    try testing.expectError(LexerError.Expected, err);
    
    try testing.expect(lex.err_msg != null);
    try testing.expectEqualStrings("0:10: Expected ''' found ';'", lex.err_msg.?);
}

test "Lexer: Single Line Comments" {
    const src = 
        \\// This is a comment at the start
        \\let x = 10; // This is a comment at the end of a line
        \\// This is a comment in the middle
        \\const y = 20;
        \\// This comment is at the very end of the file
    ;
    
    const expected = [_]TokenTag{
        .initalizer, .identifier, .eql, .int, .semicolon,
        .const_initalizer, .identifier, .eql, .int, .semicolon,
    };
    
    try expectTokenTags(src, &expected);
}
