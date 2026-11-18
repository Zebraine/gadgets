//! LZ77 tokens and their conversion to and from the bit-packed token stream.

const std = @import("std");
const bit_stream = @import("bit_stream.zig");
const BitReader = bit_stream.BitReader;
const BitWriter = bit_stream.BitWriter;

/// The shortest match the encoder emits; shorter runs stay literals.
pub const MIN_MATCH_LENGTH: u16 = 3;

/// The longest match representable by the encoded 8-bit length field.
pub const MAX_MATCH_LENGTH: u16 = 258;

/// A back-reference to earlier tokens.
pub const Match = struct {
    /// Distance from the current position back to the start of the match.
    distance: u16,
    /// Number of tokens covered by the match.
    length: u16,
};

/// A single LZ77 symbol: either a literal byte or a back-reference.
pub const Token = union(enum) {
    const LITERAL_TAG: u1 = 0;
    const MATCH_TAG: u1 = 1;
    const LITERAL_BITS = 8;
    const DISTANCE_BITS = 16;
    const LENGTH_BITS = 8;

    literal: u8,
    match: Match,

    /// Appends this token to `writer`:
    ///
    ///     literal: [0][8-bit byte]
    ///     match:   [1][16-bit distance][8-bit length - length_offset]
    pub fn intoBits(self: Token, writer: *BitWriter, length_offset: u16) !void {
        switch (self) {
            .literal => |literal| {
                try writer.writeBit(LITERAL_TAG);
                try writer.writeBits(literal, LITERAL_BITS);
            },
            .match => |match| {
                try writer.writeBit(MATCH_TAG);
                try writer.writeBits(match.distance, DISTANCE_BITS);
                try writer.writeBits(match.length - length_offset, LENGTH_BITS);
            },
        }
    }

    /// Reads a token written by `intoBits`.
    pub fn fromBits(reader: *BitReader, length_offset: u16) !Token {
        return switch (try reader.readBit()) {
            LITERAL_TAG => .{ .literal = @intCast(try reader.readBits(LITERAL_BITS)) },
            MATCH_TAG => .{ .match = .{
                .distance = @intCast(try reader.readBits(DISTANCE_BITS)),
                .length = @as(u16, @intCast(try reader.readBits(LENGTH_BITS))) + length_offset,
            } },
        };
    }
};

/// Converts between input bytes and the token representation.
pub const TokenStream = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TokenStream {
        return .{ .allocator = allocator };
    }

    /// Splits `input` into one literal token per byte.
    pub fn tokenize(self: TokenStream, input: []const u8) ![]Token {
        const tokens = try self.allocator.alloc(Token, input.len);

        for (input, 0..) |byte, i| {
            tokens[i] = .{ .literal = byte };
        }

        return tokens;
    }

    /// Rebuilds the original bytes from `tokens`.
    ///
    /// A match may overlap the bytes it produces, so the copy advances byte by
    /// byte instead of copying a slice in one step.
    pub fn detokenize(self: TokenStream, tokens: []const Token) ![]u8 {
        var output: std.ArrayList(u8) = .empty;

        for (tokens) |token| {
            switch (token) {
                .literal => |literal| {
                    try output.append(self.allocator, literal);
                },
                .match => |match| {
                    var pos = output.items.len - @as(usize, match.distance);
                    var remaining = @as(usize, match.length);
                    while (remaining > 0) : (remaining -= 1) {
                        const byte = output.items[pos];
                        try output.append(self.allocator, byte);
                        pos += 1;
                    }
                },
            }
        }

        return output.toOwnedSlice(self.allocator);
    }

    /// Packs `tokens` into bytes using the format documented on `Token.intoBits`.
    pub fn encode(self: TokenStream, tokens: []const Token, length_offset: u16) ![]u8 {
        var bit_writer = BitWriter.init(self.allocator);

        for (tokens) |token| {
            try token.intoBits(&bit_writer, length_offset);
        }

        return bit_writer.bytes.toOwnedSlice(self.allocator);
    }

    /// Decodes a byte stream written by `encode`, stopping at the end of the input.
    pub fn decode(self: TokenStream, input: []const u8, length_offset: u16) ![]Token {
        var bit_reader = BitReader.init(input);
        var tokens: std.ArrayList(Token) = .empty;

        while (true) {
            const token = Token.fromBits(&bit_reader, length_offset) catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };
            try tokens.append(self.allocator, token);
        }

        return tokens.toOwnedSlice(self.allocator);
    }
};
