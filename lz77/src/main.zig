const std = @import("std");
const Io = std.Io;

const lz77 = @import("lz77");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.smp_allocator;
    const io = init.io;

    var read_buffer: [4096]u8 = undefined;
    var reader = Io.File.stdin().reader(io, &read_buffer);
    const stdin = &reader.interface;
    const line = try stdin.takeDelimiterExclusive('\n');

    var write_buffer: [4096]u8 = undefined;
    var writer = Io.File.stdout().writer(io, &write_buffer);
    const stdout = &writer.interface;

    const tokens = try lz77.token_stream.tokenize(allocator, line);
    const encoded = try lz77.hashchain.encode(allocator, tokens);

    for (encoded) |token| {
        switch (token) {
            .literal => |literal| {
                try stdout.print("Literal: {}\n", .{literal});
            },
            .match => |match| {
                try stdout.print("Match: distance={}, length={}\n", .{ match.distance, match.length });
            },
        }
    }

    try stdout.flush();
}
