//! Command-line parsing and the screenshot scene selector.

const std = @import("std");

pub const Scene = enum { play, paused, clear, game_over };

pub const Options = struct {
    screenshot_path: ?[:0]const u8 = null,
    demo: bool = false,
    scene: ?Scene = null,
    seed: ?u64 = null,
    help: bool = false,
};

pub const USAGE =
    \\TETRIS - a neon block-stacking game built with Zig + Raylib
    \\
    \\Usage:
    \\  zig build run
    \\  zig build run -- [options]
    \\
    \\Options:
    \\  --demo                 Start with a curated mid-game board.
    \\  --seed <number>        Seed the piece randomizer.
    \\  --screenshot <path>    Render a frame, save a PNG, then exit.
    \\  --scene <name>         Screenshot board: play, paused, clear, game_over.
    \\  -h, --help             Show this help.
    \\
    \\Controls:
    \\  A/D or Left/Right      Move
    \\  S or Down              Soft drop
    \\  Space                  Hard drop
    \\  X / Up / W             Rotate clockwise
    \\  Z / Left Ctrl          Rotate counter-clockwise
    \\  C / Shift              Hold
    \\  P / Escape             Pause
    \\  R                      Restart
    \\  M                      Mute sound
    \\  F11                    Toggle fullscreen
    \\
;

pub fn parseOptions(init: std.process.Init, allocator: std.mem.Allocator) !Options {
    var options = Options{};
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.next();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.help = true;
        } else if (std.mem.eql(u8, arg, "--demo")) {
            options.demo = true;
        } else if (std.mem.eql(u8, arg, "--screenshot")) {
            const value = args.next() orelse return error.MissingScreenshotPath;
            options.screenshot_path = try allocator.dupeSentinel(u8, value, 0);
        } else if (std.mem.eql(u8, arg, "--scene")) {
            const value = args.next() orelse return error.MissingScene;
            options.scene = if (std.mem.eql(u8, value, "play"))
                .play
            else if (std.mem.eql(u8, value, "paused"))
                .paused
            else if (std.mem.eql(u8, value, "clear"))
                .clear
            else if (std.mem.eql(u8, value, "game_over"))
                .game_over
            else
                return error.UnknownScene;
        } else if (std.mem.eql(u8, arg, "--seed")) {
            const value = args.next() orelse return error.MissingSeed;
            options.seed = try std.fmt.parseInt(u64, value, 0);
        } else {
            return error.UnknownOption;
        }
    }
    return options;
}

pub fn currentSeed(io: std.Io) u64 {
    const timestamp = std.Io.Clock.real.now(io);
    const value: u96 = @bitCast(timestamp.nanoseconds);
    return @truncate(value);
}
