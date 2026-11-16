//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const base64 = @import("base64.zig");
const Io = std.Io;

pub const encode = base64.encode;
pub const decode = base64.decode;

test {
    // Include the library's test blocks in `zig build test`.
    _ = base64;
}
