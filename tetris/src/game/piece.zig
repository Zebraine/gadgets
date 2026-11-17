//! Tetromino identities, SRS rotation shapes and wall-kick tables.
//! This module has no dependency on the board or the renderer.

const std = @import("std");

pub const PieceKind = enum(u3) {
    i,
    o,
    t,
    s,
    z,
    j,
    l,

    pub fn index(self: PieceKind) usize {
        return @backingInt(self);
    }
};

pub const CellPos = struct {
    x: i32,
    y: i32,
};

pub const Piece = struct {
    kind: PieceKind,
    rotation: u2 = 0,
    x: i32 = 3,
    y: i32 = 0,

    pub fn spawn(kind: PieceKind) Piece {
        return .{ .kind = kind, .rotation = 0, .x = 3, .y = 0 };
    }

    /// The four occupied cells in board coordinates.
    pub fn cells(self: Piece) [4]CellPos {
        const rows = SHAPES[self.kind.index()][@intCast(self.rotation)];
        var out: [4]CellPos = undefined;
        var n: usize = 0;

        for (0..4) |row| {
            for (0..4) |col| {
                const bit = @as(u4, 1) << @as(u2, @intCast(col));
                if ((rows[row] & bit) != 0) {
                    out[n] = .{
                        .x = self.x + @as(i32, @intCast(col)),
                        .y = self.y + @as(i32, @intCast(row)),
                    };
                    n += 1;
                }
            }
        }

        std.debug.assert(n == 4);
        return out;
    }
};

/// SRS rotation states, one 4-bit row mask per row.
/// Rows grow down; each nibble's bits grow right.
const SHAPES = [7][4][4]u4{
    .{ // I
        .{ 0b0000, 0b1111, 0b0000, 0b0000 },
        .{ 0b0100, 0b0100, 0b0100, 0b0100 },
        .{ 0b0000, 0b0000, 0b1111, 0b0000 },
        .{ 0b0010, 0b0010, 0b0010, 0b0010 },
    },
    .{ // O
        .{ 0b0110, 0b0110, 0b0000, 0b0000 },
        .{ 0b0110, 0b0110, 0b0000, 0b0000 },
        .{ 0b0110, 0b0110, 0b0000, 0b0000 },
        .{ 0b0110, 0b0110, 0b0000, 0b0000 },
    },
    .{ // T
        .{ 0b0010, 0b0111, 0b0000, 0b0000 },
        .{ 0b0010, 0b0110, 0b0010, 0b0000 },
        .{ 0b0000, 0b0111, 0b0010, 0b0000 },
        .{ 0b0010, 0b0011, 0b0010, 0b0000 },
    },
    .{ // S
        .{ 0b0110, 0b0011, 0b0000, 0b0000 },
        .{ 0b0010, 0b0110, 0b0100, 0b0000 },
        .{ 0b0000, 0b0110, 0b0011, 0b0000 },
        .{ 0b0001, 0b0011, 0b0010, 0b0000 },
    },
    .{ // Z
        .{ 0b0011, 0b0110, 0b0000, 0b0000 },
        .{ 0b0100, 0b0110, 0b0010, 0b0000 },
        .{ 0b0000, 0b0011, 0b0110, 0b0000 },
        .{ 0b0010, 0b0011, 0b0001, 0b0000 },
    },
    .{ // J
        .{ 0b0001, 0b0111, 0b0000, 0b0000 },
        .{ 0b0110, 0b0010, 0b0010, 0b0000 },
        .{ 0b0000, 0b0111, 0b0100, 0b0000 },
        .{ 0b0010, 0b0010, 0b0011, 0b0000 },
    },
    .{ // L
        .{ 0b0100, 0b0111, 0b0000, 0b0000 },
        .{ 0b0010, 0b0010, 0b0110, 0b0000 },
        .{ 0b0000, 0b0111, 0b0001, 0b0000 },
        .{ 0b0011, 0b0010, 0b0010, 0b0000 },
    },
};

pub const Kick = [2]i8;
const KickTable = [8][5]Kick;

