//! Curated mid-game snapshot used by demo and screenshot modes.

const std = @import("std");

const game_mod = @import("game.zig");
pub fn create(seed: u64) game_mod.Game {
    var game = game_mod.Game.init(seed);
    game.board.clear();

    const pattern = [10]struct { row: usize, mask: u10 }{
        .{ .row = 19, .mask = 0b1111101111 },
        .{ .row = 18, .mask = 0b1111011111 },
        .{ .row = 17, .mask = 0b1110111011 },
        .{ .row = 16, .mask = 0b1101110111 },
        .{ .row = 15, .mask = 0b1011101101 },
        .{ .row = 14, .mask = 0b0111010011 },
        .{ .row = 13, .mask = 0b0011001010 },
        .{ .row = 12, .mask = 0b0000100100 },
        .{ .row = 11, .mask = 0b0010000010 },
        .{ .row = 10, .mask = 0b0000010000 },
    };

    for (pattern) |entry| {
        for (0..game_mod.COLS) |col| {
            const bit = @as(u10, 1) << @as(u4, @intCast(col));
            if ((entry.mask & bit) != 0) {
                const pick = (entry.row * 7 + col * 3) % 7;
                game.board.cells[entry.row][col] = @fromBackingInt(@intCast(pick));
            }
        }
    }

    game.score = 12_840;
    game.best = 48_120;
    game.lines = 37;
    game.level = 4;
    game.combo = 2;
    game.elapsed = 7 * 60 + 24;
    game.hold = .l;
    game.can_hold = true;
    game.next_queue = .{ .s, .z, .t };
    game.active = .{ .kind = .t, .rotation = 1, .x = 4, .y = 3 };
    game.phase = .playing;
    game.drop_timer = 0;
    game.lock_timer = 0;
    game.events.clear();
    return game;
}

test "showcase contains playable, in-bounds state" {
    const game = create(4);
    try std.testing.expect(game.phase == .playing);
    try std.testing.expect(game.fits(game.active));
    try std.testing.expect(game.hold != null);
    for (0..game_mod.ROWS) |row| {
        for (0..game_mod.COLS) |col| {
            _ = game.cell(col, row);
        }
    }
}
