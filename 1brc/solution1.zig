
const std = @import("std");

const Stats = struct {
    min: f32,
    max: f32,
    sum: f32,
    count: i32,
};

pub fn main(init: std.process.Init) !void {

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var stats: std.StringHashMap(Stats) = .init(allocator);
    try stats.ensureTotalCapacity(10000);
    defer stats.deinit();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    const io = init.io;

    const cwd = std.Io.Dir.cwd();
    const file = try cwd.openFile(io, "measurements.txt", .{ .mode = .read_only, });
    defer file.close(io);

    var read_buffer: [65536]u8 = undefined;
    var file_reader = file.reader(io, &read_buffer);
    const reader = &file_reader.interface;

    while (try reader.takeDelimiter('\n')) |line| 
    {
        const station, const temp_str = std.mem.cutScalar(u8, line, ';').?;
        const temp = try std.fmt.parseFloat(f32, temp_str);
        const gop = try stats.getOrPut(station);
        if (gop.found_existing) {
            gop.value_ptr.min = @min(gop.value_ptr.min, temp);
            gop.value_ptr.max = @max(gop.value_ptr.max, temp);
            gop.value_ptr.count += 1;
            gop.value_ptr.sum += temp;
        } 
        else 
        {
            gop.key_ptr.* = try allocator.dupe(u8, station);
            gop.value_ptr.* = .{
                .min = temp,
                .max = temp,
                .count = 1,
                .sum = temp,
            };
        }
    }

    var stations = try std.ArrayList([]const u8).initCapacity(allocator, stats.unmanaged.size);
    var it = stats.keyIterator();
    while (it.next()) |station_name| 
    {
        try stations.append(allocator, station_name.*);
    }

    std.mem.sortUnstable([]const u8, stations.items, {}, lessThan);

    try stdout.print("{{", .{});
    for (stations.items, 0..) |station, i| 
    {
        if (i > 0) { try stdout.print(", ", .{}); }

        const s = stats.get(station).?;
        const mean = s.sum / @as(f64, @floatFromInt(s.count));
        try stdout.print("{s}={d:.1}/{d:.1}/{d:.1}", .{ station, s.min, mean, s.max });
    }

    try stdout.print("}}\n", .{});
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool 
{
    return std.mem.order(u8, a, b) == std.math.Order.lt;
}
