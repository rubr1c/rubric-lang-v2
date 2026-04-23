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


const LexerError = error {
    Expected,
};

inline fn skip_space(src: *[]const u8) void {
    if (src.len == 0) return;

    while (src.*[0] == ' ') {
        src.* = src.*[1..];
    }
}

// TODO: add errors and expect spaces sometimes.
inline fn tok(src: *[]const u8) ?Token {
    skip_space(src);
    
    if (src.len == 0) return null;

    if (std.mem.startsWith(u8, src.*, "let")) {
        if (src.*[3] != ' ') return null;
        src.* = src.*[3..]; 
        return .initalizer;
    }

    const first = src.*[0];

    src.* = src.*[1..];
    
    return switch (first) {
        '+' => {
            if (src.len != 0 and src.*[1] == '+') {
                src.* = src.*[1..];
                return .increment;
            }
            return .add;
        },
        '-' => {
            if (src.len != 0 and src.*[1] == '-') {
                src.* = src.*[1..];
                return .decrement;
            }
            return .sub;
        },
        '*' => .mul,
        '/' => .div,
        '=' => {
            if (src.len > 1 and src.*[1] == '=') {
                src.* = src.*[1..];
                return .comparison;
            }
            return .assignment;
        },
        else => null,
    };
}


fn next(src: *[]const u8) ?Token {
    if (src.len == 0) return null;

    return tok(src); 
}

fn expect(allocator: std.mem.Allocator, src: *[]const u8, token: Token) !?Token {
    skip_space(src);
    if (src.len == 0) return null;

    return switch (token) {
        .identifier => {
            var buff = try std.ArrayList(u8).initCapacity(allocator, 256);

            while (src.len > 0 and src.*[0] != ' ') {
                try buff.append(allocator, src.*[0]);
                src.* = src.*[1..];
            }
            return Token{ .identifier = try buff.toOwnedSlice(allocator) };
        },
        else => null,
    };
}


pub fn tokenize(
    allocator: std.mem.Allocator, 
    src: []const u8
) !std.ArrayList(Token) {
   var tokens = try std.ArrayList(Token).initCapacity(allocator, 1024);

   var mut_src = src;

   while (next(&mut_src)) |token| {
       try tokens.append(allocator, token); 
       if (token == .initalizer) {
           if (try expect(allocator, &mut_src, .{ .identifier = "" })) |id| {
                try tokens.append(allocator, id);
           } else {
               return LexerError.Expected;
           }
       }
   }

   try tokens.append(allocator, .EOF);

   return tokens;
}
