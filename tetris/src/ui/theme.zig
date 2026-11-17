//! Shared visual palette and layout metrics for the 1200x800 virtual canvas.

const rl = @import("raylib");
const board = @import("../game/board.zig");
const piece = @import("../game/piece.zig");

pub const WINDOW_W: i32 = 1200;
pub const WINDOW_H: i32 = 800;

pub const VW: f32 = 1200;
pub const VH: f32 = 800;

pub const CELL: f32 = 30;
pub const BOARD_X: f32 = 450;
pub const BOARD_Y: f32 = 100;
pub const BOARD_W: f32 = @as(f32, @floatFromInt(board.COLS)) * CELL;
pub const BOARD_H: f32 = @as(f32, @floatFromInt(board.ROWS)) * CELL;

pub const LEFT_X: f32 = 90;
pub const LEFT_W: f32 = 310;
pub const RIGHT_X: f32 = 800;
pub const RIGHT_W: f32 = 310;
pub const CARD_RADIUS: f32 = 0.075;

pub const C = struct {
    pub const void_bg = rl.Color.init(3, 6, 13, 255);
    pub const bg_top = rl.Color.init(10, 15, 30, 255);
    pub const bg_bottom = rl.Color.init(4, 7, 15, 255);
    pub const surface = rl.Color.init(13, 20, 35, 255);
    pub const surface_alt = rl.Color.init(19, 28, 47, 255);
    pub const surface_hot = rl.Color.init(25, 36, 59, 255);
    pub const border = rl.Color.init(42, 57, 85, 255);
    pub const border_soft = rl.Color.init(29, 41, 63, 255);
    pub const text = rl.Color.init(237, 243, 255, 255);
    pub const muted = rl.Color.init(144, 161, 190, 255);
    pub const dim = rl.Color.init(91, 108, 137, 255);
    pub const cyan = rl.Color.init(53, 218, 240, 255);
    pub const violet = rl.Color.init(168, 114, 255, 255);
    pub const orange = rl.Color.init(255, 164, 85, 255);
    pub const green = rl.Color.init(86, 226, 164, 255);
    pub const pink = rl.Color.init(255, 112, 147, 255);
    pub const gold = rl.Color.init(255, 206, 102, 255);
    pub const board = rl.Color.init(6, 10, 19, 255);
    pub const cell_a = rl.Color.init(11, 17, 30, 255);
    pub const cell_b = rl.Color.init(10, 15, 27, 255);
};

pub const PieceVisual = struct {
    base: rl.Color,
    glow: rl.Color,
};

pub const PIECE_VISUALS = [7]PieceVisual{
    .{ .base = rl.Color.init(48, 219, 243, 255), .glow = rl.Color.init(18, 187, 222, 255) },
    .{ .base = rl.Color.init(250, 204, 72, 255), .glow = rl.Color.init(235, 167, 35, 255) },
    .{ .base = rl.Color.init(177, 111, 255, 255), .glow = rl.Color.init(137, 73, 240, 255) },
    .{ .base = rl.Color.init(77, 225, 155, 255), .glow = rl.Color.init(38, 195, 127, 255) },
    .{ .base = rl.Color.init(255, 105, 128, 255), .glow = rl.Color.init(235, 70, 105, 255) },
    .{ .base = rl.Color.init(92, 151, 255, 255), .glow = rl.Color.init(53, 107, 238, 255) },
    .{ .base = rl.Color.init(255, 159, 83, 255), .glow = rl.Color.init(237, 117, 47, 255) },
};

pub fn pieceVisual(kind: piece.PieceKind) PieceVisual {
    return PIECE_VISUALS[kind.index()];
}
