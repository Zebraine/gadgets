const std = @import("std");
const base64 = @import("base64");

const streql = std.mem.eql;

const max_bytes = 1024 * 1024; // 1 MB

const usage_fmt = "Usage: {s} <encode|decode> [-f <file_path> | -s <string>] [-o <output_file>]\n";

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    // stdout may be a pipe or a terminal, so it must not be written positionally.
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var it = init.minimal.args.iterate();
    const program_name = it.next() orelse "base64"; // Skip the program name

    const operation = it.next() orelse {
        try stdout.print(usage_fmt, .{program_name});
        return stdout.flush();
    };

    if (streql(u8, operation, "-h") or streql(u8, operation, "--help")) {
        try stdout.print(usage_fmt, .{program_name});
        return stdout.flush();
    }

    const input_source = it.next() orelse {
        try stdout.print(usage_fmt, .{program_name});
        return stdout.flush();
    };

    const input: []const u8 = blk: {
        if (streql(u8, input_source, "-f")) {
            const file_path = it.next() orelse return error.MissingFilePath;

            const file = try std.Io.Dir.cwd().openFile(io, file_path, .{});
            defer file.close(io);

            var read_buffer: [4096]u8 = undefined;
            var reader = file.reader(io, &read_buffer);

            // Reads the whole file (not "exactly max_bytes"); oversize input is an error.
            break :blk try reader.interface.allocRemaining(allocator, .limited(max_bytes));
        } else if (streql(u8, input_source, "-s")) {
            break :blk it.next() orelse return error.MissingString;
        } else {
            return error.InvalidInputSource;
        }
    };

    const output_file_path: ?[]const u8 = blk: {
        const flag = it.next() orelse break :blk null;
        if (streql(u8, flag, "-o")) {
            break :blk it.next() orelse return error.MissingOutputPath;
        }
        break :blk null;
    };

    const output = if (streql(u8, operation, "encode"))
        try base64.encode(allocator, input)
    else if (streql(u8, operation, "decode"))
        try base64.decode(allocator, input)
    else
        return error.InvalidOperation;

    if (output_file_path) |path| {
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);

        var write_buffer: [4096]u8 = undefined;
        var file_writer = file.writerStreaming(io, &write_buffer);
        try file_writer.interface.writeAll(output);
        try file_writer.interface.flush();
    } else {
        try stdout.writeAll(output);
        try stdout.writeByte('\n');
        try stdout.flush();
    }
}
