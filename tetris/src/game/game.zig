//! Tetris state machine. Rendering, input and audio are intentionally absent;
//! the only inbound calls are gameplay actions and `update`, and the only
//! outbound signals are `Event`s.

const std = @import("std");
const piece_mod = @import("piece.zig");
const board_mod = @import("board.zig");
const bag_mod = @import("bag.zig");
const scoring = @import("scoring.zig");
const event_mod = @import("events.zig");

pub const COLS = board_mod.COLS;
pub const ROWS = board_mod.ROWS;
pub const PieceKind = piece_mod.PieceKind;
pub const Piece = piece_mod.Piece;
pub const CellPos = piece_mod.CellPos;
pub const ClearInfo = event_mod.ClearInfo;
pub const Event = event_mod.Event;

pub const Phase = enum {
    playing,
    paused,
    clearing,
    game_over,
};

pub const Game = struct {
    board: board_mod.Board,
    active: Piece,
    next_queue: [3]PieceKind,
    hold: ?PieceKind,
    can_hold: bool,

    phase: Phase,
    score: u64,
    best: u64,
    lines: u32,
    level: u32,
    combo: u32,

    drop_timer: f32,
    lock_timer: f32,
    lock_resets: u8,
    clear_timer: f32,
    clear_rows: u32,
    elapsed: f32,

    bag: bag_mod.SevenBag,
    events: event_mod.EventQueue,

    pub const gravity_base: f32 = 0.85;
    pub const lock_delay: f32 = 0.45;
    pub const clear_duration: f32 = 0.28;

    pub fn init(seed: u64) Game {
        var game: Game = undefined;
        game.board = board_mod.Board.init();
        game.bag = bag_mod.SevenBag.init(seed);
        game.events = .{};
        game.best = 0;
        game.resetRound();
        return game;
    }

    pub fn restart(self: *Game) void {
        self.best = @max(self.best, self.score);
        self.resetRound();
    }

    fn resetRound(self: *Game) void {
        self.board.clear();
        self.bag.reset();

        self.hold = null;
        self.can_hold = true;
        self.phase = .playing;
        self.score = 0;
        self.lines = 0;
        self.level = 1;
        self.combo = 0;
        self.drop_timer = 0;
        self.lock_timer = 0;
        self.lock_resets = 0;
        self.clear_timer = 0;
        self.clear_rows = 0;
        self.elapsed = 0;
        self.events.clear();

        for (0..3) |i| {
            self.next_queue[i] = self.bag.next();
        }
        self.active = Piece.spawn(.t);
        self.spawnNext();
    }

    fn spawnNext(self: *Game) void {
        const kind = self.next_queue[0];
        std.mem.copyForwards(
            PieceKind,
            self.next_queue[0 .. self.next_queue.len - 1],
            self.next_queue[1..],
        );
        self.next_queue[self.next_queue.len - 1] = self.bag.next();

        self.active = Piece.spawn(kind);
        self.drop_timer = 0;
        self.lock_timer = 0;
        self.lock_resets = 0;
        self.can_hold = true;
        self.phase = .playing;

        if (!self.fits(self.active)) {
            self.endGame();
        }
    }

    fn endGame(self: *Game) void {
        if (self.phase == .game_over) return;
        self.phase = .game_over;
        self.best = @max(self.best, self.score);
        self.events.push(.game_over);
    }

    pub fn nextEvent(self: *Game) ?Event {
        return self.events.pop();
    }

    pub fn cell(self: *const Game, x: usize, y: usize) ?PieceKind {
        return self.board.cell(x, y);
    }

    pub fn activeCells(self: *const Game) [4]CellPos {
        return self.active.cells();
    }

    pub fn activeVisible(self: *const Game) bool {
        return self.phase == .playing or self.phase == .paused;
    }

    pub fn ghostY(self: *const Game) i32 {
        var y = self.active.y;
        while (y + 1 < ROWS) : (y += 1) {
            var candidate = self.active;
            candidate.y = y + 1;
            if (!self.fits(candidate)) break;
        }
        return y;
    }

    pub fn fits(self: *const Game, candidate: Piece) bool {
        return self.board.fits(candidate);
    }

    pub fn gravityInterval(self: *const Game) f32 {
        const level: f32 = @floatFromInt(self.level);
        const interval = gravity_base * std.math.pow(f32, 0.82, level - 1.0);
        return @max(0.055, interval);
    }

    pub fn isGrounded(self: *const Game) bool {
        var below = self.active;
        below.y += 1;
        return !self.fits(below);
    }

    fn bumpLockTimer(self: *Game) void {
        if (self.isGrounded() and self.lock_resets < 15) {
            self.lock_timer = 0;
            self.lock_resets += 1;
        }
    }

    pub fn move(self: *Game, dx: i32) bool {
        if (self.phase != .playing) return false;
        var candidate = self.active;
        candidate.x += dx;
        if (!self.fits(candidate)) return false;

        self.active = candidate;
        self.bumpLockTimer();
        self.events.push(.{ .move = dx });
        return true;
    }

    pub fn softDrop(self: *Game) bool {
        if (self.phase != .playing) return false;
        var candidate = self.active;
        candidate.y += 1;
        if (!self.fits(candidate)) return false;

        self.active = candidate;
        self.score += 1;
        self.drop_timer = 0;
        self.lock_timer = 0;
        return true;
    }

    pub fn hardDrop(self: *Game) void {
        if (self.phase != .playing) return;

        var distance: i32 = 0;
        while (true) {
            var candidate = self.active;
            candidate.y += 1;
            if (!self.fits(candidate)) break;
            self.active = candidate;
            distance += 1;
        }

        if (distance > 0) {
            self.score += @as(u64, @intCast(distance)) * 2;
        }
        self.events.push(.{ .hard_drop = distance });
        self.lockPiece();
    }

    pub fn rotate(self: *Game, clockwise: bool) bool {
        if (self.phase != .playing or self.active.kind == .o) return false;

        const from = self.active.rotation;
        const to = piece_mod.nextRotation(from, clockwise);
        for (piece_mod.kickTests(self.active.kind, from, to)) |kick| {
            var candidate = self.active;
            candidate.rotation = to;
            candidate.x += kick[0];
            candidate.y += kick[1];
            if (self.fits(candidate)) {
                self.active = candidate;
                self.bumpLockTimer();
                self.events.push(.{ .rotate = clockwise });
                return true;
            }
        }
        return false;
    }

    pub fn holdPiece(self: *Game) void {
        if (self.phase != .playing or !self.can_hold) return;

        const current = self.active.kind;
        if (self.hold) |held| {
            self.hold = current;
            self.setActive(held);
        } else {
            self.hold = current;
            self.spawnNext();
        }
        self.can_hold = false;
        self.events.push(.hold);
    }

    fn setActive(self: *Game, kind: PieceKind) void {
        self.active = Piece.spawn(kind);
        self.drop_timer = 0;
        self.lock_timer = 0;
        self.lock_resets = 0;

        if (!self.fits(self.active)) {
            self.endGame();
        }
    }

    pub fn togglePause(self: *Game) void {
        switch (self.phase) {
            .playing => self.phase = .paused,
            .paused => self.phase = .playing,
            else => {},
        }
    }

    pub fn update(self: *Game, dt: f32) void {
        self.elapsed += dt;

        switch (self.phase) {
            .playing => self.updatePlaying(dt),
            .clearing => {
                self.clear_timer -= dt;
                if (self.clear_timer <= 0) {
                    self.board.removeRows(self.clear_rows);
                    self.clear_rows = 0;
                    self.spawnNext();
                }
            },
            .paused, .game_over => {},
        }
    }

    fn updatePlaying(self: *Game, dt: f32) void {
        if (self.isGrounded()) {
            self.lock_timer += dt;
            if (self.lock_timer >= lock_delay) {
                self.lockPiece();
            }
            return;
        }

        self.lock_timer = 0;
        self.lock_resets = 0;
        self.drop_timer += dt;

        const interval = self.gravityInterval();
        while (self.drop_timer >= interval and self.phase == .playing) {
            self.drop_timer -= interval;
            var candidate = self.active;
            candidate.y += 1;
            if (!self.fits(candidate)) break;
            self.active = candidate;
        }
    }

    fn lockPiece(self: *Game) void {
        if (self.phase != .playing) return;

        self.board.lock(self.active);
        self.events.push(.lock);

        const full_rows = self.board.fullRows();
        const count: u8 = @intCast(@popCount(full_rows));
        if (count == 0) {
            self.combo = 0;
            self.spawnNext();
            return;
        }

        const points = self.addClearScore(count);
        self.phase = .clearing;
        self.clear_rows = full_rows;
        self.clear_timer = clear_duration;

        self.events.push(.{ .line_clear = .{
            .rows = full_rows,
            .count = count,
            .points = points,
            .level = self.level,
        } });
    }

    fn addClearScore(self: *Game, count: u8) u64 {
        const previous_level = self.level;
        const points = scoring.pointsForClear(count, self.level, self.combo);
        self.combo += 1;
        self.score += points;

        self.lines += count;
        self.level = scoring.levelForLines(self.lines);
        if (self.level > previous_level) {
            self.events.push(.{ .level_up = self.level });
        }
        return points;
    }
};

