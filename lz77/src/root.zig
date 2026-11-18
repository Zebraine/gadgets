//! By convention, root.zig is the root source file when making a package.

pub const hashchain = @import("hashchain.zig");
pub const token_stream = @import("token_stream.zig");

pub const MIN_MATCH_LENGTH: u16 = 3;
pub const MAX_MATCH_LENGTH: u16 = 258;

test {
    _ = hashchain;
    _ = token_stream;
}
