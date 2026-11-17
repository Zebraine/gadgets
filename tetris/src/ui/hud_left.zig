//! Left HUD column: logo, score, level/lines and control legend.

const std = @import("std");
const rl = @import("raylib");
const theme = @import("theme.zig");
const gfx = @import("draw.zig");
const widgets = @import("widgets.zig");
const RenderState = @import("state.zig").RenderState;

const C = theme.C;

pub fn draw(state: *const RenderState) void {
    drawLogo(state);
    drawScoreCard(state);
    drawLevelAndLines(state);
    drawControls(state);
}

fn drawLogo(state: *const RenderState) void {
    const mark_x: f32 = theme.LEFT_X;
    const mark_y: f32 = 67;
    const tile: f32 = 12;
    const gap: f32 = 3;
    const shape = [4][2]i32{
        .{ 1, 0 },
        .{ 0, 1 },
        .{ 1, 1 },
        .{ 2, 1 },
    };
    for (shape, 0..) |pos, i| {
        const px = mark_x + @as(f32, @floatFromInt(pos[0])) * (tile + gap);
        const py = mark_y + @as(f32, @floatFromInt(pos[1])) * (tile + gap);
        const color = if (i == 0) C.cyan else C.violet;
        rl.drawRectangleRounded(gfx.rect(px, py, tile, tile), 0.22, 4, color.brightness(-0.42));
        rl.drawRectangleRounded(gfx.rect(px + 2, py + 2, tile - 4, tile - 4), 0.2, 4, color);
    }

    gfx.drawText(state.fonts.display, "TETRIS", 140, 49, 60, 1.0, C.violet.fade(0.24));
    gfx.drawText(state.fonts.display, "TETRIS", 140, 46, 60, 1.0, C.text);
    gfx.drawText(state.fonts.small, "STACK / CLEAR / REPEAT", theme.LEFT_X, 126, 10.5, 1.25, C.muted);

    rl.drawLineEx(gfx.v2(theme.LEFT_X, 151), gfx.v2(theme.LEFT_X + theme.LEFT_W, 151), 1, C.border_soft);
    rl.drawLineEx(gfx.v2(theme.LEFT_X, 151), gfx.v2(theme.LEFT_X + 54, 151), 2, C.cyan.fade(0.72));
}

fn drawScoreCard(state: *const RenderState) void {
    const r = gfx.rect(theme.LEFT_X, 168, theme.LEFT_W, 112);
    widgets.drawPanel(r, C.surface, C.border);
    widgets.drawCardAccent(r, C.cyan, state.effects.score_pulse);

    drawRectangleAccent(r, C.cyan);
    gfx.drawLabel(state.fonts.small, "SCORE", r.x + 20, r.y + 16, C.muted);

    var score_buf: [40]u8 = undefined;
    const score: u64 = if (state.display_score < 0) 0 else @intFromFloat(@round(state.display_score));
    const score_text = std.fmt.bufPrint(&score_buf, "{d}", .{score}) catch "0";
    gfx.drawText(state.fonts.display, score_text, r.x + 18, r.y + 38, 38, 0.6, C.text);

    var combo_buf: [32]u8 = undefined;
    const combo_text = std.fmt.bufPrint(&combo_buf, "COMBO x{d}", .{state.game.combo}) catch "COMBO";
    if (state.game.combo > 1) {
        const chip_w: f32 = 84;
        const chip = gfx.rect(r.x + r.width - chip_w - 16, r.y + 16, chip_w, 21);
        rl.drawRectangleRounded(chip, 0.45, 5, C.orange.fade(0.12));
        rl.drawRectangleRoundedLinesEx(chip, 0.45, 5, 1, C.orange.fade(0.55));
        gfx.drawTextCentered(state.fonts.small, combo_text, chip.x + chip.width / 2, chip.y + 6, 9, 1.1, C.orange);
    } else {
        rl.drawCircleV(gfx.v2(r.x + r.width - 30, r.y + 30), 3, C.cyan.fade(0.8));
        rl.drawCircleV(gfx.v2(r.x + r.width - 30, r.y + 30), 9, C.cyan.fade(0.08));
    }

    gfx.drawText(state.fonts.small, "TIME", r.x + 20, r.y + r.height - 26, 9.5, 1.8, C.dim);
    const seconds: u64 = @intFromFloat(@max(0, state.game.elapsed));
    var time_buf: [16]u8 = undefined;
    const time_text = std.fmt.bufPrint(&time_buf, "{d:0>2}:{d:0>2}", .{ seconds / 60, seconds % 60 }) catch "00:00";
    gfx.drawTextRight(state.fonts.small, time_text, r.x + r.width - 20, r.y + r.height - 28, 13, 0.8, C.muted);
}