test "hard drop lands on the floor and locks" {
    var game = Game.init(7);
    game.hardDrop();
    try std.testing.expect(game.cell(3, 19) != null);
    try std.testing.expect(game.score >= 2);
    try std.testing.expect(game.phase == .clearing or game.phase == .playing);
}

test "line clear scores and collapses the board" {
    var game = Game.init(1);
    for (0..COLS) |col| {
        if (col != 5) game.board.cells[19][col] = .s;
    }
    game.active = .{ .kind = .i, .rotation = 1, .x = 3, .y = 0 };
    game.hardDrop();

    try std.testing.expect(game.phase == .clearing);
    try std.testing.expectEqual(@as(u8, 1), @as(u8, @intCast(@popCount(game.clear_rows))));
    try std.testing.expectEqual(@as(u64, 132), game.score);

    game.update(Game.clear_duration + 0.01);
    try std.testing.expect(game.phase == .playing);
    try std.testing.expectEqual(@as(u32, 1), game.lines);
    try std.testing.expect(game.cell(5, 19) != null);
}

test "wall kick moves a piece away from an obstruction" {
    var game = Game.init(3);
    game.board.clear();
    game.active = .{ .kind = .t, .rotation = 0, .x = 0, .y = 4 };
    // (1, 6) is the only cell that appears on the clockwise rotation, so the
    // untranslated kick fails and the (-1, 0) offset succeeds.
    game.board.cells[6][1] = .j;
    try std.testing.expect(game.rotate(true));
    try std.testing.expectEqual(@as(i32, -1), game.active.x);
    try std.testing.expectEqual(@as(u2, 1), game.active.rotation);
}

