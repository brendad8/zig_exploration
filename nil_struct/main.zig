
const std = @import("std");

const Node = struct
{
    first:  *const Node,
    last:   *const Node,
    next:   *const Node,
    prev:   *const Node,
    parent: *const Node,
    v: u32
};

const nil_node: Node = .{
    .first  = &nil_node,
    .last   = &nil_node,
    .next   = &nil_node,
    .prev   = &nil_node,
    .parent = &nil_node,
    .v = 0
};

pub fn main() void
{
    std.debug.print("\nnil_node = .{{\n", .{});
    std.debug.print("   .first  = {*}\n", .{&nil_node});
    std.debug.print("   .last   = {*}\n", .{&nil_node});
    std.debug.print("   .next   = {*}\n", .{&nil_node});
    std.debug.print("   .prev   = {*}\n", .{&nil_node});
    std.debug.print("   .parent = {*}\n", .{&nil_node});
    std.debug.print("   .v      = {}\n", .{nil_node.v});
    std.debug.print("}}\n", .{});
}