fn drawRectangleAccent(r: rl.Rectangle, color: rl.Color) void {
    rl.drawRectangleRounded(gfx.rect(r.x + 1, r.y + 26, 3, 56), 0.9, 4, color.fade(0.85));
    rl.drawCircleV(gfx.v2(r.x + 2.5, r.y + 22), 2.3, color);
}

fn drawLevelAndLines(state: *const RenderState) void {
    const card_w: f32 = 148;
    const gap: f32 = 14;
    const y: f32 = 294;
    const level_r = gfx.rect(theme.LEFT_X, y, card_w, 94);
    const lines_r = gfx.rect(theme.LEFT_X + card_w + gap, y, card_w, 94);

    widgets.drawPanel(level_r, C.surface, C.border);
    widgets.drawPanel(lines_r, C.surface, C.border);
    widgets.drawCardAccent(level_r, C.cyan, state.effects.level_pulse);

    gfx.drawLabel(state.fonts.small, "LEVEL", level_r.x + 16, level_r.y + 14, C.muted);
    var level_buf: [20]u8 = undefined;
    const level_text = std.fmt.bufPrint(&level_buf, "{d:0>2}", .{state.game.level}) catch "01";
    gfx.drawText(state.fonts.display, level_text, level_r.x + 14, level_r.y + 33, 32, 0.8, C.cyan);

    gfx.drawLabel(state.fonts.small, "LINES", lines_r.x + 16, lines_r.y + 14, C.muted);
    var lines_buf: [20]u8 = undefined;
    const lines_text = std.fmt.bufPrint(&lines_buf, "{d}", .{state.game.lines}) catch "0";
    gfx.drawText(state.fonts.display, lines_text, lines_r.x + 14, lines_r.y + 33, 32, 0.8, C.orange);

    const track = gfx.rect(level_r.x + 16, level_r.y + level_r.height - 15, level_r.width - 32, 4);
    rl.drawRectangleRounded(track, 0.9, 3, C.surface_alt);
    const remainder: f32 = @floatFromInt(state.game.lines % 10);
    const progress = @max(0.03, remainder / 10.0);
    rl.drawRectangleRounded(gfx.rect(track.x, track.y, track.width * progress, track.height), 0.9, 3, C.cyan.fade(0.9));
    rl.drawCircleV(gfx.v2(track.x + track.width * progress, track.y + 2), 3.0, C.cyan);
}

fn drawControls(state: *const RenderState) void {
    const r = gfx.rect(theme.LEFT_X, 402, theme.LEFT_W, 298);
    widgets.drawPanel(r, C.surface, C.border);
    gfx.drawLabel(state.fonts.small, "CONTROLS", r.x + 20, r.y + 18, C.muted);
    rl.drawLineEx(gfx.v2(r.x + 92, r.y + 23), gfx.v2(r.x + r.width - 20, r.y + 23), 1, C.border_soft);

    const rows = [7]struct { key: []const u8, action: []const u8 }{
        .{ .key = "A / D", .action = "MOVE" },
        .{ .key = "S", .action = "SOFT DROP" },
        .{ .key = "SPACE", .action = "HARD DROP" },
        .{ .key = "X / UP", .action = "ROTATE CW" },
        .{ .key = "Z", .action = "ROTATE CCW" },
        .{ .key = "C", .action = "HOLD" },
        .{ .key = "P / ESC", .action = "PAUSE" },
    };

    for (rows, 0..) |row, i| {
        const row_y = r.y + 53 + @as(f32, @floatFromInt(i)) * 28;
        const key_rect = gfx.rect(r.x + 20, row_y - 4, 66, 21);
        rl.drawRectangleRounded(key_rect, 0.32, 5, C.surface_alt);
        rl.drawRectangleRoundedLinesEx(key_rect, 0.32, 5, 1, C.border);
        gfx.drawTextCentered(state.fonts.small, row.key, key_rect.x + key_rect.width / 2, row_y + 1, 10, 1.0, C.text);
        gfx.drawText(state.fonts.small, row.action, r.x + 101, row_y, 11.5, 1.05, C.muted);
    }

    rl.drawLineEx(gfx.v2(r.x + 20, r.y + r.height - 39), gfx.v2(r.x + r.width - 20, r.y + r.height - 39), 1, C.border_soft);
    gfx.drawText(state.fonts.small, "ARROWS + WASD SUPPORTED", r.x + 20, r.y + r.height - 27, 9.5, 1.3, C.dim);
}
