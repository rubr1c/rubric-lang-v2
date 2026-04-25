const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // colon for types have to have a space before the id prob should fix.
    var tokenizer: lexer.Tokenizer = try .init(allocator, "let cold : bool = false;");
    try tokenizer.build();

    std.debug.print("{any}\n", .{tokenizer.tokens.items});
}
