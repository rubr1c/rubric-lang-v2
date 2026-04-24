const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tokenizer: lexer.Tokenizer = .{
        .src = "let cold ++--=/*==",
        .allocator = allocator,
    };

    const tokens = tokenizer.build();

    std.debug.print("{any}\n", .{tokens});
}
