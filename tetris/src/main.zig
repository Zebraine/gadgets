//! Entry point: parse options, acquire resources, then hand the frame loop to
//! the application layer.

const std = @import("std");
const rl = @import("raylib");
const cli = @import("cli.zig");
const demo = @import("demo.zig");
const game_mod = @import("game/game.zig");
const App = @import("app.zig").App;
const audio_mod = @import("ui/audio.zig");
const capture = @import("capture.zig");
const Fonts = @import("ui/fonts.zig").Fonts;
const theme = @import("ui/theme.zig");
const window = @import("ui/window.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const options = cli.parseOptions(init, allocator) catch |err| {
        std.debug.print("Could not parse arguments: {s}\n\n{s}\n", .{ @errorName(err), cli.USAGE });
        return;
    };

    if (options.help) {
        std.debug.print("{s}\n", .{cli.USAGE});
        return;
    }

    const screenshot_mode = options.screenshot_path != null;
    const seed = options.seed orelse if (screenshot_mode)
        @as(u64, 0x5445_5452_4953)
    else
        cli.currentSeed(init.io);

    window.init();
    defer window.deinit();

    var fonts = try Fonts.load();
    defer fonts.deinit();

    var audio_system: ?audio_mod.AudioSystem = null;
    if (!screenshot_mode) {
        audio_system = audio_mod.AudioSystem.init(allocator);
    }
    defer if (audio_system) |*system| system.deinit();

    const game = if (options.demo or options.scene != null)
        demo.createGame(seed)
    else
        game_mod.Game.init(seed);

    var app = App.init(
        game,
        &fonts,
        if (audio_system) |*system| system else null,
        seed,
    );

    if (options.scene) |scene| {
        demo.applyScene(&app.game, &app.effects, scene);
    }

    var capture_target: ?capture.Target = null;
    if (screenshot_mode) {
        capture_target = try capture.Target.init(theme.WINDOW_W, theme.WINDOW_H);
    }
    defer if (capture_target) |*target| target.deinit();

    var capture_countdown: u8 = 4;
    var should_close = false;

    while (!should_close and !rl.windowShouldClose()) {
        const dt = @min(rl.getFrameTime(), 0.05);
        app.update(dt, !screenshot_mode);

        rl.beginDrawing();
        if (capture_target) |*target| {
            target.begin();
            app.drawSized(theme.VW, theme.VH);
            target.end();
        } else {
            app.draw();
        }
        rl.endDrawing();

        if (screenshot_mode) {
            if (capture_countdown > 0) {
                capture_countdown -= 1;
            } else {
                try capture_target.?.save(options.screenshot_path.?);
                should_close = true;
            }
        }
    }

    if (screenshot_mode) {
        std.debug.print("Saved {d}x{d} screenshot to {s}\n", .{
            theme.WINDOW_W,
            theme.WINDOW_H,
            options.screenshot_path.?,
        });
    }
}
