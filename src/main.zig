const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var lexer_instance: lexer.Lexer = .{ .allocator = allocator, .src = "let c_char:byte='c';" };

    try lexer_instance.next();
    while (lexer_instance.tok != .EOF) {
        std.debug.print("{any} ", .{lexer_instance.tok});
        try lexer_instance.next();
    }
}
