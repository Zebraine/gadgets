//! Modal in-field overlays for pause and game over.

const std = @import("std");
const rl = @import("raylib");
const theme = @import("theme.zig");
const gfx = @import("draw.zig");
const widgets = @import("widgets.zig");
const RenderState = @import("state.zig").RenderState;

const C = theme.C;

pub fn draw(state: *const RenderState) void {
    switch (state.game.phase) {
        .paused => drawPauseOverlay(state),
        .game_over => drawGameOverOverlay(state),
        else => {},
    }
}

fn drawPauseOverlay(state: *const RenderState) void {
    rl.drawRectangleRec(gfx.rect(theme.BOARD_X, theme.BOARD_Y, theme.BOARD_W, theme.BOARD_H), C.void_bg.fade(0.66));

    const center_x = theme.BOARD_X + theme.BOARD_W / 2;
    const center_y = theme.BOARD_Y + theme.BOARD_H / 2;
    const panel = gfx.rect(center_x - 112, center_y - 76, 224, 152);
    widgets.drawPanel(panel, C.surface.fade(0.98), C.border);

    const pulse = 0.65 + 0.35 * std.math.sin(state.time * 2.4);
    rl.drawRectangleRounded(gfx.rect(center_x - 22, center_y - 56, 8, 30), 0.5, 4, C.cyan.fade(pulse));
    rl.drawRectangleRounded(gfx.rect(center_x + 14, center_y - 56, 8, 30), 0.5, 4, C.cyan.fade(pulse));

    gfx.drawLabel(state.fonts.small, "SYSTEM HALTED", center_x - 47, center_y - 11, C.dim);
    gfx.drawTextCentered(state.fonts.display, "PAUSED", center_x, center_y + 6, 28, 2.4, C.text);
    gfx.drawTextCentered(state.fonts.small, "PRESS P OR ESC TO RESUME", center_x, center_y + 49, 9.5, 1.2, C.muted);
    gfx.drawTextCentered(state.fonts.small, "R TO RESTART", center_x, center_y + 65, 9, 1.3, C.dim);
}

fn drawGameOverOverlay(state: *const RenderState) void {
    rl.drawRectangleRec(gfx.rect(theme.BOARD_X, theme.BOARD_Y, theme.BOARD_W, theme.BOARD_H), C.void_bg.fade(0.76));

    const center_x = theme.BOARD_X + theme.BOARD_W / 2;
    const panel = gfx.rect(center_x - 132, theme.BOARD_Y + 125, 264, 350);
    widgets.drawPanel(panel, C.surface.fade(0.99), C.border);
    rl.drawCircleGradient(gfx.v2(center_x, panel.y + 52), 90, C.pink.fade(0.075), C.surface.fade(0.0));

    gfx.drawTextCentered(state.fonts.small, "RUN TERMINATED", center_x, panel.y + 25, 9.5, 1.75, C.pink);
    gfx.drawTextCentered(state.fonts.display, "GAME OVER", center_x, panel.y + 44, 30, 1.4, C.text);
    rl.drawLineEx(gfx.v2(panel.x + 30, panel.y + 92), gfx.v2(panel.x + panel.width - 30, panel.y + 92), 1, C.border_soft);
    rl.drawCircleV(gfx.v2(center_x, panel.y + 92), 2.2, C.pink.fade(0.8));

    gfx.drawTextCentered(state.fonts.small, "FINAL SCORE", center_x, panel.y + 111, 9.5, 1.7, C.muted);
    var score_buf: [40]u8 = undefined;
    const score_text = std.fmt.bufPrint(&score_buf, "{d}", .{state.game.score}) catch "0";
    gfx.drawTextCentered(state.fonts.display, score_text, center_x, panel.y + 131, 34, 0.7, C.text);

    var stats_buf: [64]u8 = undefined;
    const stats = std.fmt.bufPrint(&stats_buf, "LINES {d}     LEVEL {d}", .{ state.game.lines, state.game.level }) catch "";
    gfx.drawTextCentered(state.fonts.small, stats, center_x, panel.y + 181, 10.5, 1.15, C.muted);

    var best_buf: [48]u8 = undefined;
    const best_text = std.fmt.bufPrint(&best_buf, "BEST  {d}", .{state.game.best}) catch "BEST";
    gfx.drawTextCentered(state.fonts.small, best_text, center_x, panel.y + 211, 13, 1.0, C.gold);
    if (state.game.score >= state.game.best and state.game.score > 0) {
        gfx.drawTextCentered(state.fonts.small, "NEW SESSION RECORD", center_x, panel.y + 232, 9, 1.4, C.orange);
    }

    const pulse = 0.6 + 0.4 * std.math.sin(state.time * 3.2);
    const button = gfx.rect(panel.x + 26, panel.y + panel.height - 70, panel.width - 52, 40);
    rl.drawRectangleRounded(button, 0.28, 5, C.surface_alt);
    rl.drawRectangleRoundedLinesEx(button, 0.28, 5, 1.2, C.cyan.fade(0.3 + pulse * 0.45));
    gfx.drawTextCentered(state.fonts.small, "ENTER OR R TO RESTART", center_x, button.y + 12, 10.5, 1.25, C.text.fade(0.85 + pulse * 0.15));
    gfx.drawTextCentered(state.fonts.small, "THANKS FOR PLAYING", center_x, panel.y + panel.height - 18, 9, 1.3, C.dim);
}
