//! A read-only snapshot passed from the application layer into renderers.

const game_mod = @import("../game/game.zig");
const Fonts = @import("fonts.zig").Fonts;
const Effects = @import("effects.zig").Effects;

pub const RenderState = struct {
    game: *const game_mod.Game,
    fonts: *const Fonts,
    effects: *const Effects,
    display_score: f64,
    display_best: f64,
    time: f32,
};
