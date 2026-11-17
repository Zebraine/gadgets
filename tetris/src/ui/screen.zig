//! Virtual-canvas composition and camera/scaling for the whole frame.

const std = @import("std");
const rl = @import("raylib");
const theme = @import("theme.zig");
const draw = @import("draw.zig");
const background = @import("background.zig");
const hud_left = @import("hud_left.zig");
const hud_right = @import("hud_right.zig");
const playfield = @import("playfield.zig");
const overlays = @import("overlays.zig");
const RenderState = @import("state.zig").RenderState;

const C = theme.C;

pub fn drawFrame(state: *const RenderState, screen_w: f32, screen_h: f32) void {
    const scale = @min(screen_w / theme.VW, screen_h / theme.VH);
    const offset_x = (screen_w - theme.VW * scale) / 2;
    const offset_y = (screen_h - theme.VH * scale) / 2;

    rl.clearBackground(C.void_bg);

    var shake_x: f32 = 0;
    var shake_y: f32 = 0;
    if (state.effects.shake_timer > 0) {
        const strength = state.effects.shake;
        shake_x = std.math.sin(state.time * 96.0) * strength;
        shake_y = std.math.cos(state.time * 81.0 + 1.2) * strength * 0.7;
    }

    const camera = rl.Camera2D{
        .offset = draw.v2(offset_x + shake_x, offset_y + shake_y),
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = scale,
    };
    const pad: f32 = 48;
    const view_left = -(offset_x + shake_x) / scale - pad;
    const view_top = -(offset_y + shake_y) / scale - pad;
    const view_width = screen_w / scale + pad * 2;
    const view_height = screen_h / scale + pad * 2;

    camera.begin();
    background.drawBackground(state.time, view_left, view_top, view_width, view_height);
    hud_left.draw(state);
    playfield.draw(state);
    hud_right.draw(state);
    drawFooter(state);
    state.effects.drawParticles();
    state.effects.drawBanner(state.fonts);
    overlays.draw(state);
    camera.end();
}

fn drawFooter(state: *const RenderState) void {
    const center_x = theme.BOARD_X + theme.BOARD_W / 2;
    draw.drawTextCentered(state.fonts.small, "ZIG + RAYLIB  //  SRS  /  7-BAG", center_x, 724, 10, 1.4, C.muted);

    rl.drawLineEx(draw.v2(center_x - 155, 731), draw.v2(center_x - 66, 731), 1, C.border_soft.fade(0.75));
    rl.drawLineEx(draw.v2(center_x + 66, 731), draw.v2(center_x + 155, 731), 1, C.border_soft.fade(0.75));
    rl.drawCircleV(draw.v2(center_x - 58, 731), 1.5, C.cyan.fade(0.65));
    rl.drawCircleV(draw.v2(center_x + 58, 731), 1.5, C.orange.fade(0.65));
}
