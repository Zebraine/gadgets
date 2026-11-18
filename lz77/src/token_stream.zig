const std = @import("std");
const bit_stream = @import("bit_stream.zig");
const BitWriter = bit_stream.BitWriter;
const BitReader = bit_stream.BitReader;

pub const Token = union(enum) {
    literal: u8,
    match: Match,

    pub fn is_literal(self: Token) bool {
        return switch (self) {
            .literal => true,
            .match => false,
        };
    }

    pub fn is_match(self: Token) bool {
        return switch (self) {
            .literal => false,
            .match => true,
        };
    }

    pub fn equal(self: Token, other: Token) bool {
        return switch (self) {
            .literal => |literal| switch (other) {
                .literal => |other_literal| literal == other_literal,
                .match => false,
            },
            .match => |match| switch (other) {
                .literal => false,
                .match => |other_match| match.distance == other_match.distance and match.length == other_match.length,
            },
        };
    }

    pub fn into_bits(self: Token, writer: *BitWriter, length_offset: u16) !void {
        switch (self) {
            .literal => |literal| {
                try writer.write_bit(0);
                try writer.write_bits(@as(u64, literal), 8);
            },
            .match => |match| {
                try writer.write_bit(1);
                try writer.write_bits(@as(u64, match.distance), 16);
                try writer.write_bits(@as(u64, match.length - length_offset), 8);
            },
        }
    }

    pub fn from_bits(reader: *BitReader, length_offset: u16) !Token {
        const match_bit = try reader.read_bit();
        if (match_bit == 1) {
            const distance = @as(u16, @intCast(try reader.read_bits(16)));
            const length = @as(u16, @intCast(try reader.read_bits(8))) + length_offset;
            return Token{ .match = Match{ .distance = distance, .length = length } };
        } else {
            const literal = @as(u8, @intCast(try reader.read_bits(8)));
            return Token{ .literal = literal };
        }
    }
};

pub const Match = struct {
    distance: u16,
    length: u16,
};

pub fn tokenize(allocator: std.mem.Allocator, input: []const u8) ![]Token {
    var tokens: []Token = try allocator.alloc(Token, input.len);
    var i: usize = 0;

    while (i < input.len) : (i += 1) {
        const token = Token{ .literal = input[i] };
        tokens[i] = token;
    }

    return tokens;
}

pub fn detokenize(allocator: std.mem.Allocator, tokens: []Token) ![]u8 {
    var output: std.ArrayList(u8) = .empty;

    for (tokens) |token| {
        switch (token) {
            .literal => |literal| {
                try output.append(allocator, literal);
            },
            .match => |match| {
                var pos = output.items.len - @as(usize, match.distance);
                var length = @as(usize, match.length);
                while (length > 0) : (length -= 1) {
                    const byte = output.items[pos];
                    try output.append(allocator, byte);
                    pos += 1;
                }
            },
        }
    }

    return output.toOwnedSlice(allocator);
}

pub fn encode(allocator: std.mem.Allocator, tokens: []Token, length_offset: u16) ![]u8 {
    var bit_writer = BitWriter.init(allocator);

    for (tokens) |token| {
        try token.into_bits(&bit_writer, length_offset);
    }

    return bit_writer.items.toOwnedSlice(allocator);
}

pub fn decode(allocator: std.mem.Allocator, input: []const u8, length_offset: u16) ![]Token {
    var bit_reader = BitReader.init(input);

    var tokens: std.ArrayList(Token) = .empty;

    while (true) {
        const token = Token.from_bits(&bit_reader, length_offset) catch break;
        try tokens.append(allocator, token);
    }

    return tokens.toOwnedSlice(allocator);
}
