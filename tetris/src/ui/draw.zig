//! Low-level drawing helpers: geometry, text and tetromino blocks.

const rl = @import("raylib");

pub fn v2(x: f32, y: f32) rl.Vector2 {
    return .{ .x = x, .y = y };
}

pub fn rect(x: f32, y: f32, w: f32, h: f32) rl.Rectangle {
    return .{ .x = x, .y = y, .width = w, .height = h };
}

/// Raylib wants NUL-terminated strings. This thin helper keeps the rest of the
/// renderer free to pass ordinary slices, including formatted ones.
pub fn drawText(font: rl.Font, content: []const u8, x: f32, y: f32, size: f32, spacing: f32, color: rl.Color) void {
    var buffer: [512:0]u8 = undefined;
    const n = @min(content.len, buffer.len - 1);
    @memcpy(buffer[0..n], content[0..n]);
    buffer[n] = 0;
    rl.drawTextEx(font, buffer[0..n :0], v2(x, y), size, spacing, color);
}

pub fn textWidth(font: rl.Font, content: []const u8, size: f32, spacing: f32) f32 {
    var buffer: [512:0]u8 = undefined;
    const n = @min(content.len, buffer.len - 1);
    @memcpy(buffer[0..n], content[0..n]);
    buffer[n] = 0;
    return rl.measureTextEx(font, buffer[0..n :0], size, spacing).x;
}

pub fn drawTextCentered(font: rl.Font, content: []const u8, center_x: f32, y: f32, size: f32, spacing: f32, color: rl.Color) void {
    drawText(font, content, center_x - textWidth(font, content, size, spacing) / 2, y, size, spacing, color);
}

pub fn drawTextRight(font: rl.Font, content: []const u8, right_x: f32, y: f32, size: f32, spacing: f32, color: rl.Color) void {
    drawText(font, content, right_x - textWidth(font, content, size, spacing), y, size, spacing, color);
}

pub fn drawLabel(font: rl.Font, content: []const u8, x: f32, y: f32, color: rl.Color) void {
    drawText(font, content, x, y, 10.5, 1.8, color);
}

pub fn drawBlock(x: f32, y: f32, size: f32, color: rl.Color, alpha: f32, glow: bool) void {
    if (glow) {
        const center = v2(x + size / 2, y + size / 2);
        rl.drawCircleGradient(center, size * 0.86, color.fade(0.11 * alpha), color.fade(0.0));
    }

    const pad = @max(1.0, size * 0.055);
    const outer = rect(x + pad, y + pad, size - pad * 2, size - pad * 2);
    rl.drawRectangleRounded(outer, 0.24, 4, color.brightness(-0.38).fade(alpha));

    const inset = @max(1.4, size * 0.08);
    const inner = rect(outer.x + inset, outer.y + inset, outer.width - inset * 2, outer.height - inset * 2);
    rl.drawRectangleRounded(inner, 0.2, 4, color.fade(alpha));

    const sheen = rect(inner.x + 1, inner.y + 1.2, inner.width - 2, inner.height * 0.24);
    rl.drawRectangleRounded(sheen, 0.55, 3, color.brightness(0.34).fade(alpha * 0.68));

    const under = rect(inner.x + 2, inner.y + inner.height - 3.0, inner.width - 4, 1.4);
    rl.drawRectangleRounded(under, 0.8, 2, color.brightness(-0.52).fade(alpha * 0.55));
}
