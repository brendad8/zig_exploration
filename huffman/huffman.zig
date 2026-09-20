
const std = @import("std");

const HuffmanNode = struct
{
    c: u8,
    count: usize,
    left: ?*HuffmanNode = null,
    right: ?*HuffmanNode = null,
    code: u64 = 0,
    code_len: u8 = 0,
};


pub fn main(init: std.process.Init) !void
{
    const io = init.io;
    const arena = init.arena.allocator();

    const input = try std.Io.Dir.cwd().readFileAlloc(io, "example.txt", arena, .unlimited);
    var node_map: std.AutoHashMap(u8, HuffmanNode) = .init(arena);

    for (input) |c| 
    {
        const gop = try node_map.getOrPut(c);
        if (gop.found_existing) 
        {
            gop.value_ptr.*.count += 1;
        } 
        else 
        {
            const node: HuffmanNode = .{
                .c = c,
                .count = 1,
                .left = null,
                .right = null,
                .code = 0,
                .code_len = 0,
            };
            gop.key_ptr.* = c; 
            gop.value_ptr.* = node;
        }
    }

    var node_pq: std.PriorityQueue(*HuffmanNode, void, comparePtrHuffmanNode) = .initContext({});
    
    var iter = node_map.iterator();
    while (iter.next()) |entry| 
    {
        try node_pq.push(arena, entry.value_ptr);
    }

    while (node_pq.count() > 1)
    {
        const left = node_pq.pop().?; 
        const right = node_pq.pop().?; 

        const new_node = try arena.create(HuffmanNode);
        new_node.* = .{ 
            .c = 0, 
            .count = left.count + right.count,
            .left = left,
            .right = right
        };
        try node_pq.push(arena, new_node);
    }

    const root = node_pq.pop().?;
    generateCodes(root, 0, 0);
    
    const file = try std.Io.Dir.cwd().createFile( io, "output", .{},);
    defer file.close(io);

    var writer_buf: [64]u8 = undefined;
    var file_writer = file.writer(io, &writer_buf);
    const writer = &file_writer.interface;

    var bits: u256 = 0;
    var bits_len: usize = 0;

    for (input) |c|
    {
        const node: HuffmanNode = node_map.get(c).?;
        bits |= node.code;
        bits_len += node.code_len;

        if (bits_len >= 8)
        {
            const byte: u8 = @intCast(bits);
            try writer.writeByte(byte);
            try writer.flush();
            bits >>= 8;
            bits_len -= 8;
        }
    }

    // NOTE(bcall): write remaining bits
    const byte: u8 = @intCast(bits);
    try writer.writeByte(byte);
    try writer.flush();
}

pub fn comparePtrHuffmanNode(context: void, a: *HuffmanNode, b: *HuffmanNode) std.math.Order
{
    _ = context;
    var result: std.math.Order = undefined;
    if (a.*.count < b.*.count) { result = .lt; }
    else if (a.*.count > b.*.count) { result = .gt; }
    else { result = .eq; }
    return result;
}

pub fn generateCodes(node: *HuffmanNode, code: u64, code_len: u8) void
{
    if (code_len > 64) unreachable;
    if (node.*.left == null and node.*.right == null)
    {
        node.*.code = code;
        node.*.code_len = code_len;
        return;
    }
    if (node.left)  |left|  { generateCodes(left, code << 1, code_len + 1); }
    if (node.right) |right| { generateCodes(right, (code << 1) | 1, code_len + 1); }
}

fn printBits(bits: u64, len: usize) void {
    var i = len;
    while (i > 0) 
    {
        i -= 1;
        const bit = (bits >> @as(u6, @intCast(i))) & 1;
        std.debug.print("{}", .{bit});
    }
}


