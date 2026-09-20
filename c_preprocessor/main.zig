
const std = @import("std");
const lex = @import("lexer.zig");

pub fn main(init: std.process.Init) !void
{
    const gpa = init.gpa;
    const io = init.io;

    const input = try std.Io.Dir.cwd().readFileAlloc(io, "input.c", gpa, .unlimited);
    defer gpa.free(input);

    var lexer = lex.init(input);

    while (lexer.hasTokens())
    {
        const token = lexer.nextToken();
        std.debug.print("{any}\n", .{token});
    }
}
