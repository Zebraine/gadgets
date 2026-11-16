const std = @import("std");
const Io = std.Io;

const zig = @import("base64");

threadlocal var x: i32 = 1234;

pub fn main() !void {
    const thread1 = try std.Thread.spawn(.{}, testTls, .{});
    const thread2 = try std.Thread.spawn(.{}, testTls, .{});
    testTls();
    thread1.join();
    thread2.join();
}

fn testTls() void {
    // 1234
    std.debug.print("x is {}\n", .{x});
    x += 1;
    // 1235
    std.debug.print("x is {}\n", .{x});
}