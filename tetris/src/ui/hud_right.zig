//! Right HUD column: hold slot, next queue and session best.

const std = @import("std");
const rl = @import("raylib");
const theme = @import("theme.zig");
const gfx = @import("draw.zig");
const widgets = @import("widgets.zig");
const RenderState = @import("state.zig").RenderState;

const C = theme.C;

pub fn draw(state: *const RenderState) void {
    drawHold(state);
    drawNext(state);
    drawBest(state);
}

fn drawHold(state: *const RenderState) void {
    const r = gfx.rect(theme.RIGHT_X, 100, theme.RIGHT_W, 142);
    widgets.drawPanel(r, C.surface, C.border);
    widgets.drawCardAccent(r, C.cyan, state.effects.hold_pulse);
    widgets.drawCardHeader(state.fonts, r, "HOLD", "");
    widgets.drawKeycap(state.fonts, gfx.rect(r.x + r.width - 38, r.y + 12, 21, 18), "C");

    const center = gfx.v2(r.x + r.width / 2, r.y + 87);
    if (state.game.hold) |kind| {
        const alpha: f32 = if (state.game.can_hold) 1.0 else 0.4;
        widgets.drawPiecePreview(kind, center.x, center.y, 25, alpha);
        if (!state.game.can_hold) {
            gfx.drawTextCentered(state.fonts.small, "USED", center.x, r.y + r.height - 19, 9, 1.5, C.dim);
        }
    } else {
        const empty = gfx.rect(center.x - 56, center.y - 27, 112, 54);
        rl.drawRectangleRounded(empty, 0.24, 5, C.board.fade(0.7));
        rl.drawRectangleRoundedLinesEx(empty, 0.24, 5, 1, C.border_soft);
        gfx.drawTextCentered(state.fonts.small, "EMPTY", center.x, center.y - 5, 10, 1.7, C.dim);
    }
}

fn drawNext(state: *const RenderState) void {
    const r = gfx.rect(theme.RIGHT_X, 258, theme.RIGHT_W, 316);
    widgets.drawPanel(r, C.surface, C.border);
    widgets.drawCardHeader(state.fonts, r, "NEXT", "7-BAG");

    const slot_height: f32 = 82;
    for (0..3) |i| {
        const slot_y = r.y + 47 + @as(f32, @floatFromInt(i)) * slot_height;
        const slot = gfx.rect(r.x + 14, slot_y, r.width - 28, slot_height - 4);
        if (i == 0) {
            rl.drawRectangleRounded(slot, 0.16, 5, C.surface_alt.fade(0.58));
            rl.drawRectangleRoundedLinesEx(slot, 0.16, 5, 1, C.border_soft);
            const visual = theme.pieceVisual(state.game.next_queue[0]);
            rl.drawRectangleRounded(gfx.rect(slot.x, slot.y + 17, 3, slot.height - 34), 0.8, 3, visual.base.fade(0.8));
        }

        var idx_buf: [8]u8 = undefined;
        const idx_text = std.fmt.bufPrint(&idx_buf, "0{d}", .{i + 1}) catch "01";
        gfx.drawText(state.fonts.small, idx_text, r.x + 30, slot_y + 25, 11.5, 1.1, if (i == 0) C.muted else C.dim);

        const center_x = r.x + r.width / 2 + 26;
        const center_y = slot_y + (slot_height - 4) / 2;
        widgets.drawPiecePreview(state.game.next_queue[i], center_x, center_y, if (i == 0) 23 else 19, if (i == 0) 1.0 else 0.8);

        if (i < 2) {
            const line_y = slot_y + slot_height - 3;
            rl.drawLineEx(gfx.v2(r.x + 26, line_y), gfx.v2(r.x + r.width - 26, line_y), 1, C.border_soft.fade(0.8));
        }
    }
}

fn drawBest(state: *const RenderState) void {
    const r = gfx.rect(theme.RIGHT_X, 590, theme.RIGHT_W, 110);
    widgets.drawPanel(r, C.surface, C.border);
    gfx.drawLabel(state.fonts.small, "SESSION BEST", r.x + 20, r.y + 16, C.muted);

    var best_buf: [40]u8 = undefined;
    const best: u64 = if (state.display_best < 0) 0 else @intFromFloat(@round(state.display_best));
    const best_text = std.fmt.bufPrint(&best_buf, "{d}", .{best}) catch "0";
    gfx.drawText(state.fonts.display, best_text, r.x + 18, r.y + 38, 32, 0.6, C.gold);

    gfx.drawText(state.fonts.small, "KEEP THE STACK ALIVE", r.x + 20, r.y + r.height - 25, 9, 1.45, C.dim);

    const star_center = gfx.v2(r.x + r.width - 45, r.y + 53);
    rl.drawCircleGradient(star_center, 28, C.gold.fade(0.1), C.surface.fade(0.0));
    rl.drawPoly(star_center, 4, 12, 45, C.gold.fade(0.16));
    rl.drawPolyLinesEx(star_center, 4, 12, 45, 1.4, C.gold.fade(0.7));
    rl.drawPoly(star_center, 4, 4.5, 45, C.gold.fade(0.8));
}
