const std = @import("std");

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
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator, src: []const u8) !Tokenizer {
        return .{
            .tokens = try std.ArrayList(Token).initCapacity(allocator, 1024),
            .allocator = allocator,
            .src = src,
        };
    }

    pub inline fn empty(self: *const Tokenizer) bool {
        return self.pos >= self.src.len;
    }

    pub inline fn peek(self: *const Tokenizer, offset: usize) ?u8 {
        if (self.pos + offset >= self.src.len) return null;
        return self.src[self.pos + offset];
    }

    pub inline fn add_tok(self: *Tokenizer, token: Token) !void {
        return self.tokens.append(self.allocator, token);
    }

    pub inline fn next_tok(self: *Tokenizer) !?void {
        self.skip_space();

        if (self.empty()) return null;

        const first = self.src[self.pos];

        return switch (first) {
            '+' => {
                const next = self.peek(1);
                if (next == '+') {
                    self.pos += 2;
                    try self.add_tok(.increment);
                } else if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.add_eql);
                } else {
                    self.pos += 1;
                    try self.add_tok(.add);
                }
            },
            '-' => {
                const next = self.peek(1);
                if (next == '-') {
                    self.pos += 2;
                    try self.add_tok(.decrement);
                } else if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.sub_eql);
                } else {
                    self.pos += 1;
                    try self.add_tok(.sub);
                }
            },
            '*' => {
                const next = self.peek(1);
                if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.mul_eql);
                } else {
                    self.pos += 1;
                    try self.add_tok(.mul);
                }
            },
            '/' => {
                const next = self.peek(1);
                if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.div_eql);
                } else {
                    self.pos += 1;
                    try self.add_tok(.div);
                }
            },
            '=' => {
                const next = self.peek(1);
                if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.eql_eql);
                } else {
                    self.pos += 1;
                    try self.add_tok(.eql);
                }
            },
            ':' => {
                self.pos += 1;
                try self.add_tok(.colon);
            },
            ';' => {
                self.pos += 1;
                try self.add_tok(.semicolon);
            },
            '[' => {
                self.pos += 1;
                try self.add_tok(.sq_brace_o);
            },
            ']' => {
                self.pos += 1;
                try self.add_tok(.sq_brace_c);
            },
            '{' => {
                self.pos += 1;
                try self.add_tok(.cu_brace_o);
            },
            '}' => {
                self.pos += 1;
                try self.add_tok(.cu_brace_c);
            },
            '(' => {
                self.pos += 1;
                try self.add_tok(.paren_o);
            },
            ')' => {
                self.pos += 1;
                try self.add_tok(.paren_c);
            },
            '@' => {
                self.pos += 1;
                try self.add_tok(.at);
            },
            '.' => {
                self.pos += 1;
                try self.add_tok(.dot);
            },
            '?' => {
                self.pos += 1;
                try self.add_tok(.question);
            },
            ',' => {
                self.pos += 1;
                try self.add_tok(.comma);
            },
            '!' => {
                const next = self.peek(1);
                if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.not_eql);
                } else {
                    self.pos += 1;
                    try self.add_tok(.not);
                }
            },
            '>' => {
                const next = self.peek(1);
                if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.greater_eql);
                } else if (next == '>') {
                    self.pos += 2;
                    try self.add_tok(.shift_right);
                } else {
                    self.pos += 1;
                    try self.add_tok(.greater);
                }
            },
            '<' => {
                const next = self.peek(1);
                if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.less_eql);
                } else if (next == '<') {
                    self.pos += 2;
                    try self.add_tok(.shift_left);
                } else {
                    self.pos += 1;
                    try self.add_tok(.less);
                }
            },
            '%' => {
                const next = self.peek(1);
                if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(.modulo_eql);
                } else {
                    self.pos += 1;
                    try self.add_tok(.modulo);
                }
            },
            '&' => {
                const next = self.peek(1);
                if (next == '&') {
                    self.pos += 2;
                    try self.add_tok(._and);
                } else {
                    self.pos += 1;
                    try self.add_tok(.bitwise_and);
                }
            },
            '|' => {
                const next = self.peek(1);
                if (next == '=') {
                    self.pos += 2;
                    try self.add_tok(._or);
                } else {
                    self.pos += 1;
                    try self.add_tok(.bitwise_or);
                }
            },
            '^' => {
               self.pos += 1; 
               try self.add_tok(.bitwise_xor);
            },
           '~' => {
               self.pos += 1;
                try self.add_tok(.bitwise_not);
           },
            else => {
                try self.lex_id();
            },
        };
    }

    inline fn lex_id(self: *Tokenizer) !void {
        var buff = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        if (std.mem.startsWith(u8, self.src[self.pos..], INITALIZER)) {
            try self.read_lex_id(INITALIZER, .initalizer);
        } else if (std.mem.startsWith(u8, self.src[self.pos..], CONST_INITALIZER)) {
            try self.read_lex_id(CONST_INITALIZER, .const_initalizer);
        } else if (std.mem.startsWith(u8, self.src[self.pos..], IF_KEYWORD)) {
            try self.read_lex_id(IF_KEYWORD, .keyword_if);
        } else if (std.mem.startsWith(u8, self.src[self.pos..], ELSE_KEYWORD)) {
            try self.read_lex_id(ELSE_KEYWORD, .keyword_else);
        } else if (std.mem.startsWith(u8, self.src[self.pos..], FN_KEYWORD)) {
            try self.read_lex_id(FN_KEYWORD, .keyword_fn);
        } else if (std.mem.startsWith(u8, self.src[self.pos..], WHILE_KEYWORD)) {
            try self.read_lex_id(WHILE_KEYWORD, .keyword_while);
        } else if (std.mem.startsWith(u8, self.src[self.pos..], FOR_KEYWORD)) {
            try self.read_lex_id(FOR_KEYWORD, .keyword_for);
        } else if (std.mem.startsWith(u8, self.src[self.pos..], RETURN_KEYWORD)) {
            try self.read_lex_id(RETURN_KEYWORD, .keyword_return);
        } else if (std.mem.startsWith(u8, self.src[self.pos..], STRUCT_KEYWORD)) {
            try self.read_lex_id(STRUCT_KEYWORD, .keyword_struct);
        } else if (std.ascii.isDigit(self.src[self.pos])) {
            const is_float = try self.read_num(&buff);
            if (is_float) {
                try self.add_tok(.{ .float = try std.fmt.parseFloat(f64, try buff.toOwnedSlice(self.allocator)) });
            } else {
                try self.add_tok(.{ .int = try std.fmt.parseInt(i64, try buff.toOwnedSlice(self.allocator), 10) });
            }
        } else if (std.mem.startsWith(u8, self.src[self.pos..], "true") and
            !std.ascii.isAlphanumeric(self.src[self.pos + 4]))
        {
            try self.add_tok(.{ .boolean = true });
            self.pos += 4;
        } else if (std.mem.startsWith(u8, self.src[self.pos..], "false") and
            !std.ascii.isAlphanumeric(self.src[self.pos + 5]))
        {
            try self.add_tok(.{ .boolean = false });
            self.pos += 5;
        } else if (self.src[self.pos] == '\"') {
            try self.read_str(&buff);
            try self.add_tok(.{ .string = try buff.toOwnedSlice(self.allocator) });
        } else if (self.src[self.pos] == '\'') {
            try self.read_str(&buff);
            if (buff.items.len > 1) {
                // should not be allowed should check in parser prob.
                try self.add_tok(.{ .string = try buff.toOwnedSlice(self.allocator) });
            } else {
                try self.add_tok(.{ .byte = buff.items[0] });
            }
        } else if ((try self.read_type_id(&buff)) != null) {} else {
            try self.add_tok(.{ .identifier = try buff.toOwnedSlice(self.allocator) });
        }
    }

    inline fn read_type_id(
        self: *Tokenizer,
        buff: *std.ArrayList(u8),
    ) !?void {
        try self.read_id(buff);
        var start: usize = 0;
        var is_float = false;

        if (std.mem.startsWith(u8, buff.items, INT_ID)) {
            start = INT_ID.len;
        } else if (std.mem.startsWith(u8, buff.items, FLOAT_ID)) {
            start = FLOAT_ID.len;
            is_float = true;
        } else if (std.mem.startsWith(u8, buff.items, BYTE_ID)) {
            try self.add_tok(.byte_id);
            return;
        } else if (std.mem.startsWith(u8, buff.items, STRING_ID)) {
            try self.add_tok(.string_id);
            return;
        } else if (std.mem.startsWith(u8, buff.items, BOOL_ID)) {
            try self.add_tok(.bool_id);
            return;
        } else {
            return null;
        }

        const size = buff.items[start..];

        if (std.mem.startsWith(u8, size, "32")) {
            try self.add_tok(if (is_float) .float32_id else .integer32_id);
        } else if (std.mem.startsWith(u8, size, "64")) {
            try self.add_tok(if (is_float) .float64_id else .integer64_id);
        } else {
            return null;
        }
    }

    // returns true if float
    inline fn read_num(self: *Tokenizer, buff: *std.ArrayList(u8)) !bool {
        var is_float = false;
        while (!self.empty() and (std.ascii.isDigit(self.src[self.pos]) or self.src[self.pos] == '.')) {
            const has_point = self.src[self.pos] == '.';
            if (is_float and has_point) return LexerError.InvalidNum;
            if (has_point) is_float = true;

            try buff.append(self.allocator, self.src[self.pos]);
            self.pos += 1;
        }

        return is_float;
    }

    // assumes current is "
    // works with single and double even when strings should only be in ""
    // but will be used for chars and will be validated in parser.
    inline fn read_str(self: *Tokenizer, buff: *std.ArrayList(u8)) !void {
        self.pos += 1;
        while (self.src[self.pos] != '\"' and self.src[self.pos] != '\'') {
            try buff.append(self.allocator, self.src[self.pos]);
            self.pos += 1;
        }
        self.pos += 1;
    }

    inline fn read_lex_id(self: *Tokenizer, id: []const u8, tok: Token) !void {
        const next = self.peek(id.len);
        if (next == null or std.ascii.isWhitespace(next.?)) {
            self.pos += id.len;
            try self.add_tok(tok);
        }
    }

    inline fn read_id(self: *Tokenizer, buff: *std.ArrayList(u8)) !void {
        while (!self.empty() and
            !std.ascii.isWhitespace(self.src[self.pos]))
        {
            try buff.append(self.allocator, self.src[self.pos]);
            self.pos += 1;
        }

        if (buff.items.len == 0) return LexerError.Expected;
    }

    inline fn skip_space(self: *Tokenizer) void {
        if (self.empty()) return;

        while (!self.empty() and (self.src[self.pos] == ' ' or self.src[self.pos] == '\n')) {
            self.pos += 1;
        }
    }

    pub fn build(self: *Tokenizer) !void {
        while ((try self.next_tok()) != null) {}
        try self.tokens.append(self.allocator, .EOF);
    }
};
