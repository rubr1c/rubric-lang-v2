const std = @import("std");

const Token = union(enum) {
    initalizer: void,
    identifier: []const u8,
    assignment: void,

    // datatypes
    integer32: i32,

    // ops
    add: void,
    sub: void,
    mul: void,
    div: void,
    increment: void,
    decrement: void,

    comparison: void,

    // misc
    EOF: void,
};

const LexerError = error{
    Expected,
};

pub const Tokenizer = struct {
    src: []const u8,
    pos: usize = 0,
    allocator: std.mem.Allocator,

    pub inline fn empty(self: *const Tokenizer) bool {
        return self.pos >= self.src.len;
    }

    pub inline fn peek(self: *const Tokenizer, offset: usize) ?u8 {
        if (self.pos + offset >= self.src.len) return null;
        return self.src[self.pos + offset];
    }

    pub inline fn next_tok(self: *Tokenizer) ?Token {
        self.skip_space();

        if (self.empty()) return null;

        if (std.mem.startsWith(u8, self.src[self.pos..], "let")) {
            if (self.peek(3)) |next| {
                if (next != ' ') return null;
            }
            self.pos += 3;
            return .initalizer;
        }

        const first = self.src[self.pos];

        return switch (first) {
            '+' => {
                if (self.peek(1)) |next| {
                    if (next == '+') {
                        self.pos += 2;
                        return .increment;
                    }
                }
                self.pos += 1;
                return .add;
            },
            '-' => {
                if (self.peek(1)) |next| {
                    if (next == '-') {
                        self.pos += 2;
                        return .decrement;
                    }
                }
                self.pos += 1;
                return .sub;
            },
            '*' => {
                self.pos += 1;
                return .mul;
            },
            '/' => {
                self.pos += 1;
                return .div;
            },
            '=' => {
                if (self.peek(1)) |next| {
                    if (next == '=') {
                        self.pos += 21;
                        return .comparison;
                    }
                }
                self.pos += 1;
                return .assignment;
            },
            else => null,
        };
    }

    inline fn skip_space(self: *Tokenizer) void {
        if (self.empty()) return;

        while (!self.empty() and (self.src[self.pos] == ' ' or self.src[self.pos] == '\n')) {
            self.pos += 1;
        }
    }

    inline fn expect(self: *Tokenizer, token: Token) !?Token {
        self.skip_space();
        if (self.empty()) return null;

        return switch (token) {
            .identifier => {
                var buff = try std.ArrayList(u8).initCapacity(self.allocator, 256);

                while (!self.empty() and self.src[self.pos] != ' ') {
                    try buff.append(self.allocator, self.src[self.pos]);
                    self.pos += 1;
                }
                return Token{ .identifier = try buff.toOwnedSlice(self.allocator) };
            },
            else => null,
        };
    }

    pub fn build(self: *Tokenizer) !std.ArrayList(Token) {
        var tokens = try std.ArrayList(Token).initCapacity(self.allocator, 1024);

        while (self.next_tok()) |token| {
            try tokens.append(self.allocator, token);
            if (token == .initalizer) {
                if (try self.expect(.{ .identifier = "" })) |id| {
                    try tokens.append(self.allocator, id);
                } else {
                    return LexerError.Expected;
                }
            }
        }

        try tokens.append(self.allocator, .EOF);

        return tokens;
    }
};
