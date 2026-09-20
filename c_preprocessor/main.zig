
const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main(init: std.process.Init) !void
{
    const gpa = init.gpa;
    const io = init.io;

    const input = try std.Io.Dir.cwd().readFileAlloc(io, "input.c", gpa, .unlimited);
    defer gpa.free(input);

    var lex = lexer.init(input);

    while (lex.hasTokens())
    {
        const token = lex.nextToken();
        std.debug.print("{any}\n", .{token});
    }
}
