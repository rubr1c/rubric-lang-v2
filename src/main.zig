const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const tokens = lexer.tokenize(allocator, "let cold ++--=/*==");

    std.debug.print("{any}\n", .{tokens});
}


