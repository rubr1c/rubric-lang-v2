const std = @import("std");


const Token = union(enum) {
    identifier: []const u8,

    // datatypes
    
    integer32: i32,

    // ops
    
    add: void,
    sub: void,
    mul: void,
    div: void,
};


pub fn tokenize(allocator: std.mem.Allocator, src: []const u8) !std.ArrayList(Token) {
   var tokens = try std.ArrayList(Token).initCapacity(allocator, 1024);

   for (src) |char| {
       if (char == '+') {
           try tokens.append(allocator, Token.add);
       } else if (char == '-') {
           try tokens.append(allocator, Token.sub);
       } else if (char == '*') {
           try tokens.append(allocator, Token.mul);
       } else if (char == '/') {
           try tokens.append(allocator, Token.div);
       }
   }

   return tokens;
}