/// Ordered 0->R, R->0, R->2, 2->R, 2->L, L->2, L->0, 0->L.
/// X grows right, Y grows down (SRS tables are expressed with Y growing up).
const JLSTZ_KICKS: KickTable = .{
    .{ .{ 0, 0 }, .{ -1, 0 }, .{ -1, -1 }, .{ 0, 2 }, .{ -1, 2 } },
    .{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, -2 }, .{ 1, -2 } },
    .{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, -2 }, .{ 1, -2 } },
    .{ .{ 0, 0 }, .{ -1, 0 }, .{ -1, -1 }, .{ 0, 2 }, .{ -1, 2 } },
    .{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, -1 }, .{ 0, 2 }, .{ 1, 2 } },
    .{ .{ 0, 0 }, .{ -1, 0 }, .{ -1, 1 }, .{ 0, -2 }, .{ -1, -2 } },
    .{ .{ 0, 0 }, .{ -1, 0 }, .{ -1, 1 }, .{ 0, -2 }, .{ -1, -2 } },
    .{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, -1 }, .{ 0, 2 }, .{ 1, 2 } },
};

const I_KICKS: KickTable = .{
    .{ .{ 0, 0 }, .{ -2, 0 }, .{ 1, 0 }, .{ -2, 1 }, .{ 1, -2 } },
    .{ .{ 0, 0 }, .{ 2, 0 }, .{ -1, 0 }, .{ 2, -1 }, .{ -1, 2 } },
    .{ .{ 0, 0 }, .{ -1, 0 }, .{ 2, 0 }, .{ -1, -2 }, .{ 2, 1 } },
    .{ .{ 0, 0 }, .{ 1, 0 }, .{ -2, 0 }, .{ 1, 2 }, .{ -2, -1 } },
    .{ .{ 0, 0 }, .{ 2, 0 }, .{ -1, 0 }, .{ 2, -1 }, .{ -1, 2 } },
    .{ .{ 0, 0 }, .{ -2, 0 }, .{ 1, 0 }, .{ -2, 1 }, .{ 1, -2 } },
    .{ .{ 0, 0 }, .{ 1, 0 }, .{ -2, 0 }, .{ 1, 2 }, .{ -2, -1 } },
    .{ .{ 0, 0 }, .{ -1, 0 }, .{ 2, 0 }, .{ -1, -2 }, .{ 2, 1 } },
};

fn transitionIndex(from: u2, to: u2) usize {
    const key = @as(u8, from) * 4 + @as(u8, to);
    return switch (key) {
        0b0001 => 0, // 0 -> R
        0b0100 => 1, // R -> 0
        0b0110 => 2, // R -> 2
        0b1001 => 3, // 2 -> R
        0b1011 => 4, // 2 -> L
        0b1110 => 5, // L -> 2
        0b1100 => 6, // L -> 0
        0b0011 => 7, // 0 -> L
        else => unreachable,
    };
}

pub fn nextRotation(rotation: u2, clockwise: bool) u2 {
    const base: u3 = @intCast(rotation);
    return @intCast(if (clockwise) (base + 1) % 4 else (base + 3) % 4);
}

/// Ordered SRS kick offsets to test for a one-step rotation.
pub fn kickTests(kind: PieceKind, from: u2, to: u2) []const Kick {
    if (kind == .o) return &.{.{ 0, 0 }};
    const index = transitionIndex(from, to);
    return if (kind == .i) &I_KICKS[index] else &JLSTZ_KICKS[index];
}

test "every piece has four unique cells in every rotation" {
    for ([_]PieceKind{ .i, .o, .t, .s, .z, .j, .l }) |kind| {
        for (0..4) |rotation| {
            const piece = Piece{ .kind = kind, .rotation = @intCast(rotation), .x = 3, .y = 0 };
            var seen: [16]bool = @splat(false);
            for (piece.cells()) |pos| {
                const local_x: usize = @intCast(pos.x - piece.x);
                const local_y: usize = @intCast(pos.y - piece.y);
                try std.testing.expect(local_x < 4 and local_y < 4);
                try std.testing.expect(!seen[local_y * 4 + local_x]);
                seen[local_y * 4 + local_x] = true;
            }
        }
    }
}

test "clockwise and counter-clockwise rotations wrap" {
    try std.testing.expectEqual(@as(u2, 1), nextRotation(0, true));
    try std.testing.expectEqual(@as(u2, 0), nextRotation(3, true));
    try std.testing.expectEqual(@as(u2, 3), nextRotation(0, false));
    try std.testing.expectEqual(@as(u2, 0), nextRotation(1, false));
}
