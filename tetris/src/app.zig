//! Application state and glue between gameplay, input, audio and rendering.

const std = @import("std");

const rl = @import("raylib");
const game_mod = @import("game/game.zig");
const input_mod = @import("ui/input.zig");
const audio_mod = @import("ui/audio.zig");
const Fonts = @import("ui/fonts.zig").Fonts;
const Effects = @import("ui/effects.zig").Effects;
const RenderState = @import("ui/state.zig").RenderState;
const screen = @import("ui/screen.zig");
const theme = @import("ui/theme.zig");

const C = theme.C;

pub const App = struct {
    game: game_mod.Game,
    fonts: *const Fonts,
    effects: Effects,
    controls: input_mod.InputState,
    audio: ?*audio_mod.AudioSystem,

    time: f32 = 0,
    display_score: f64,
    display_best: f64,
    move_sfx_timer: f32 = 0,

    pub fn init(
        game: game_mod.Game,
        fonts: *const Fonts,
        audio: ?*audio_mod.AudioSystem,
        seed: u64,
    ) App {
        return .{
            .game = game,
            .fonts = fonts,
            .effects = Effects.init(seed),
            .controls = .{},
            .audio = audio,
            .display_score = @floatFromInt(game.score),
            .display_best = @floatFromInt(@max(game.best, game.score)),
        };
    }

    pub fn update(self: *App, dt: f32, interactive: bool) void {
        self.time += dt;
        if (interactive) self.handleInput(dt);

        self.game.update(dt);
        self.effects.update(dt);
        self.move_sfx_timer = @max(0, self.move_sfx_timer - dt);
        self.drainGameEvents();
        self.tweenHud(dt);
    }

    pub fn draw(self: *const App) void {
        self.drawSized(
            @floatFromInt(rl.getScreenWidth()),
            @floatFromInt(rl.getScreenHeight()),
        );
    }

    pub fn drawSized(self: *const App, width: f32, height: f32) void {
        var state = RenderState{
            .game = &self.game,
            .fonts = self.fonts,
            .effects = &self.effects,
            .display_score = self.display_score,
            .display_best = self.display_best,
            .time = self.time,
        };
        screen.drawFrame(&state, width, height);
    }

    fn handleInput(self: *App, dt: f32) void {
        const game = &self.game;

        if (input_mod.pressedAny(&.{ .p, .escape })) {
            if (game.phase == .playing or game.phase == .paused) {
                game.togglePause();
                self.controls.reset();
            }
        }

        if (input_mod.pressedAny(&.{.m})) {
            if (self.audio) |audio| audio.toggleMute();
        }

        if (input_mod.pressedAny(&.{.f11})) {
            rl.toggleFullscreen();
        }

        if (input_mod.pressedAny(&.{.r})) {
            self.restartGame();
            return;
        }

        if (game.phase == .game_over and input_mod.pressedAny(&.{.enter})) {
            self.restartGame();
            return;
        }

        if (game.phase != .playing) {
            self.controls.reset();
            return;
        }

        self.controls.updateGameplay(game, dt);
    }

    fn restartGame(self: *App) void {
        self.game.restart();
        self.effects.clear();
        self.controls.reset();
        self.display_score = 0;
        self.display_best = @floatFromInt(@max(self.game.best, self.game.score));
        self.move_sfx_timer = 0;
    }

    fn drainGameEvents(self: *App) void {
        var hard_dropped = false;
        while (self.game.nextEvent()) |event| {
            switch (event) {
                .move => {
                    if (self.move_sfx_timer <= 0) {
                        self.playSfx(.move);
                        self.move_sfx_timer = 0.05;
                    }
                },
                .rotate => self.playSfx(.rotate),
                .hold => {
                    self.effects.hold_pulse = 1.0;
                    self.playSfx(.hold);
                },
                .lock => if (!hard_dropped) self.playSfx(.lock),
                .hard_drop => |distance| {
                    hard_dropped = true;
                    self.playSfx(.hard_drop);
                    if (distance >= 8) {
                        self.effects.kickShake(@min(4.5, @as(f32, @floatFromInt(distance)) * 0.18));
                    }
                },
                .line_clear => |info| {
                    self.effects.flash = 0.55;
                    self.effects.score_pulse = 1.0;
                    self.effects.kickShake(3.0 + @as(f32, @floatFromInt(info.count)) * 0.7);
                    self.effects.burstRows(&self.game, info);

                    const titles = [5][]const u8{ "", "SINGLE", "DOUBLE", "TRIPLE", "TETRIS!" };
                    const colors = [5]rl.Color{ C.text, C.cyan, C.green, C.violet, C.orange };
                    const index = @min(info.count, 4);
                    var buffer: [48]u8 = undefined;
                    const subtitle = std.fmt.bufPrint(&buffer, "+{d} PTS", .{info.points}) catch "";
                    self.effects.banner.show(titles[index], subtitle, colors[index], 1.15);
                    self.playSfx(if (info.count >= 4) .tetris else .clear);
                },
                .level_up => |level| {
                    self.effects.level_pulse = 1.0;
                    // A level-up usually rides along with a line clear. Do not
                    // replace the more celebratory clear banner on that frame.
                    if (self.effects.banner.timer <= 0) {
                        var buffer: [48]u8 = undefined;
                        const title = std.fmt.bufPrint(&buffer, "LEVEL {d}", .{level}) catch "LEVEL UP";
                        self.effects.banner.show(title, "SPEED INCREASED", C.orange, 1.0);
                    }
                    self.playSfx(.level_up);
                },
                .game_over => {
                    self.effects.kickShake(5.0);
                    self.playSfx(.game_over);
                },
            }
        }
    }

    fn playSfx(self: *App, id: audio_mod.Sfx) void {
        if (self.audio) |audio| audio.play(id);
    }

    fn tweenHud(self: *App, dt: f32) void {
        const target_score: f64 = @floatFromInt(self.game.score);
        const target_best: f64 = @floatFromInt(@max(self.game.best, self.game.score));
        self.display_score += (target_score - self.display_score) * @min(1.0, @as(f64, dt) * 12);
        self.display_best += (target_best - self.display_best) * @min(1.0, @as(f64, dt) * 8);
    }
};
