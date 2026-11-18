//! LZ77 matching over a token stream, using a hash chain of earlier positions.

const std = @import("std");

const token_stream = @import("token_stream.zig");
const Token = token_stream.Token;
const Match = token_stream.Match;

/// Finds repeated token sequences with a hash chain.
pub const HashChain = struct {
    const MIN_MATCH_LENGTH = token_stream.MIN_MATCH_LENGTH;
    const MAX_MATCH_LENGTH = token_stream.MAX_MATCH_LENGTH;

    const HASH_SIZE = 32768;
    const HASH_MULTIPLIER = 2654435761;
    const WINDOW_SIZE = 32768;
    const WINDOW_MASK = WINDOW_SIZE - 1;

    /// Marks the end of a hash chain.
    const NO_POSITION: usize = 0xffffffff;

    allocator: std.mem.Allocator,
    /// Maps a hash to the most recent position with that hash.
    head: [HASH_SIZE]usize = @splat(NO_POSITION),
    /// Links each position to the previous position with the same hash.
    prev: [WINDOW_SIZE]usize = @splat(NO_POSITION),

    pub fn init(allocator: std.mem.Allocator) HashChain {
        return .{ .allocator = allocator };
    }

    /// Replaces runs of literals with back-references.
    ///
    /// `input` is expected to contain only literal tokens, as produced by
    /// `TokenStream.tokenize`. The chain is initialized when the instance is
    /// created and is not reset between calls, so use a fresh instance for
    /// each input.
    pub fn compress(self: *HashChain, input: []const Token) ![]Token {
        var output: std.ArrayList(Token) = .empty;
        const input_len = input.len;
        var pos: usize = 0;

        while (pos < input_len) : (pos += 1) {
            if (input_len - pos < MIN_MATCH_LENGTH) {
                try output.append(self.allocator, input[pos]);
                continue;
            }

            const match = try self.findLongestMatch(pos, input);
            if (match.length >= MIN_MATCH_LENGTH) {
                try output.append(self.allocator, .{ .match = match });
                pos += @as(usize, match.length) - 1;
            } else {
                try output.append(self.allocator, input[pos]);
            }

            try self.insert(pos, input);
        }

        return output.toOwnedSlice(self.allocator);
    }

    /// Hashes the first `MIN_MATCH_LENGTH` literal tokens of `tokens`.
    ///
    /// Returns 0 when there are not enough tokens to form a match, and
    /// `error.InvalidTokenForHashing` when a match token is encountered.
    fn hashTokens(tokens: []const Token) !usize {
        if (tokens.len < MIN_MATCH_LENGTH) return 0;

        var hash: usize = 0;
        for (tokens[0..MIN_MATCH_LENGTH]) |token| {
            const literal = switch (token) {
                .literal => |literal| literal,
                .match => return error.InvalidTokenForHashing,
            };
            hash = (hash *% HASH_MULTIPLIER) +% @as(usize, literal);
        }

        return hash % HASH_SIZE;
    }

    /// Records `pos` in the chain for the tokens starting there.
    fn insert(self: *HashChain, pos: usize, input: []const Token) !void {
        const hash = try hashTokens(input[pos..]);

        self.prev[pos & WINDOW_MASK] = self.head[hash];
        self.head[hash] = pos;
    }

    /// Finds the longest match for the tokens starting at `pos`, or a match of
    /// length 0 when none is found.
    fn findLongestMatch(self: *HashChain, pos: usize, input: []const Token) !Match {
        var best = Match{ .distance = 0, .length = 0 };

        const hash = try hashTokens(input[pos..]);
        var candidate = self.head[hash];
        const max_length: u16 = @intCast(@min(@as(usize, MAX_MATCH_LENGTH), input.len - pos));

        while (candidate != NO_POSITION) : (candidate = self.prev[candidate & WINDOW_MASK]) {
            const distance = @as(u16, @intCast(pos - candidate));
            if (distance > WINDOW_SIZE) continue;

            var length: u16 = 0;
            while (length < max_length and
                std.meta.eql(input[pos + @as(usize, length)], input[candidate + @as(usize, length)]))
            {
                length += 1;
            }

            if (length > best.length) {
                best = .{ .distance = distance, .length = length };
            }
        }

        return best;
    }
};
