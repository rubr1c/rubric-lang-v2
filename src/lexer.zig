const std = @import("std");

const Token = union(enum) {
    initalizer: void,
    identifier: []const u8,
    assignment: void,

    // types
    int: i64,
    float: f64,
    integer32_id: void,
    float32_id: void,
    integer64_id: void,
    float64_id: void,

    // ops
    add: void,
    sub: void,
    mul: void,
    div: void,
    increment: void,
    decrement: void,

    comparison: void,

    colon: void,
    semicolon: void,

    // misc
    EOF: void,
};

const LexerError = error{
    Expected,
    InvalidNum,
};

const INITALIZER = "let";
const INT_ID = "int";
const FLOAT_ID = "float";

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
                if (self.peek(1)) |next| {
                    if (next == '+') {
                        self.pos += 2;
                        try self.add_tok(.increment);
                        return;
                    }
                }
                self.pos += 1;
                try self.add_tok(.add);
            },
            '-' => {
                if (self.peek(1)) |next| {
                    if (next == '-') {
                        self.pos += 2;
                        try self.add_tok(.decrement);
                        return;
                    }
                }
                self.pos += 1;
                try self.add_tok(.sub);
            },
            '*' => {
                self.pos += 1;
                try self.add_tok(.mul);
            },
            '/' => {
                self.pos += 1;
                try self.add_tok(.div);
            },
            '=' => {
                if (self.peek(1)) |next| {
                    if (next == '=') {
                        self.pos += 2;
                        try self.add_tok(.comparison);
                        return;
                    }
                }
                self.pos += 1;
                try self.add_tok(.assignment);
            },
            ':' => {
                self.pos += 1;
                try self.add_tok(.colon);
            },
            ';' => {
                self.pos += 1;
                try self.add_tok(.semicolon);
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
        } else if (std.ascii.isDigit(self.src[self.pos])) {
            const is_float = try self.read_num(&buff);
            if (is_float) {
                try self.add_tok(.{ .float = try std.fmt.parseFloat(f64, try buff.toOwnedSlice(self.allocator)) });
            } else {
                try self.add_tok(.{ .int = try std.fmt.parseInt(i64, try buff.toOwnedSlice(self.allocator), 10) });
            }
            // self.read_id() is called twice and should be optimized.
        } else if ((try self.read_num_id(&buff)) != null) {} else {
            try self.read_id(&buff);
            try self.add_tok(.{ .identifier = try buff.toOwnedSlice(self.allocator) });
        }
    }

    inline fn read_num_id(
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
