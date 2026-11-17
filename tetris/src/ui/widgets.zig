//! Reusable HUD components: panels, card headers, keycaps and piece previews.

const rl = @import("raylib");
const piece = @import("../game/piece.zig");
const theme = @import("theme.zig");
const draw = @import("draw.zig");
const Fonts = @import("fonts.zig").Fonts;

pub fn drawPanel(r: rl.Rectangle, fill: rl.Color, border: rl.Color) void {
    rl.drawRectangleRounded(draw.rect(r.x + 2, r.y + 8, r.width, r.height), theme.CARD_RADIUS, 8, rl.Color.init(0, 0, 0, 95));
    rl.drawRectangleRounded(r, theme.CARD_RADIUS, 8, fill);
    rl.drawRectangleRoundedLinesEx(r, theme.CARD_RADIUS, 8, 1.0, border);
    rl.drawLineEx(draw.v2(r.x + 12, r.y + 1), draw.v2(r.x + r.width - 12, r.y + 1), 1, rl.Color.init(255, 255, 255, 12));
}

pub fn drawCardAccent(r: rl.Rectangle, color: rl.Color, strength: f32) void {
    if (strength <= 0) return;
    rl.drawRectangleRoundedLinesEx(r, theme.CARD_RADIUS, 8, 1.0 + strength, color.fade(0.35 + strength * 0.35));
}

pub fn drawCardHeader(fonts: *const Fonts, r: rl.Rectangle, title: []const u8, trailing: []const u8) void {
    draw.drawLabel(fonts.small, title, r.x + 20, r.y + 17, theme.C.muted);
    if (trailing.len > 0) {
        draw.drawTextRight(fonts.small, trailing, r.x + r.width - 20, r.y + 17, 10, 1.3, theme.C.dim);
    }
    rl.drawLineEx(draw.v2(r.x + 20, r.y + 37), draw.v2(r.x + r.width - 20, r.y + 37), 1, theme.C.border_soft);
}

pub fn drawKeycap(fonts: *const Fonts, r: rl.Rectangle, label: []const u8) void {
    rl.drawRectangleRounded(r, 0.3, 5, theme.C.surface_alt);
    rl.drawRectangleRoundedLinesEx(r, 0.3, 5, 1, theme.C.border);
    draw.drawTextCentered(fonts.small, label, r.x + r.width / 2, r.y + 4, 9, 0.5, theme.C.muted);
}

pub fn drawPiecePreview(kind: piece.PieceKind, center_x: f32, center_y: f32, cell_size: f32, alpha: f32) void {
    const preview = piece.Piece{ .kind = kind, .rotation = 0, .x = 0, .y = 0 };
    var min_x: i32 = 4;
    var max_x: i32 = -1;
    var min_y: i32 = 4;
    var max_y: i32 = -1;
    for (preview.cells()) |pos| {
        min_x = @min(min_x, pos.x);
        max_x = @max(max_x, pos.x);
        min_y = @min(min_y, pos.y);
        max_y = @max(max_y, pos.y);
    }

    const width = @as(f32, @floatFromInt(max_x - min_x + 1)) * cell_size;
    const height = @as(f32, @floatFromInt(max_y - min_y + 1)) * cell_size;
    const start_x = center_x - width / 2;
    const start_y = center_y - height / 2;
    const visual = theme.pieceVisual(kind);

    for (preview.cells()) |pos| {
        const x = start_x + @as(f32, @floatFromInt(pos.x - min_x)) * cell_size;
        const y = start_y + @as(f32, @floatFromInt(pos.y - min_y)) * cell_size;
        draw.drawBlock(x, y, cell_size, visual.base, alpha, false);
    }
}
