//! A seven-bag randomizer: each group of seven pieces is a shuffled full set.

const std = @import("std");
const piece = @import("piece.zig");

pub const SevenBag = struct {
    rng: std.Random.DefaultPrng,
    bag: [7]piece.PieceKind,
    index: usize,

    pub fn init(seed: u64) SevenBag {
        return .{
            .rng = std.Random.DefaultPrng.init(seed ^ 0x9e37_79b9_7f4a_7c15),
            .bag = undefined,
            .index = 7,
        };
    }

    /// Start a new shuffled bag while preserving the RNG stream.
    pub fn reset(self: *SevenBag) void {
        self.index = self.bag.len;
    }

    pub fn next(self: *SevenBag) piece.PieceKind {
        if (self.index >= self.bag.len) {
            self.bag = .{ .i, .o, .t, .s, .z, .j, .l };
            self.rng.random().shuffle(piece.PieceKind, &self.bag);
            self.index = 0;
        }

        const kind = self.bag[self.index];
        self.index += 1;
        return kind;
    }
};

test "each cycle of the seven bag is a complete set" {
    var bag = SevenBag.init(42);
    bag.reset();
    var counts: [7]u8 = @splat(0);
    for (0..14) |_| {
        counts[bag.next().index()] += 1;
    }
    try std.testing.expectEqualSlices(u8, &[_]u8{ 2, 2, 2, 2, 2, 2, 2 }, &counts);

    bag.reset();
    var cycle: [7]u8 = @splat(0);
    for (0..7) |_| {
        cycle[bag.next().index()] += 1;
    }
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 1, 1, 1, 1, 1, 1 }, &cycle);
}
