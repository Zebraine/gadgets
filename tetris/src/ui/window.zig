//! Window creation, icon and platform-facing setup.

const rl = @import("raylib");
const theme = @import("theme.zig");

pub const TITLE = "TETRIS // Zig + Raylib";

pub fn init() void {
    rl.setConfigFlags(.{
        .window_resizable = true,
        .msaa_4x_hint = true,
        .vsync_hint = true,
    });
    rl.initWindow(theme.WINDOW_W, theme.WINDOW_H, TITLE);
    rl.setExitKey(.null);
    rl.setWindowMinSize(900, 600);
    rl.setTargetFPS(60);
    rl.hideCursor();
    installIcon();
}

pub fn deinit() void {
    rl.closeWindow();
}

fn installIcon() void {
    var icon = rl.genImageColor(64, 64, theme.C.bg_bottom);
    rl.imageDrawRectangle(&icon, 0, 0, 64, 64, theme.C.surface);
    const blocks = [4][2]i32{
        .{ 24, 10 },
        .{ 10, 27 },
        .{ 24, 27 },
        .{ 38, 27 },
    };
    const colors = [4]rl.Color{ theme.C.cyan, theme.C.violet, theme.C.cyan, theme.C.violet };
    for (blocks, 0..) |pos, i| {
        rl.imageDrawRectangle(&icon, pos[0], pos[1], 14, 14, colors[i]);
    }
    rl.setWindowIcon(icon);
    rl.unloadImage(icon);
}
