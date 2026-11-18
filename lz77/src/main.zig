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
    const compressed = try lz77.hashchain.compress(allocator, tokens);

    for (compressed) |token| {
        switch (token) {
            .literal => |literal| {
                try stdout.print("Literal: {}\n", .{literal});
            },
            .match => |match| {
                try stdout.print("Match: distance={}, length={}\n", .{ match.distance, match.length });
            },
        }
    }

    const encoded = try lz77.token_stream.encode(allocator, compressed, lz77.MIN_MATCH_LENGTH);

    for (encoded) |c| {
        try stdout.print("{x}\n", .{c});
    }

    const decoded = try lz77.token_stream.decode(allocator, encoded, lz77.MIN_MATCH_LENGTH);

    for (decoded) |token| {
        switch (token) {
            .literal => |literal| {
                try stdout.print("Decoded Literal: {}\n", .{literal});
            },
            .match => |match| {
                try stdout.print("Decoded Match: distance={}, length={}\n", .{ match.distance, match.length });
            },
        }
    }

    const detokenized = try lz77.token_stream.detokenize(allocator, decoded);
    try stdout.print("Detokenized: {s}\n", .{detokenized});

    try stdout.flush();
}
