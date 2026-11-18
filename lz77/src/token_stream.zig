const std = @import("std");

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
