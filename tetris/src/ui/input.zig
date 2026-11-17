//! Keyboard polling for gameplay actions (movement, drops, rotation, hold).

const rl = @import("raylib");
const game_mod = @import("../game/game.zig");

const DAS_DELAY: f32 = 0.15;
const ARR_INTERVAL: f32 = 0.045;
const SOFT_DROP_INTERVAL: f32 = 0.035;

pub fn pressedAny(keys: []const rl.KeyboardKey) bool {
    for (keys) |key| {
        if (rl.isKeyPressed(key)) return true;
    }
    return false;
}

pub fn downAny(keys: []const rl.KeyboardKey) bool {
    for (keys) |key| {
        if (rl.isKeyDown(key)) return true;
    }
    return false;
}

pub const InputState = struct {
    held_dir: i8 = 0,
    das_timer: f32 = 0,
    soft_timer: f32 = 0,

    pub fn reset(self: *InputState) void {
        self.held_dir = 0;
        self.das_timer = 0;
        self.soft_timer = 0;
    }

    pub fn updateGameplay(self: *InputState, game: *game_mod.Game, dt: f32) void {
        if (game.phase != .playing) {
            self.reset();
            return;
        }

        if (pressedAny(&.{ .x, .up, .w })) {
            _ = game.rotate(true);
        }
        if (pressedAny(&.{ .z, .left_control })) {
            _ = game.rotate(false);
        }
        if (pressedAny(&.{.space})) {
            game.hardDrop();
        }
        if (pressedAny(&.{ .c, .left_shift, .right_shift })) {
            game.holdPiece();
        }

        const left = downAny(&.{ .a, .left });
        const right = downAny(&.{ .d, .right });
        var dir: i8 = 0;
        if (left and !right) dir = -1;
        if (right and !left) dir = 1;

        if (dir == 0) {
            self.held_dir = 0;
        } else if (self.held_dir != dir) {
            self.held_dir = dir;
            _ = game.move(dir);
            self.das_timer = DAS_DELAY;
        } else {
            self.das_timer -= dt;
            if (self.das_timer <= 0) {
                _ = game.move(dir);
                self.das_timer = ARR_INTERVAL;
            }
        }

        const soft = downAny(&.{ .s, .down });
        if (soft) {
            self.soft_timer -= dt;
            if (pressedAny(&.{ .s, .down }) or self.soft_timer <= 0) {
                _ = game.softDrop();
                self.soft_timer = SOFT_DROP_INTERVAL;
            }
        } else {
            self.soft_timer = 0;
        }
    }
};
