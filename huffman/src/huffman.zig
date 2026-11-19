const std = @import("std");
const Order = std.math.Order;

fn ascNodes(_: void, a: Node, b: Node) Order {
    return std.math.order(a.frequency, b.frequency);
}

pub const Node = struct {
    frequency: u32,
    left: ?Node,
    right: ?Node,
    symbol: ?u8,

    pub fn init(frequency: u32, left: ?Node, right: ?Node, symbol: ?u8) Node {
        return Node{
            .frequency = frequency,
            .left = left,
            .right = right,
            .symbol = symbol,
        };
    }
};

pub const HuffmanTree = struct {
    allocator: std.mem.Allocator,
    root: ?Node,

    pub fn init(allocator: std.mem.Allocator, root: ?Node) HuffmanTree {
        return HuffmanTree{
            .allocator = allocator,
            .root = root,
        };
    }

    pub fn build(self: *HuffmanTree, symbols: []const u8) !void {
        var frequencies: [256]u32 = @splat(0);

        for (symbols) |symbol| {
            frequencies[symbol] += 1;
        }

        var pq: std.PriorityQueue(Node, void, ascNodes) = .empty;
        defer pq.deinit(self.allocator);

        for (frequencies, 0..) |frequency, symbol| {
            if (frequency > 0) {
                const node = Node.init(frequency, null, null, @as(u8, @intCast(symbol)));
                try pq.push(self.allocator, node);
            }
        }

        while (pq.items.len > 1) {
            const left = pq.pop().?;
            const right = pq.pop().?;
            const parent = Node.init(left.frequency + right.frequency, left, right, null);
            try pq.push(self.allocator, parent);
        }

        self.root = pq.pop();
    }

    
};
