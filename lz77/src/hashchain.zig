const std = @import("std");

const token_stream = @import("token_stream.zig");
const Token = token_stream.Token;
const Match = token_stream.Match;

const HASH_SIZE = 32768;
const WINDOW_SIZE = 32768;

const MIN_MATCH_LENGTH: u16 = 3;
const MAX_MATCH_LENGTH: u16 = 258;

var head: [HASH_SIZE]usize = @splat(0xffffffff);
var prev: [WINDOW_SIZE]usize = @splat(0xffffffff);

fn hash_seg(b: []const Token) !usize {
    if (b.len < MIN_MATCH_LENGTH) return 0;
    var hash: usize = 0;

    // only accept literal tokens for hashing
    for (b[0..MIN_MATCH_LENGTH]) |token| {
        if (!token.is_literal()) return error.InvalidTokenForHashing;
        hash = (hash *% 2654435761) + @as(usize, token.literal);
    }

    return hash % HASH_SIZE;
}

fn insert_string(pos: usize, input: []const Token) !void {
    const hash = try hash_seg(input[pos..]);

    prev[pos & (WINDOW_SIZE - 1)] = head[hash];
    head[hash] = pos;
}

fn find_longest_match(pos: usize, input: []const Token) !Match {
    var best_length: u16 = 0;
    var best_distance: u16 = 0;

    const hash = try hash_seg(input[pos..]);
    var match_pos = head[hash];

    while (match_pos != 0xffffffff) : (match_pos = prev[match_pos & (WINDOW_SIZE - 1)]) {
        const distance = @as(u16, @intCast(pos - @as(usize, match_pos)));
        if (distance > WINDOW_SIZE) continue;

        var length: u16 = 0;
        while (length < MAX_MATCH_LENGTH and pos + @as(usize, length) < input.len and
            input[pos + @as(usize, length)].equal(input[@as(usize, match_pos) + @as(usize, length)]))
        {
            length += 1;
        }

        if (length > best_length) {
            best_length = length;
            best_distance = distance;
        }
    }

    return Match{ .distance = best_distance, .length = best_length };
}

pub fn encode(allocator: std.mem.Allocator, input: []const Token) ![]Token {
    var output: std.ArrayList(Token) = .empty;
    const input_len = input.len;

    var pos: usize = 0;

    while (pos < input_len) : (pos += 1) {
        const token = input[pos];

        if (input_len - pos < MIN_MATCH_LENGTH) {
            try output.append(allocator, token);
            continue;
        }

        const match = try find_longest_match(pos, input);
        if (match.length >= MIN_MATCH_LENGTH) {
            try output.append(allocator, Token{ .match = match });
            pos += @as(usize, match.length) - 1;
        } else {
            try output.append(allocator, token);
        }

        try insert_string(pos, input);
    }

    return output.toOwnedSlice(allocator);
}
