
const std = @import("std");

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
    const range = getRange(file_size, num_threads, idx);
    std.debug.print("range = {}\n", .{range});

    var read_buffer: [256]u8 = undefined;
    var file_reader = file.reader(io, &read_buffer);
    try file_reader.seekTo(range.begin);

    const reader = &file_reader.interface;

    while (try reader.takeDelimiter('\n')) |line| 
    {
        std.debug.print("thread {d}: {s}\n", .{idx, line});
    }
}

const Range = struct
{
    begin: u64,
    end: u64
};

fn getRange(size: u64, num_partitions: u64, idx: u64) Range {
    std.debug.assert(num_partitions > 0);
    std.debug.assert(idx < num_partitions);

    const base = size / num_partitions;
    const remainder = size % num_partitions;

    const begin = idx * base + @min(idx, remainder);
    const end = begin + base + @intFromBool(idx < remainder);

    return .{ .begin = begin, .end = end, };
}
