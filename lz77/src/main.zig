//! Demo driver: reads one line from stdin and prints every stage of an LZ77
//! round trip — compressed tokens, packed bytes, decoded tokens, and the
//! restored text.

const std = @import("std");
const Io = std.Io;

const lz77 = @import("lz77");
const HashChain = lz77.hashchain.HashChain;
const Token = lz77.token_stream.Token;
const TokenStream = lz77.token_stream.TokenStream;

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

    var stream = TokenStream.init(allocator);
    var compressor = HashChain.init(allocator);

    const tokens = try stream.tokenize(line);
    const compressed = try compressor.compress(tokens);
    try printTokens(stdout, compressed, "");

    const encoded = try stream.encode(compressed, lz77.MIN_MATCH_LENGTH);
    for (encoded) |byte| {
        try stdout.print("{x}\n", .{byte});
    }

    const decoded = try stream.decode(encoded, lz77.MIN_MATCH_LENGTH);
    try printTokens(stdout, decoded, "Decoded ");

    const detokenized = try stream.detokenize(decoded);
    try stdout.print("Detokenized: {s}\n", .{detokenized});

    try stdout.flush();
}

/// Prints one line per token, with `prefix` naming the pipeline stage.
fn printTokens(writer: *Io.Writer, tokens: []const Token, prefix: []const u8) !void {
    for (tokens) |token| {
        switch (token) {
            .literal => |literal| {
                try writer.print("{s}Literal: {}\n", .{ prefix, literal });
            },
            .match => |match| {
                try writer.print("{s}Match: distance={}, length={}\n", .{ prefix, match.distance, match.length });
            },
        }
    }
}
