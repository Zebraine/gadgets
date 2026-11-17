//! Events emitted by the rules layer and consumed by the presentation layer.

const std = @import("std");

pub const ClearInfo = struct {
    rows: u32,
    count: u8,
    points: u64,
    level: u32,
};

pub const Event = union(enum) {
    move: i32,
    rotate: bool,
    hold,
    lock,
    hard_drop: i32,
    line_clear: ClearInfo,
    level_up: u32,
    game_over,
};

pub const EventQueue = struct {
    const capacity = 64;

    items: [capacity]Event = undefined,
    len: usize = 0,

    pub fn clear(self: *EventQueue) void {
        self.len = 0;
    }

    pub fn push(self: *EventQueue, event: Event) void {
        if (self.len < capacity) {
            self.items[self.len] = event;
            self.len += 1;
        }
    }

    pub fn pop(self: *EventQueue) ?Event {
        if (self.len == 0) return null;
        const event = self.items[0];
        for (0..self.len - 1) |i| {
            self.items[i] = self.items[i + 1];
        }
        self.len -= 1;
        return event;
    }
};

test "event queue preserves order and respects capacity" {
    var queue = EventQueue{};
    queue.push(.{ .move = -1 });
    queue.push(.hold);
    try std.testing.expect(queue.len == 2);

    const first = queue.pop().?;
    try std.testing.expect(first == .move);
    const second = queue.pop().?;
    try std.testing.expect(second == .hold);
    try std.testing.expect(queue.pop() == null);
}
