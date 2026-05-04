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

pub const Tokenizer = struct {
    src: []const u8,
    pos: usize = 0,
    allocator: Allocator,
    tok: Token = undefined,
    line: usize = 0,
    col: usize = 0,

    pub inline fn ended(self: *const Tokenizer) bool {
        return self.pos >= self.src.len;
    }

    pub inline fn willEnd(self: *const Tokenizer, n: usize) bool {
        return (self.pos + n) >= self.src.len;
    }

    pub inline fn currentChar(self: *const Tokenizer) u8 {
        return self.src[self.pos];
    }

    pub inline fn peekChar(self: *const Tokenizer) ?u8 {
        if (self.willEnd(1)) return null;
        return self.src[self.pos + 1];
    }

    pub inline fn peekNChars(self: *const Tokenizer, n: usize) ?u8 {
        if (self.willEnd(n)) return null;
        return self.src[self.pos + n];
    }

    pub inline fn advance(self: *Tokenizer) u8 {
        const char = self.currentChar();
        self.pos += 1;
        return char;
    }

    pub inline fn matchNext(self: *Tokenizer, expected: u8) bool {
        if (self.ended() or self.currentChar() != expected) return false;

        _ = self.advance();
        return true;
    }

    pub inline fn skipWhitespace(self: *Tokenizer) void {
        if (self.ended()) return;

        while (!self.ended() and std.ascii.isWhitespace(self.src[self.pos])) {
            self.pos += 1;
        }
    }

    pub inline fn scanNumber(self: *Tokenizer, buff: *std.ArrayList(u8)) !Token {
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

    pub inline fn scanString(self: *Tokenizer, buff: *std.ArrayList(u8)) !Token {
        while (!self.ended() and self.currentChar() != '\"') {
            try buff.append(self.allocator, self.advance());
        }
        if (!self.matchNext('\"')) return LexerError.Expected;
        return .{ .string = try buff.toOwnedSlice(self.allocator) };
    }

    pub inline fn scanChar(self: *Tokenizer) !Token {
        if (self.ended()) return LexerError.Expected;
        const char = self.advance();
        if (!self.matchNext('\'')) {
            return LexerError.Expected;
        }
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

    pub inline fn readIdentifier(self: *Tokenizer, buff: *std.ArrayList(u8)) !void {
        while (!self.ended() and (std.ascii.isAlphanumeric(self.currentChar()) or
            self.currentChar() == '_'))
        {
            try buff.append(self.allocator, self.advance());
        }
    }

    pub inline fn scanIdentifier(self: *Tokenizer, buff: *std.ArrayList(u8)) !Token {
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
        } else if (Tokenizer.getType(buff.items)) |tok| {
            return tok;
        } else {
            return .{ .identifier = try buff.toOwnedSlice(self.allocator) };
        }
    }

    //TODO: line num and col
    pub inline fn next(self: *Tokenizer) !void {
        self.skipWhitespace();

        if (self.ended()) {
            self.tok = .EOF;
            return;
        }

        const current = self.advance();

        switch (current) {
            '+' => {
                if (self.matchNext('+')) {
                    self.tok = .increment;
                } else if (self.matchNext('=')) {
                    self.tok = .add_eql;
                } else {
                    self.tok = .add;
                }
            },
            '-' => {
                if (self.matchNext('-')) {
                    self.tok = .decrement;
                } else if (self.matchNext('=')) {
                    self.tok = .sub_eql;
                } else {
                    self.tok = .sub;
                }
            },
            '*' => {
                if (self.matchNext('=')) {
                    self.tok = .mul_eql;
                } else {
                    self.tok = .mul;
                }
            },
            '/' => {
                if (self.matchNext('=')) {
                    self.tok = .div_eql;
                } else {
                    self.tok = .div;
                }
            },
            '=' => {
                if (self.matchNext('=')) {
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
                if (self.matchNext('=')) {
                    self.tok = .not_eql;
                } else {
                    self.tok = .not;
                }
            },
            '>' => {
                if (self.matchNext('=')) {
                    self.tok = .greater_eql;
                } else if (self.matchNext('>')) {
                    self.tok = .shift_right;
                } else {
                    self.tok = .greater;
                }
            },
            '<' => {
                if (self.matchNext('=')) {
                    self.tok = .less_eql;
                } else if (self.matchNext('<')) {
                    self.tok = .shift_left;
                } else {
                    self.tok = .less;
                }
            },
            '%' => {
                if (self.matchNext('=')) {
                    self.tok = .modulo_eql;
                } else {
                    self.tok = .modulo;
                }
            },
            '&' => {
                if (self.matchNext('&')) {
                    self.tok = ._and;
                } else {
                    self.tok = .bitwise_and;
                }
            },
            '|' => {
                if (self.matchNext('|')) {
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

                buff.clearAndFree(self.allocator);
            },
        }
    }
};
