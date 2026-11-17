//! Playfield rendering: frame, cells, ghost, active piece and clear flash.

const rl = @import("raylib");
const game_mod = @import("../game/game.zig");
const theme = @import("theme.zig");
const gfx = @import("draw.zig");
const widgets = @import("widgets.zig");
const RenderState = @import("state.zig").RenderState;

const C = theme.C;

pub fn draw(state: *const RenderState) void {
    const frame = gfx.rect(theme.BOARD_X - 14, theme.BOARD_Y - 14, theme.BOARD_W + 28, theme.BOARD_H + 28);

    // Stacked drop shadows and a faint halo give the well some depth.
    rl.drawRectangleRounded(gfx.rect(frame.x + 4, frame.y + 16, frame.width, frame.height), 0.045, 10, rl.Color.init(0, 0, 0, 125));
    rl.drawCircleGradient(gfx.v2(600, 400), 360, C.cyan.fade(0.035), C.void_bg.fade(0.0));
    widgets.drawPanel(frame, C.surface, C.border);

    rl.drawRectangleRec(gfx.rect(frame.x + 14, frame.y + 14, theme.BOARD_W, theme.BOARD_H), C.board);

    const inner = gfx.rect(theme.BOARD_X, theme.BOARD_Y, theme.BOARD_W, theme.BOARD_H);
    for (0..game_mod.ROWS) |row| {
        for (0..game_mod.COLS) |col| {
            const x = theme.BOARD_X + @as(f32, @floatFromInt(col)) * theme.CELL;
            const y = theme.BOARD_Y + @as(f32, @floatFromInt(row)) * theme.CELL;
            const color = if ((row + col) % 2 == 0) C.cell_a else C.cell_b;
            rl.drawRectangleV(gfx.v2(x, y), gfx.v2(theme.CELL, theme.CELL), color);
        }
    }

    // Hairline grid.
    for (0..game_mod.COLS + 1) |col| {
        const x = theme.BOARD_X + @as(f32, @floatFromInt(col)) * theme.CELL;
        rl.drawLineEx(gfx.v2(x, theme.BOARD_Y), gfx.v2(x, theme.BOARD_Y + theme.BOARD_H), 1, rl.Color.init(81, 104, 139, 17));
    }
    for (0..game_mod.ROWS + 1) |row| {
        const y = theme.BOARD_Y + @as(f32, @floatFromInt(row)) * theme.CELL;
        rl.drawLineEx(gfx.v2(theme.BOARD_X, y), gfx.v2(theme.BOARD_X + theme.BOARD_W, y), 1, rl.Color.init(81, 104, 139, 17));
    }
    rl.drawRectangleLinesEx(inner, 1, rl.Color.init(100, 126, 161, 30));

    // Subtle top vignette.
    rl.drawRectangleGradientV(
        @intFromFloat(theme.BOARD_X),
        @intFromFloat(theme.BOARD_Y),
        @intFromFloat(theme.BOARD_W),
        76,
        C.void_bg.fade(0.48),
        C.void_bg.fade(0.0),
    );

    // Stacked cells.
    for (0..game_mod.ROWS) |row| {
        for (0..game_mod.COLS) |col| {
            if (state.game.cell(col, row)) |kind| {
                const x = theme.BOARD_X + @as(f32, @floatFromInt(col)) * theme.CELL;
                const y = theme.BOARD_Y + @as(f32, @floatFromInt(row)) * theme.CELL;
                gfx.drawBlock(x, y, theme.CELL, theme.pieceVisual(kind).base, 1.0, false);
            }
        }
    }

    if (state.game.activeVisible()) {
        drawGhost(state);
        drawActivePiece(state);
    }

    if (state.game.phase == .clearing) {
        drawClearFlash(state);
    }

    // Four asymmetric corner brackets.
    const bracket = 22;
    const line = 2;
    rl.drawLineEx(gfx.v2(frame.x - 1, frame.y + 8), gfx.v2(frame.x - 1, frame.y + 8 + bracket), line, C.cyan.fade(0.8));
    rl.drawLineEx(gfx.v2(frame.x + 8, frame.y - 1), gfx.v2(frame.x + 8 + bracket, frame.y - 1), line, C.cyan.fade(0.8));
    rl.drawLineEx(gfx.v2(frame.x + frame.width + 1, frame.y + frame.height - 8 - bracket), gfx.v2(frame.x + frame.width + 1, frame.y + frame.height - 8), line, C.orange.fade(0.8));
    rl.drawLineEx(gfx.v2(frame.x + frame.width - 8 - bracket, frame.y + frame.height + 1), gfx.v2(frame.x + frame.width - 8, frame.y + frame.height + 1), line, C.orange.fade(0.8));
    rl.drawCircleV(gfx.v2(frame.x + frame.width + 2, frame.y + frame.height + 2), 2.5, C.orange);
    rl.drawCircleV(gfx.v2(frame.x - 2, frame.y - 2), 2.5, C.cyan);

    // Scanline highlight so the well reads as a glass panel.
    rl.drawLineEx(gfx.v2(theme.BOARD_X + 1, theme.BOARD_Y + 7), gfx.v2(theme.BOARD_X + theme.BOARD_W - 1, theme.BOARD_Y + 7), 1, rl.Color.init(255, 255, 255, 14));
}

