

pub fn Range(comptime T: type) type
{
    return struct {
        begin: T,
        end: T,

        const Self = @This();

        pub fn getParitionFromIdx(num_values: T, num_paritions: T, idx: T) Range(T)
        {
            const values_per_partition = num_values / num_paritions;
            const num_leftover_values = num_values % num_paritions;
            const partition_has_leftover: bool = (idx < num_leftover_values);
            const leftovers_before_this_idx = if (partition_has_leftover) idx 
                                              else num_leftover_values;

            const begin = (values_per_partition * idx + leftovers_before_this_idx);
            const end = (begin + values_per_partition + @intFromBool(partition_has_leftover));
            return .{
                .begin = begin,
                .end = end
            };
        }
    };
}

const std = @import("std");

test "range partitions 1"
{
    var range: Range(u64) = undefined;
    range.getParitionFromIdx(1000, 3, 0);
    try std.testing.expectEqual(range, Range(u64){.begin = 0, .end = 334});
    range.getParitionFromIdx(1000, 3, 1);
    try std.testing.expectEqual(range, Range(u64){.begin = 334, .end = 667});
    range.getParitionFromIdx(1000, 3, 2);
    try std.testing.expectEqual(range, Range(u64){.begin = 667, .end = 1000});
}

test "range partitions 2"
{
    var range: Range(u8) = undefined;
    range.getParitionFromIdx(255, 6, 0);
    try std.testing.expectEqual(range, Range(u8){.begin = 0, .end = 43});
    range.getParitionFromIdx(255, 6, 1);
    try std.testing.expectEqual(range, Range(u8){.begin = 43, .end = 86});
    range.getParitionFromIdx(255, 6, 2);
    try std.testing.expectEqual(range, Range(u8){.begin = 86, .end = 129});
    range.getParitionFromIdx(255, 6, 3);
    try std.testing.expectEqual(range, Range(u8){.begin = 129, .end = 171});
    range.getParitionFromIdx(255, 6, 4);
    try std.testing.expectEqual(range, Range(u8){.begin = 171, .end = 213});
    range.getParitionFromIdx(255, 6, 5);
    try std.testing.expectEqual(range, Range(u8){.begin = 213, .end = 255});
}
