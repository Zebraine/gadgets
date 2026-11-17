//! Full-window procedural backdrop: gradient, light pools, grid and dust.

const std = @import("std");
const rl = @import("raylib");
const theme = @import("theme.zig");
const draw = @import("draw.zig");

const C = theme.C;

pub fn drawBackground(time: f32, view_left: f32, view_top: f32, view_width: f32, view_height: f32) void {
    const view_right = view_left + view_width;
    const view_bottom = view_top + view_height;

    // Paint the full visible virtual area, not only the 1200x800 design canvas.
    // A very wide/tall window (common with tiling window managers) therefore
    // gets continuous scenery instead of black letterbox bars.
    rl.drawRectangleGradientV(
        @intFromFloat(view_left),
        @intFromFloat(view_top),
        @intFromFloat(view_width),
        @intFromFloat(view_height),
        C.bg_top,
        C.bg_bottom,
    );

    // Soft ambient light pools.
    rl.drawCircleGradient(draw.v2(view_left + 260, view_top + 160), 430, rl.Color.init(24, 53, 94, 24), C.bg_top.fade(0.0));
    rl.drawCircleGradient(draw.v2(view_left + 980, view_bottom - 190), 380, rl.Color.init(74, 39, 112, 22), C.bg_bottom.fade(0.0));
    rl.drawCircleGradient(draw.v2(view_left + 605, view_top + 390), 330, rl.Color.init(18, 72, 96, 12), C.bg_bottom.fade(0.0));

    const grid = rl.Color.init(101, 128, 167, 10);
    var x = @floor(view_left / 40.0) * 40.0;
    while (x <= view_right) : (x += 40) {
        rl.drawLineEx(draw.v2(x, view_top), draw.v2(x, view_bottom), 1.0, grid);
    }
    var y = @floor(view_top / 40.0) * 40.0;
    while (y <= view_bottom) : (y += 40) {
        rl.drawLineEx(draw.v2(view_left, y), draw.v2(view_right, y), 1.0, grid);
    }

    // Sparse, gently drifting dust over the whole visible area.
    for (0..52) |i| {
        const fraction_x: f32 = @as(f32, @floatFromInt((i * 197 + 41) % 1200)) / 1200.0;
        const fraction_y: f32 = @as(f32, @floatFromInt((i * 283 + 113) % 800)) / 800.0;
        const sx = view_left + fraction_x * view_width;
        var sy = view_top + fraction_y * view_height - time * (3.0 + @as(f32, @floatFromInt(i % 5)));
        while (sy < view_top) sy += view_height;
        const twinkle = 0.5 + 0.5 * std.math.sin(time * 0.8 + @as(f32, @floatFromInt(i)));
        const color = if (i % 3 == 0) C.cyan else if (i % 3 == 1) C.violet else C.muted;
        rl.drawCircleV(draw.v2(sx, sy), 0.8 + twinkle * 0.9, color.fade(0.07 + twinkle * 0.12));
    }

    rl.drawLineEx(draw.v2(48, 36), draw.v2(theme.VW - 48, 36), 1, rl.Color.init(72, 95, 130, 22));
    rl.drawLineEx(draw.v2(48, theme.VH - 36), draw.v2(theme.VW - 48, theme.VH - 36), 1, rl.Color.init(72, 95, 130, 14));
}
