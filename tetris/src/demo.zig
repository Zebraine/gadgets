//! Screenshot/demo scene setup. Kept outside the pure rules layer.

const cli = @import("cli.zig");
const game_mod = @import("game/game.zig");
const showcase = @import("game/showcase.zig");
const effects_mod = @import("ui/effects.zig");
const theme = @import("ui/theme.zig");

pub fn createGame(seed: u64) game_mod.Game {
    return showcase.create(seed);
}

pub fn applyScene(game: *game_mod.Game, effects: *effects_mod.Effects, scene: cli.Scene) void {
    switch (scene) {
        .play => {},
        .paused => game.phase = .paused,
        .game_over => {
            game.phase = .game_over;
            game.best = @max(game.best, game.score);
        },
        .clear => {
            for (16..20) |row| {
                for (0..game_mod.COLS) |col| {
                    game.board.cells[row][col] = @fromBackingInt(@intCast((row * 3 + col * 5) % 7));
                }
            }
            game.phase = .clearing;
            game.clear_rows = 0xF0000;
            game.clear_timer = game_mod.Game.clear_duration * 0.78;

            const info = game_mod.ClearInfo{
                .rows = game.clear_rows,
                .count = 4,
                .points = 800,
                .level = game.level,
            };
            effects.flash = 0.55;
            effects.burstRows(game, info);
            effects.banner.show("TETRIS!", "+800 PTS", theme.C.orange, 5.0);
        },
    }
}
