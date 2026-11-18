//! Bit-level reader and writer. Bits are read and written most significant
//! bit first within each byte.

const std = @import("std");

/// Width of the `u64` values handled by `readBits` and `writeBits`.
const MAX_BITS_PER_VALUE = 64;

pub const BitReader = struct {
    bytes: []const u8,
    bit_offset: usize = 0,

    pub fn init(bytes: []const u8) BitReader {
        return .{ .bytes = bytes };
    }

    /// Reads a single bit.
    pub fn readBit(self: *BitReader) !u1 {
        if (self.bit_offset >= self.bytes.len * 8) {
            return error.EndOfStream;
        }

        const byte = self.bytes[self.bit_offset / 8];
        const shift: u3 = @intCast(7 - (self.bit_offset % 8));
        const bit: u1 = @intCast((byte >> shift) & 1);
        self.bit_offset += 1;
        return bit;
    }

    /// Reads `count` bits as a big-endian value.
    pub fn readBits(self: *BitReader, count: usize) !u64 {
        if (count > MAX_BITS_PER_VALUE) {
            return error.TooManyBits;
        }

        var value: u64 = 0;
        for (0..count) |i| {
            const bit = try self.readBit();
            const shift: u6 = @intCast(count - 1 - i);
            value |= @as(u64, bit) << shift;
        }
        return value;
    }
};

pub const BitWriter = struct {
    bytes: std.ArrayList(u8) = .empty,
    bit_offset: usize = 0,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BitWriter {
        return .{ .allocator = allocator };
    }

    /// Writes a single bit.
    pub fn writeBit(self: *BitWriter, bit: u1) !void {
        if (self.bit_offset % 8 == 0) {
            try self.bytes.append(self.allocator, 0);
        }

        const byte_index = self.bit_offset / 8;
        const shift: u3 = @intCast(7 - (self.bit_offset % 8));
        self.bytes.items[byte_index] |= @as(u8, bit) << shift;
        self.bit_offset += 1;
    }

    /// Writes the low `count` bits of `value`, most significant bit first.
    pub fn writeBits(self: *BitWriter, value: u64, count: usize) !void {
        if (count > MAX_BITS_PER_VALUE) {
            return error.TooManyBits;
        }

        for (0..count) |i| {
            const shift: u6 = @intCast(count - 1 - i);
            try self.writeBit(@intCast((value >> shift) & 1));
        }
    }
};