fn drawGhost(state: *const RenderState) void {
    const ghost_y = state.game.ghostY();
    if (ghost_y == state.game.active.y) return;

    const visual = theme.pieceVisual(state.game.active.kind);
    var ghost = state.game.active;
    ghost.y = ghost_y;
    for (ghost.cells()) |pos| {
        const x = theme.BOARD_X + @as(f32, @floatFromInt(pos.x)) * theme.CELL;
        const y = theme.BOARD_Y + @as(f32, @floatFromInt(pos.y)) * theme.CELL;
        const inset = 3.0;
        const cell_rect = gfx.rect(x + inset, y + inset, theme.CELL - inset * 2, theme.CELL - inset * 2);
        rl.drawRectangleRounded(cell_rect, 0.22, 4, visual.base.fade(0.07));
        rl.drawRectangleRoundedLinesEx(cell_rect, 0.22, 4, 1.2, visual.base.fade(0.36));
        rl.drawCircleV(gfx.v2(cell_rect.x + cell_rect.width / 2, cell_rect.y + cell_rect.height / 2), 1.4, visual.base.fade(0.42));
    }
}

fn drawActivePiece(state: *const RenderState) void {
    const visual = theme.pieceVisual(state.game.active.kind);
    for (state.game.activeCells()) |pos| {
        const x = theme.BOARD_X + @as(f32, @floatFromInt(pos.x)) * theme.CELL;
        const y = theme.BOARD_Y + @as(f32, @floatFromInt(pos.y)) * theme.CELL;
        gfx.drawBlock(x, y, theme.CELL, visual.base, 1.0, true);
    }
}

fn drawClearFlash(state: *const RenderState) void {
    const ratio = @max(0.0, state.game.clear_timer / game_mod.Game.clear_duration);
    const intensity = ratio * ratio;
    var rows = state.game.clear_rows;
    while (rows != 0) {
        const row: usize = @intCast(@ctz(rows));
        rows &= rows - 1;
        const y = theme.BOARD_Y + @as(f32, @floatFromInt(row)) * theme.CELL;
        rl.drawRectangleRec(gfx.rect(theme.BOARD_X, y, theme.BOARD_W, theme.CELL), C.text.fade(0.17 * intensity));
        rl.drawLineEx(gfx.v2(theme.BOARD_X, y + 2), gfx.v2(theme.BOARD_X + theme.BOARD_W, y + 2), 1.5, C.text.fade(0.72 * intensity));
        rl.drawLineEx(gfx.v2(theme.BOARD_X, y + theme.CELL - 2), gfx.v2(theme.BOARD_X + theme.BOARD_W, y + theme.CELL - 2), 1.0, C.text.fade(0.4 * intensity));
    }

    rl.drawRectangleRec(gfx.rect(theme.BOARD_X, theme.BOARD_Y, theme.BOARD_W, theme.BOARD_H), C.text.fade(0.035 * state.effects.flash));
}
