//! Scoring, combo and level progression rules.

const std = @import("std");

pub const line_clear_points = [5]u64{ 0, 100, 300, 500, 800 };

pub fn pointsForClear(lines: u8, level: u32, combo: u32) u64 {
    const count: usize = @min(lines, line_clear_points.len - 1);
    const level_mult: u64 = level;

    var points = line_clear_points[count] * level_mult;
    if (combo > 0) {
        points += 50 * @as(u64, combo) * level_mult;
    }
    return points;
}

pub fn levelForLines(lines: u32) u32 {
    return lines / 10 + 1;
}

test "clear points include level and combo multipliers" {
    try std.testing.expectEqual(@as(u64, 100), pointsForClear(1, 1, 0));
    try std.testing.expectEqual(@as(u64, 800), pointsForClear(4, 1, 0));
    try std.testing.expectEqual(@as(u64, 500), pointsForClear(1, 5, 0));
    try std.testing.expectEqual(@as(u64, 750), pointsForClear(1, 5, 1));
    try std.testing.expectEqual(@as(u32, 1), levelForLines(9));
    try std.testing.expectEqual(@as(u32, 2), levelForLines(10));
    try std.testing.expectEqual(@as(u32, 5), levelForLines(40));
}
