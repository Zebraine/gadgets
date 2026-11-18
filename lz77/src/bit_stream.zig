const std = @import("std");

pub const BitReader = struct {
    items: []const u8,
    bit_offset: usize,

    pub fn init(items: []const u8) BitReader {
        return BitReader{
            .items = items,
            .bit_offset = 0,
        };
    }

    pub fn read_bit(self: *BitReader) !u1 {
        if (self.bit_offset >= self.items.len * 8) {
            return error.EndOfStream;
        }

        const byte = self.items[self.bit_offset / 8];
        const bit = @as(u1, @intCast((byte >> @as(u3, @intCast(7 - (self.bit_offset % 8)))) & 1));
        self.bit_offset += 1;
        return bit;
    }

    pub fn read_bits(self: *BitReader, count: usize) !u64 {
        if (count > 64) {
            return error.TooManyBits;
        }

        var value: u64 = 0;
        for (0..count) |i| {
            const bit = try self.read_bit();
            value |= @as(u64, bit) << @as(u6, @intCast(count - 1 - i));
        }
        return value;
    }
};

pub const BitWriter = struct {
    items: std.ArrayList(u8),
    allocator: std.mem.Allocator,
    bit_offset: usize,

    pub fn init(allocator: std.mem.Allocator) BitWriter {
        return BitWriter{
            .items = .empty,
            .allocator = allocator,
            .bit_offset = 0,
        };
    }

    pub fn write_bit(self: *BitWriter, bit: u1) !void {
        if (self.bit_offset % 8 == 0) {
            try self.items.append(self.allocator, 0);
        }

        const byte_index = self.bit_offset / 8;
        const bit_index: u3 = @as(u3, @intCast(7 - (self.bit_offset % 8)));
        self.items.items[byte_index] |= @as(u8, bit) << bit_index;
        self.bit_offset += 1;
    }

    pub fn write_bits(self: *BitWriter, value: u64, count: usize) !void {
        if (count > 64) {
            return error.TooManyBits;
        }

        for (0..count) |i| {
            const bit = @as(u1, @intCast((value >> @as(u6, @intCast(count - 1 - i))) & 1));
            try self.write_bit(bit);
        }
    }
};
