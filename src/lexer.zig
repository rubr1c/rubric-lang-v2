const std = @import("std");

const Token = union(enum) {
    initalizer: void,
    identifier: []const u8,
    assignment: void,

    // types
    integer32: i32,
    integer32_id: void, 

    // ops
    add: void,
    sub: void,
    mul: void,
    div: void,
    increment: void,
    decrement: void,

    comparison: void,

    colon: void,

    // misc
    EOF: void,
};

const LexerError = error{
    Expected,
};

const IDENTIFIER = "let";
const I32_ID = "int32";

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

    pub inline fn next_tok(self: *Tokenizer) !bool {
        self.skip_space();

        if (self.empty()) return false;

        const first = self.src[self.pos];

        return switch (first) {
            '+' => {
                if (self.peek(1)) |next| {
                    if (next == '+') {
                        self.pos += 2;
                        try self.add_tok(.increment);
                        return true;
                    }
                }
                self.pos += 1;
                try self.add_tok(.add);
                return true;
            },
            '-' => {
                if (self.peek(1)) |next| {
                    if (next == '-') {
                        self.pos += 2;
                        try self.add_tok(.decrement);
                        return true;
                    }
                }
                self.pos += 1;
                try self.add_tok(.sub);
                return true;
            },
            '*' => {
                self.pos += 1;
                try self.add_tok(.mul);
                return true;
            },
            '/' => {
                self.pos += 1;
                try self.add_tok(.div);
                return true;
            },
            '=' => {
                if (self.peek(1)) |next| {
                    if (next == '=') {
                        self.pos += 2;
                        try self.add_tok(.comparison);
                        return true;
                    }
                }
                self.pos += 1;
                try self.add_tok(.assignment);
                return true;
            },
            else => self.lex_id(),
        };
    }

    // very messy just testin
    inline fn lex_id(self: *Tokenizer) !bool {
        if (std.mem.startsWith(u8, self.src[self.pos..], IDENTIFIER)) {
            const next = self.peek(IDENTIFIER.len);
            if (next == null or std.ascii.isWhitespace(next.?)) {
                self.pos += IDENTIFIER.len;
                try self.add_tok(.initalizer);
                self.skip_space();

                if (self.empty()) return LexerError.Expected;

                var buff = try std.ArrayList(u8).initCapacity(self.allocator, 256);

                while (!self.empty() and 
                         self.src[self.pos] != ' ' and self.src[self.pos] != ':')
                 {
                    try buff.append(self.allocator, self.src[self.pos]);
                    self.pos += 1;
                }

                if (buff.items.len == 0) return LexerError.Expected;

                try self.add_tok(.{ .identifier = try buff.toOwnedSlice(self.allocator) });
                
                if (self.empty()) return true;

                self.skip_space();

                if (self.src[self.pos] == ':') {
                    try self.add_tok(.colon);
                    self.pos += 1;

                    self.skip_space();

                    var t_buff = try std.ArrayList(u8).initCapacity(self.allocator, 256);
                    var count: usize = 0;
                    while (self.pos + count < self.src.len and self.src[self.pos + count] != ' ') {
                        try t_buff.append(self.allocator, self.src[self.pos + count]);
                        count += 1;
                    }

                    if (std.mem.eql(u8, t_buff.items, I32_ID)) {
                        try self.add_tok(.integer32_id);
                        self.pos += count;
                    }
                }

                return true;
            }
        }

        return false;
    }

    inline fn skip_space(self: *Tokenizer) void {
        if (self.empty()) return;

        while (!self.empty() and (self.src[self.pos] == ' ' or self.src[self.pos] == '\n')) {
            self.pos += 1;
        }
    }

    pub fn build(self: *Tokenizer) !void {
        while (try self.next_tok()) {}
        try self.tokens.append(self.allocator, .EOF);
    }
};
