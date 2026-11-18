//! A small LZ77 implementation.
//!
//! `token_stream` defines literals, matches, and their bit-packed form;
//! `hashchain` groups repeated literals into matches; `bit_stream` provides
//! the bit-level I/O used by the token format.

pub const hashchain = @import("hashchain.zig");
pub const token_stream = @import("token_stream.zig");

/// The shortest match the encoder emits.
pub const MIN_MATCH_LENGTH: u16 = token_stream.MIN_MATCH_LENGTH;

/// The longest match the encoder emits.
pub const MAX_MATCH_LENGTH: u16 = token_stream.MAX_MATCH_LENGTH;

test {
    _ = hashchain;
    _ = token_stream;
}
