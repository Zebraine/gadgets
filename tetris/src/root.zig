//! Public package API. The rules are renderer-independent and can be tested
//! with `zig build test`.
pub const game = @import("game/game.zig");
pub const piece = @import("game/piece.zig");
pub const board = @import("game/board.zig");
pub const bag = @import("game/bag.zig");
pub const scoring = @import("game/scoring.zig");
pub const events = @import("game/events.zig");
pub const showcase = @import("game/showcase.zig");

test {
    _ = game;
    _ = piece;
    _ = board;
    _ = bag;
    _ = scoring;
    _ = events;
    _ = showcase;
}
