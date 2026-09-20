
const std = @import("std");
const range = @import("range.zig");

const num_threads = 2;

pub fn main(init: std.process.Init) !void
{
    const io = init.io;
    const arena = init.arena.allocator();
    _ = arena;

    const file = try std.Io.Dir.cwd().openFile(io, "example.txt", .{});
    const file_stat = try file.stat(io);
    const file_size = file_stat.size;
    defer file.close(io);

    var threads: [2]std.Thread = undefined;
    for (0..2) |i|
    {
        threads[i] = try std.Thread.spawn(.{}, threadEntry, .{io, file, file_size, i});
    }
    
    for (0..2) |i|
    {
        threads[i].join();
    }

    // std.debug.print("file_size = {d}\n", .{file_size});
    // std.debug.print("range = {}\n", .{getRange(file_size, 2, 0)});
    // std.debug.print("range = {}\n", .{getRange(file_size, 2, 1)});

    // var read_buffer: [1024]u8 = undefined;
    // var file_reader = file.reader(io, &read_buffer);
    // const reader = &file_reader.interface;

    // while (try reader.takeDelimiter('\n')) |line| 
    // {
    // }
}

fn threadEntry(io: std.Io, file: std.Io.File, file_size: u64, idx: u64) !void
{
    const rng: range.Range(u64) = .getParitionFromIdx(file_size, num_threads, idx);
    std.debug.print("rng = {}\n", .{rng});

    var read_buffer: [256]u8 = undefined;
    var file_reader = file.reader(io, &read_buffer);
    try file_reader.seekTo(rng.begin);

    // const reader = &file_reader.interface;
    // if (idx != 0)
    // {
    //     while (true) 
    //     {
    //         const c = reader.peekByte() catch break;
    //         if (!isDelimiter(c)) break;
    //         _ = try reader.takeByte();
    //     }
    // }
    //
    // // std.debug.print("thread {d} pos = {}\n", .{idx, file_reader.logicalPos()});
    //
    // while (try takeUntilDelimiter(reader)) |word| 
    // {
    //     std.debug.print("thread {d}: {s}\n", .{idx, word});
    //     if (file_reader.logicalPos() > rng.end) break;
    // }
}

fn isDelimiter(c: u8) bool
{
    return c == ' ' or c == '\n' or c == '\t' or c == '.';
}

fn takeUntilDelimiter(reader: *std.Io.Reader) !?[]u8
{
    
    var len: usize = 0; 
    while (true) : (len += 1)
    {
        const c = reader.peekByte() catch break;
        if (isDelimiter(c)) break;
    }
    const result: ?[]u8 = reader.take(len) catch null;
    _ = reader.take(1) catch {}; // move past delimiter
    return result;
}
