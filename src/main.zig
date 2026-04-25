const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // many issues with needing whitespace that needed to be fixed.
    var tokenizer: lexer.Tokenizer = try .init(
        allocator, 
        "let x : struct = { x : int32 };"
    );
    try tokenizer.build();

    std.debug.print("{any}\n", .{tokenizer.tokens.items});
}
