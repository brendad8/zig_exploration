
const std = @import("std");
const builtin = @import("builtin");

const windows = std.os.windows;
const ntdll = windows.ntdll;

const posix = std.os.posix;


const VirtualMemoryInfo = struct
{
    page_size: usize = 0,
    allocation_granularity: usize = 0
};

pub fn getVirtualMemoryInfo() VirtualMemoryInfo 
{
    var vm_info: VirtualMemoryInfo = .{};
    if (builtin.os.tag == .windows) 
    {
        var sys_info: windows.SYSTEM.BASIC_INFORMATION = undefined;
        const status = ntdll.NtQuerySystemInformation(.Basic, &sys_info, @sizeOf(windows.SYSTEM.BASIC_INFORMATION), null);
        if (status == .SUCCESS)
        {
            vm_info.page_size = @as(usize, sys_info.PageSize);
            vm_info.allocation_granularity = @as(usize, sys_info.AllocationGranularity);
        }
    } 
    else 
    {
        const page_size = posix.sysconf(std.posix._SC.PAGESIZE) catch 0;
        vm_info.page_size = @as(usize, page_size);
        vm_info.allocation_granularity = @as(usize, page_size);
    }
    return vm_info;
}


pub fn reserveVirtualMemory(size: u64) ?*anyopaque
{
    var result: ?*anyopaque = null;

    const info: VirtualMemoryInfo  = getVirtualMemoryInfo();
    var size_aligned = std.mem.alignForward(usize, @as(usize, @intCast(size)), info.allocation_granularity);

    if (builtin.os.tag == .windows) 
    {
        var base_addr: ?*anyopaque = null;
        const current_process = windows.GetCurrentProcess();
        const status = ntdll.NtAllocateVirtualMemory(current_process, @ptrCast(@constCast(&base_addr)), 0, &size_aligned, .{ .COMMIT = false, .RESERVE = true }, .{ .NOACCESS = true });
        if (status == .SUCCESS) 
        {
            result = base_addr;
        }
    }
    else
    {
        result = posix.mmap(null, size_aligned, .{}, .{ .PRIVATE = true, .ANONYMOUS = true }, -1, 0) catch null;
    }

    return result;
}

pub fn commitVirtualMemory(ptr: *anyopaque , size: u64) bool
{
    const info: VirtualMemoryInfo = getVirtualMemoryInfo();
    var size_aligned = std.mem.alignForward(u64, @as(usize, @intCast(size)), info.page_size);

    if (builtin.os.tag == .windows) 
    {
        const current_process = windows.GetCurrentProcess();
        const status = ntdll.NtAllocateVirtualMemory(current_process, @ptrCast(@constCast(&ptr)), 1, &size_aligned, .{.COMMIT = true}, .{.READWRITE = true});
        return status == .SUCCESS;
    }
    else
    {
        const status: c_int = std.c.mprotect(ptr, size, .{.READ = true, .WRITE = true});
        return status == 0;
    }
}

pub fn decommitVirtualMemory(ptr: *anyopaque, size: u64) bool
{
    const info: VirtualMemoryInfo = getVirtualMemoryInfo();
    var size_aligned = std.mem.alignForward(u64, @as(usize, @intCast(size)), info.page_size);

    if (builtin.os.tag == .windows) 
    {
        const current_process = windows.GetCurrentProcess();
        const status = ntdll.NtFreeVirtualMemory(current_process, @ptrCast(@constCast(&ptr)), &size_aligned, .{.DECOMMIT = true});
        return status == .SUCCESS;
    }
    else
    {
        const status = try posix.madvise(@ptrCast(ptr), size, .{.DONTNEED = true});
        std.c.mprotect(ptr, size, .{});
        return status == 0;
    }
}

pub fn releaseVirtualMemory(ptr: *anyopaque, size: u64) bool
{
    if (builtin.os.tag == .windows) 
    {
        const current_process = windows.GetCurrentProcess();
        var size_aligned: windows.SIZE_T = 0;
        const status = ntdll.NtFreeVirtualMemory(current_process, @ptrCast(@constCast(&ptr)), &size_aligned, .{.RELEASE = true});
        return status == .SUCCESS;
    }
    else
    {
        const status = posix.munmap(@ptrCast(ptr), size);
        return status == 0;
    }
}

test "getVirtualMemoryInfo returns valid information" 
{
    const info = getVirtualMemoryInfo();

    try std.testing.expect(info.page_size > 0);
    try std.testing.expect(info.allocation_granularity > 0);

    // Allocation granularity should be at least as large as a page.
    try std.testing.expect(
        info.allocation_granularity >= info.page_size,
    );
}

test "reserveVirtualMemory returns memory" 
{
    const info = getVirtualMemoryInfo();

    const size = info.allocation_granularity * 2;

    const ptr = reserveVirtualMemory(size);
    try std.testing.expect(ptr != null);

    // The reservation itself should not be accessed yet.
    try std.testing.expect(
        releaseVirtualMemory(ptr.?, size),
    );
}

test "reserve, commit, write, decommit and release virtual memory" 
{
    const info = getVirtualMemoryInfo();

    // Use a size that is valid for both Windows and POSIX.
    const reserve_size = info.allocation_granularity * 2;
    const commit_size = info.page_size;

    const ptr = reserveVirtualMemory(reserve_size);
    try std.testing.expect(ptr != null);

    const memory = ptr.?;

    // Commit the first page.
    try std.testing.expect(
        commitVirtualMemory(memory, commit_size),
    );

    // We should now be able to read/write the committed page.
    const bytes: [*]u8 = @ptrCast(memory);

    bytes[0] = 0xAB;
    bytes[commit_size - 1] = 0xCD;

    try std.testing.expectEqual(@as(u8, 0xAB), bytes[0]);
    try std.testing.expectEqual(
        @as(u8, 0xCD),
        bytes[commit_size - 1],
    );

    // Decommit the page.
    try std.testing.expect(
        decommitVirtualMemory(memory, commit_size),
    );

    // Don't access `memory` after decommit.
    //
    // Finally release the entire reservation.
    try std.testing.expect(
        releaseVirtualMemory(memory, reserve_size),
    );
}

test "commit only part of a reservation" 
{
    const info = getVirtualMemoryInfo();

    const reserve_size = info.allocation_granularity * 2;
    const commit_size = info.page_size;

    const ptr = reserveVirtualMemory(reserve_size);
    try std.testing.expect(ptr != null);

    const base = ptr.?;

    defer _ = releaseVirtualMemory(base, reserve_size);

    // Commit only the first page.
    try std.testing.expect(
        commitVirtualMemory(base, commit_size),
    );

    const bytes: [*]u8 = @ptrCast(base);

    bytes[0] = 42;

    try std.testing.expectEqual(
        @as(u8, 42),
        bytes[0],
    );
}

test "multiple pages can be committed independently" 
{
    const info = getVirtualMemoryInfo();

    const page_size = info.page_size;
    const reserve_size = info.allocation_granularity * 2;

    const ptr = reserveVirtualMemory(reserve_size);
    try std.testing.expect(ptr != null);

    const base: [*]u8 = @ptrCast(ptr.?);

    defer _ = releaseVirtualMemory(ptr.?, reserve_size);

    // Commit two pages.
    try std.testing.expect( commitVirtualMemory(ptr.?, page_size * 2),);

    base[0] = 0x11;
    base[page_size] = 0x22;

    try std.testing.expectEqual( @as(u8, 0x11), base[0],);
    try std.testing.expectEqual( @as(u8, 0x22), base[page_size],);
}
