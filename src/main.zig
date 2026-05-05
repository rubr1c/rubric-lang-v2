const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var lexer_instance: lexer.Lexer = .{ .allocator = allocator, .src = "let c_char:byte='c';" };

    while (true) {
        lexer_instance.next() catch |err| {
            if (lexer_instance.err_msg) |msg| {
                std.debug.print("\nError: {s}\n", .{msg});
            } else {
                std.debug.print("\nError: {}\n", .{err});
            }
            return;
        };

        if (lexer_instance.tok == .EOF) break;
        std.debug.print("{any} ", .{lexer_instance.tok});
    }
    std.debug.print("\n", .{});
}
