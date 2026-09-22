
const builtin = @import("builtin");
const std = @import("std");
const time = std.time;

const c = @cImport({
    @cInclude("sys/time.h");
    @cInclude("time.h");
});

const DayOfWeek = enum(u8)
{
    sunday,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
};

const Duration = struct
{
    days:  i64 = 0,
    hours: i64 = 0,
    mins:  i64 = 0,
    secs:  i64 = 0,
    msecs: i64 = 0,
    usecs: i64 = 0,
};

const DenseTime = i64; // micro seconds since 0001-01-01 00:00:00.000
                       
const DateTime = struct
{
    year:  u16,       // [1-65535] 0 = undefined, 1 = 1 AD
    month: u16,       // [1-12]
    day:   u16,       // [1-31]
    hour:  u16 = 0,   // [0-23]
    min:   u16 = 0,   // [0-59]
    sec:   u16 = 0,   // [0-59]
    msec:  u16 = 0,   // [0-999]
    usec:  u16 = 0,   // [0-999]
                 
    const Self = @This();

    
    pub fn toDense(self: Self) DenseTime
    {
        var result: DenseTime = 0;
        var days: i64 = daysBeforeYear(self.year);
        const leap_year_idx: usize = if (isLeapYear(self.year)) 1 else 0;
        days += days_before_month[leap_year_idx][self.month - 1];
        days += self.day - 1;
        result += days * time.us_per_day;
        result += @as(i64, @intCast(self.hour)) * time.us_per_hour;
        result += @as(i64, @intCast(self.min)) * time.us_per_min;
        result += @as(i64, @intCast(self.sec)) * time.us_per_s;
        result += @as(i64, @intCast(self.msec)) * time.us_per_ms;
        result += @as(i64, @intCast(self.usec));
        return result;
    }

    pub fn fromDense(dense: DenseTime) DateTime
    {
        var result: DateTime = undefined;

        const days = @divTrunc(dense, time.us_per_day); // days since 0001-01-01 00:00:00.000
        const usec_into_day = @mod(dense, time.us_per_day);

        const num_cycles = @divTrunc(days, days_per_400_years);
        var days_into_cycle = @mod(days, days_per_400_years);

        var year: u16 = @intCast(num_cycles * 400 + 1);
        
        while (true)
        {
            const leap_year_idx: usize = if (isLeapYear(year)) 1 else 0;
            const diy = days_in_year[leap_year_idx];

            if (days_into_cycle < diy)
                break;

            days_into_cycle -= diy;
            year += 1;
        }

        var month: usize = 1;
        const days_into_year = days_into_cycle;
        const leap_year_idx: usize = if (isLeapYear(year)) 1 else 0;

        for (1..12) |i|
        {
            if (days_into_year < days_before_month[leap_year_idx][i])
                break;
            month += 1;
        }

        const day = days_into_year - days_before_month[leap_year_idx][month-1] + 1;

        const hour = @divTrunc(usec_into_day, time.us_per_hour);
        const usec_into_hour = @mod(usec_into_day, time.us_per_hour);

        const min = @divTrunc(usec_into_hour, time.us_per_min);
        const usec_into_min = @mod(usec_into_hour, time.us_per_min);

        const sec = @divTrunc(usec_into_min, time.us_per_s);
        const usec_into_sec = @mod(usec_into_min, time.us_per_s);
        
        const msec = @divTrunc(usec_into_sec, time.us_per_ms);
        const usec = @mod(usec_into_sec, time.us_per_ms);

        result.year  = year;
        result.month = @intCast(month);
        result.day   = @intCast(day);
        result.hour  = @intCast(hour);
        result.min   = @intCast(min);
        result.sec   = @intCast(sec);
        result.msec  = @intCast(msec);
        result.usec  = @intCast(usec);

        return result;
    }

    pub fn nowUtc(io: std.Io) DateTime
    {
        const us_since_epoch = std.Io.Clock.now(.real, io).toMicroseconds();
        const now: DenseTime = unix_epoch_dense + us_since_epoch;
        return DateTime.fromDense(now);
    }

    pub fn nowLocal() DateTime
    {
        if (builtin.os.tag == .windows)
        {
        }
        else
        {
            var tv: c.struct_timeval = undefined;
            _ = c.gettimeofday(&tv, null);
            const t: c.time_t = tv.tv_sec;
            var tm_local: c.struct_tm = undefined;
            _ = c.localtime_r(&t, &tm_local);
            return .{
                .year  = @as(u16, @intCast(tm_local.tm_year)) + 1900,
                .month = @as(u16, @intCast(tm_local.tm_mon)) + 1,
                .day   = @as(u16, @intCast(tm_local.tm_mday)),
                .hour  = @as(u16, @intCast(tm_local.tm_hour)),
                .min   = @as(u16, @intCast(tm_local.tm_min)),
                .sec   = @as(u16, @intCast(tm_local.tm_sec)),
                .msec  = @as(u16, @intCast(@divTrunc(tv.tv_usec, 1000))),
                .usec  = @as(u16, @intCast(@mod(tv.tv_usec, 1000))),
            };
        }
    }

    pub fn addDuration(self: Self, duration: Duration)
    {
        var dense = self.toDense();
        dense += duration.days * time.us_per_day;
        dense += duration.hours * time.us_per_hour;
        dense += duration.mins * time.us_per_min;
        dense += duration.secs * time.us_per_s;
        dense += duration.msecs * time.us_per_ms;
        dense += duration.usecs;
        return DateTime.fromDense(dense);
    }


    pub fn getDayOfWeek(self: Self) DayOfWeek
    {
        const dense = self.toDense();
        const days: i64 = @divTrunc(dense, time.us_per_day);
        const dow: DayOfWeek = @enumFromInt(@mod((days + 1), 7));
        return dow;
    }
};

