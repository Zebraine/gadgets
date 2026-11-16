const std = @import("std");

const encode_table: []const u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

inline fn encode_u8(x: u8) u8 {
    return encode_table[x];
}

/// Encodes `input` as standard Base64. The returned slice is owned by the
/// caller and must be freed with the same allocator.
pub fn encode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const output_len = ((input.len + 2) / 3) * 4;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);

    var i: usize = 0;
    var j: usize = 0;

    while (i < input.len) : ({
        i += 3;
        j += 4;
    }) {
        const a = input[i];
        const b = if (i + 1 < input.len) input[i + 1] else 0;
        const c = if (i + 2 < input.len) input[i + 2] else 0;

        output[j] = encode_u8(a >> 2);
        output[j + 1] = encode_u8(((a & 0x03) << 4) | (b >> 4));
        output[j + 2] = if (i + 1 < input.len) encode_u8(((b & 0x0F) << 2) | (c >> 6)) else '=';
        output[j + 3] = if (i + 2 < input.len) encode_u8(c & 0x3F) else '=';
    }

    return output;
}

inline fn decode_u8(c: u8) !u8 {
    return switch (c) {
        'A'...'Z' => c - 'A',
        'a'...'z' => c - 'a' + 26,
        '0'...'9' => c - '0' + 52,
        '+' => 62,
        '/' => 63,
        else => error.InvalidCharacter,
    };
}

inline fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ', '\t', '\r', '\n', 11, 12 => true,
        else => false,
    };
}

/// Decodes standard Base64 `input`. ASCII whitespace is ignored, so text that
/// was written with a trailing newline (or line-wrapped) still decodes.
/// The returned slice is owned by the caller and must be freed with the same
/// allocator.
pub fn decode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var sig_len: usize = 0;
    for (input) |c| {
        if (!isWhitespace(c)) sig_len += 1;
    }
    if (sig_len % 4 != 0) return error.InvalidLength;

    // Padding is determined by the last one or two significant characters.
    var padding: usize = 0;
    var seen: usize = 0;
    var idx: usize = input.len;
    while (idx > 0 and seen < 2) {
        idx -= 1;
        const c = input[idx];
        if (isWhitespace(c)) continue;
        seen += 1;
        if (c != '=') break;
        padding += 1;
    }

    // Exact decoded size: drop the bytes that are only covered by '=' padding.
    const output_len = (sig_len / 4) * 3 - padding;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);

    var quad: [4]u8 = undefined;
    var q: usize = 0;
    var j: usize = 0;

    for (input) |c| {
        if (isWhitespace(c)) continue;
        quad[q] = c;
        q += 1;
        if (q != 4) continue;
        q = 0;

        const a = try decode_u8(quad[0]);
        const b = try decode_u8(quad[1]);
        const c2 = if (quad[2] == '=') 0 else try decode_u8(quad[2]);
        const d = if (quad[3] == '=') 0 else try decode_u8(quad[3]);

        if (j < output_len) {
            output[j] = (a << 2) | (b >> 4);
            j += 1;
        }
        if (j < output_len) {
            output[j] = ((b & 0x0F) << 4) | (c2 >> 2);
            j += 1;
        }
        if (j < output_len) {
            output[j] = ((c2 & 0x03) << 6) | d;
            j += 1;
        }
    }

    std.debug.assert(q == 0);
    std.debug.assert(j == output_len);
    return output;
}

test "base64 encode" {
    const encoded = try encode(std.testing.allocator, "Hello, World!");
    defer std.testing.allocator.free(encoded);

    try std.testing.expectEqualStrings("SGVsbG8sIFdvcmxkIQ==", encoded);
}

test "base64 decode" {
    const decoded = try decode(std.testing.allocator, "SGVsbG8sIFdvcmxkIQ==");
    defer std.testing.allocator.free(decoded);

    try std.testing.expectEqualStrings("Hello, World!", decoded);
}

test "base64 encode and decode" {
    const input = "Zig is awesome!";
    const encoded = try encode(std.testing.allocator, input);
    defer std.testing.allocator.free(encoded);

    const decoded = try decode(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);

    try std.testing.expectEqualStrings(input, decoded);
}

test "base64 decode ignores whitespace" {
    const decoded = try decode(std.testing.allocator, "SGVs\nbG8s\r\nIFdvcmxk IQ==\n");
    defer std.testing.allocator.free(decoded);

    try std.testing.expectEqualStrings("Hello, World!", decoded);
}

test "base64 empty round trip" {
    const encoded = try encode(std.testing.allocator, "");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualStrings("", encoded);

    const decoded = try decode(std.testing.allocator, "");
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings("", decoded);
}

test "base64 decode rejects bad length" {
    try std.testing.expectError(error.InvalidLength, decode(std.testing.allocator, "abc"));
    try std.testing.expectError(error.InvalidCharacter, decode(std.testing.allocator, "SGVs!G8="));
}
