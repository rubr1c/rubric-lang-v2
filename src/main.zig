const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tokenizer: lexer.Tokenizer = .{ .allocator = allocator, .src = "let c_char:byte='c';" };

    try tokenizer.next();
    while (tokenizer.tok != .EOF) {
        std.debug.print("{any} ", .{tokenizer.tok});
        try tokenizer.next();
    }
}
