const std = @import("std");

pub fn encode(input: []const u8) []u8 {
    const allocator = std.heap.smp_allocator;
    const encode_table: []const u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    const output_len = ((input.len + 2) / 3) * 4;
    const output = try allocator.alloc(u8, output_len);
    defer allocator.free(output);

    var i: usize = 0;
    var j: usize = 0;

    while (i < input.len) : ({
        i += 3;
        j += 4;
    }) {
        const a = input[i];
        const b = if (i + 1 < input.len) input[i + 1] else 0;
        const c = if (i + 2 < input.len) input[i + 2] else 0;

        output[j] = encode_table[a >> 2];
        output[j + 1] = encode_table[((a & 0x03) << 4) | (b >> 4)];
        output[j + 2] = if (i + 1 < input.len) encode_table[((b & 0x0F) << 2) | (c >> 6)] else '=';
        output[j + 3] = if (i + 2 < input.len) encode_table[c & 0x3F] else '=';
    }

    return output;
}