fn isLeapYear(year: u16) bool 
{
    if (@mod(year, 4) != 0)
        return false;
    if (@mod(year, 100) != 0)
        return true;
    return (0 == @mod(year, 400));
}

fn daysBeforeYear(year: u16) i64
{
    var result: i64 = 0;
    const y: i64 = @as(i64, @intCast(year)) - 1;
    result += 365 * y;
    result += @divTrunc(y, 4);
    result -= @divTrunc(y, 100);
    result += @divTrunc(y, 400);
    return result;
}

// DateTime    date_time_now_local        (void);
// DayOfWeek   date_time_day_of_week      (DateTime);
// DateTime    date_time_add_usec         (DateTime, int);
// DateTime    date_time_add_msec         (DateTime, int);
// DateTime    date_time_add_secs         (DateTime, int);
// DateTime    date_time_add_mins         (DateTime, int);
// DateTime    date_time_add_days         (DateTime, int);
// int         date_time_compare          (DateTime, DateTime);
// bool        date_time_equal            (DateTime, DateTime);
// bool        date_time_equal_date       (DateTime, DateTime);
// int64       date_time_diff             (DateTime, DateTime);
// bool        date_time_local_to_utc     (DateTime, DateTime*);
// bool        date_time_utc_to_local     (DateTime, DateTime*);
// DateTime    date_time_from_unix        (int64); // unix time is microseconds since Jan 1st 1970 00:00:00.000000
// DenseTime   dense_time_from_unix       (int64); // unix time is microseconds since Jan 1st 1970 00:00:00.000000


const unix_epoch_dt: DateTime = .{ .year = 1970, .month = 1, .day = 1 };
const unix_epoch_dense: DenseTime = 62135596800000000;

const win_epoch_dt: DateTime = .{ .year = 1601, .month = 1, .day = 1 };
const dense_win_epoch: DenseTime = 50491123200000000;

const days_in_year: [2]i64 = .{ 365, 366 }; // { non-leap, leap }
                                            
const days_before_month: [2][12]i64 = .{
    .{ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }, // non-leap
    .{ 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335 }  // leap
};

const days_per_400_years = 146097;


pub fn main(init: std.process.Init) void
{
    const today: DateTime = .{
        .year = 2026,
        .month = 9,
        .day = 21
    };
    std.debug.print("today = {any}\n", .{today});
    const today_dense = today.toDense();
    const today2: DateTime = .fromDense(today_dense);
    std.debug.print("today2 = {any}\n", .{today2});
    
    const now_utc: DateTime = .nowUtc(init.io);
    std.debug.print("now = {any}\n", .{now_utc});
    
    const now_local: DateTime = .nowLocal();
    std.debug.print("now = {any}\n", .{now_local});

}
