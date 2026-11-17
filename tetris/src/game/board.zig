//! The playfield grid: collision checks, locking, line detection and collapse.

const std = @import("std");
const piece = @import("piece.zig");

pub const COLS: usize = 10;
pub const ROWS: usize = 20;

pub const Board = struct {
    cells: [ROWS][COLS]?piece.PieceKind,

    pub fn init() Board {
        var board: Board = undefined;
        board.clear();
        return board;
    }

    pub fn clear(self: *Board) void {
        for (0..ROWS) |row| {
            for (0..COLS) |col| {
                self.cells[row][col] = null;
            }
        }
    }

    pub fn cell(self: *const Board, x: usize, y: usize) ?piece.PieceKind {
        return self.cells[y][x];
    }

    pub fn fits(self: *const Board, candidate: piece.Piece) bool {
        for (candidate.cells()) |pos| {
            if (pos.x < 0 or pos.x >= @as(i32, @intCast(COLS))) return false;
            if (pos.y < 0 or pos.y >= @as(i32, @intCast(ROWS))) return false;
            if (self.cells[@intCast(pos.y)][@intCast(pos.x)] != null) return false;
        }
        return true;
    }

    pub fn lock(self: *Board, locked_piece: piece.Piece) void {
        for (locked_piece.cells()) |pos| {
            if (pos.x < 0 or pos.x >= @as(i32, @intCast(COLS))) continue;
            if (pos.y < 0 or pos.y >= @as(i32, @intCast(ROWS))) continue;
            self.cells[@intCast(pos.y)][@intCast(pos.x)] = locked_piece.kind;
        }
    }

    /// Bitset of full rows. Bit N corresponds to row N.
    pub fn fullRows(self: *const Board) u32 {
        var mask: u32 = 0;
        for (0..ROWS) |row| {
            var full = true;
            for (0..COLS) |col| {
                if (self.cells[row][col] == null) {
                    full = false;
                    break;
                }
            }
            if (full) {
                mask |= @as(u32, 1) << @as(u5, @intCast(row));
            }
        }
        return mask;
    }

    pub fn removeRows(self: *Board, mask: u32) void {
        var dst: usize = ROWS;
        var src: usize = ROWS;

        while (src > 0) {
            src -= 1;
            if ((mask & (@as(u32, 1) << @as(u5, @intCast(src)))) != 0) {
                continue;
            }

            dst -= 1;
            if (dst != src) {
                self.cells[dst] = self.cells[src];
            }
        }

        while (dst > 0) {
            dst -= 1;
            for (0..COLS) |col| {
                self.cells[dst][col] = null;
            }
        }
    }
};

test "locking a piece and clearing rows works on the board" {
    var board = Board.init();
    for (0..COLS) |col| {
        if (col != 4 and col != 5) board.cells[19][col] = .j;
    }

    const o_piece = piece.Piece{ .kind = .o, .rotation = 0, .x = 3, .y = 18 };
    board.lock(o_piece);

    const rows = board.fullRows();
    try std.testing.expectEqual(@as(u5, 1), @popCount(rows));
    board.removeRows(rows);
    try std.testing.expectEqual(@as(u32, 0), board.fullRows());
    try std.testing.expectEqual(piece.PieceKind.o, board.cells[19][4].?);
}