test "two complete rows collapse after the clear animation" {
    var game = Game.init(11);
    for (18..20) |row| {
        for (0..COLS) |col| {
            if (col != 4 and col != 5) game.board.cells[row][col] = .j;
        }
    }

    game.active = .{ .kind = .o, .rotation = 0, .x = 3, .y = 0 };
    game.hardDrop();

    try std.testing.expect(game.phase == .clearing);
    try std.testing.expectEqual(@as(u5, 2), @popCount(game.clear_rows));
    try std.testing.expectEqual(@as(u64, 336), game.score);

    game.update(Game.clear_duration + 0.01);
    try std.testing.expect(game.phase == .playing);
    try std.testing.expectEqual(@as(u32, 2), game.lines);
    try std.testing.expect(game.cell(4, 19) == null);
    try std.testing.expect(game.cell(4, 18) == null);
}

test "hold can be used once per spawned piece" {
    var game = Game.init(9);
    const first = game.active.kind;

    game.holdPiece();
    try std.testing.expectEqual(first, game.hold.?);
    try std.testing.expect(!game.can_hold);

    const after_exchange = game.active.kind;
    game.holdPiece();
    try std.testing.expectEqual(after_exchange, game.active.kind);
    try std.testing.expectEqual(first, game.hold.?);

    game.hardDrop();
    try std.testing.expect(game.can_hold);
    const before_second_hold = game.active.kind;
    game.holdPiece();
    try std.testing.expectEqual(before_second_hold, game.hold.?);
    try std.testing.expectEqual(first, game.active.kind);
}

test "a blocked spawn ends the run" {
    var game = Game.init(5);
    const next_kind = game.next_queue[0];
    const next_piece = Piece.spawn(next_kind);
    const first_cell = next_piece.cells()[0];
    game.board.cells[@intCast(first_cell.y)][@intCast(first_cell.x)] = .s;

    game.spawnNext();
    try std.testing.expect(game.phase == .game_over);

    var saw_game_over = false;
    while (game.nextEvent()) |event| {
        switch (event) {
            .game_over => saw_game_over = true,
            else => {},
        }
    }
    try std.testing.expect(saw_game_over);
}

test "clearing tenth line raises the level and emits an event" {
    var game = Game.init(17);
    for (0..COLS) |col| {
        if (col != 5) game.board.cells[19][col] = .z;
    }
    game.lines = 9;
    game.level = 1;
    game.active = .{ .kind = .i, .rotation = 1, .x = 3, .y = 0 };
    game.hardDrop();

    try std.testing.expectEqual(@as(u32, 10), game.lines);
    try std.testing.expectEqual(@as(u32, 2), game.level);

    var saw_level_up = false;
    while (game.nextEvent()) |event| {
        switch (event) {
            .level_up => |level| {
                try std.testing.expectEqual(@as(u32, 2), level);
                saw_level_up = true;
            },
            else => {},
        }
    }
    try std.testing.expect(saw_level_up);
}

test "pause freezes gravity and the active piece" {
    var game = Game.init(23);
    const original_y = game.active.y;
    game.togglePause();
    game.update(10.0);
    try std.testing.expect(game.phase == .paused);
    try std.testing.expectEqual(original_y, game.active.y);

    game.togglePause();
    try std.testing.expect(game.phase == .playing);
}
