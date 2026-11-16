const ENCODE_TABLE: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const INVALID: u8 = u8::MAX;

const fn build_decode_table() -> [u8; 256] {
    let mut table = [INVALID; 256];

    let mut i = 0u8;
    while i < 26 {
        table[(b'A' + i) as usize] = i;
        table[(b'a' + i) as usize] = i + 26;
        i += 1;
    }

    let mut i = 0u8;
    while i < 10 {
        table[(b'0' + i) as usize] = i + 52;
        i += 1;
    }

    table[b'+' as usize] = 62;
    table[b'/' as usize] = 63;
    table
}

const DECODE_TABLE: [u8; 256] = build_decode_table();

#[inline]
fn encode_byte(value: u8) -> u8 {
    ENCODE_TABLE[value as usize]
}

#[inline]
fn decode_byte(c: u8) -> Option<u8> {
    let value = DECODE_TABLE[c as usize];
    if value == INVALID { None } else { Some(value) }
}

#[inline]
fn is_whitespace(c: u8) -> bool {
    matches!(c, b' ' | b'\t' | b'\r' | b'\n' | 0x0b | 0x0c)
}

/// Encodes `input` as standard Base64, including `=` padding.
pub fn encode(input: &str) -> String {
    let input = input.as_bytes();
    let output_len = (input.len() + 2) / 3 * 4;
    let mut output = Vec::with_capacity(output_len);

    let mut chunks = input.chunks_exact(3);
    for chunk in &mut chunks {
        let a = chunk[0];
        let b = chunk[1];
        let c = chunk[2];

        output.push(encode_byte(a >> 2));
        output.push(encode_byte(((a & 0x03) << 4) | (b >> 4)));
        output.push(encode_byte(((b & 0x0f) << 2) | (c >> 6)));
        output.push(encode_byte(c & 0x3f));
    }

    let remainder = chunks.remainder();
    match remainder.len() {
        1 => {
            let a = remainder[0];
            output.push(encode_byte(a >> 2));
            output.push(encode_byte((a & 0x03) << 4));
            output.push(b'=');
            output.push(b'=');
        }
        2 => {
            let a = remainder[0];
            let b = remainder[1];
            output.push(encode_byte(a >> 2));
            output.push(encode_byte(((a & 0x03) << 4) | (b >> 4)));
            output.push(encode_byte((b & 0x0f) << 2));
            output.push(b'=');
        }
        _ => {}
    }

    debug_assert_eq!(output.len(), output_len);
    // Both the encode table and the padding are ASCII.
    String::from_utf8(output).expect("base64 output is ASCII")
}

/// Decodes standard Base64. ASCII whitespace is ignored, so text that was
/// written with a trailing newline (or line-wrapped) still decodes.
///
/// Returns `None` when the input is not valid Base64, or when the decoded
/// bytes are not valid UTF-8.
pub fn decode(input: &str) -> Option<String> {
    let input = input.as_bytes();

    let mut sig_len = 0usize;
    for &c in input {
        if !is_whitespace(c) {
            sig_len += 1;
        }
    }
    if sig_len % 4 != 0 {
        return None;
    }

    // Padding is determined by the last one or two significant characters.
    let mut padding = 0usize;
    let mut seen = 0usize;
    for &c in input.iter().rev() {
        if seen >= 2 {
            break;
        }
        if is_whitespace(c) {
            continue;
        }
        seen += 1;
        if c != b'=' {
            break;
        }
        padding += 1;
    }

    // Exact decoded size: drop the bytes that are only covered by `=` padding.
    let output_len = (sig_len / 4) * 3 - padding;
    let mut output = Vec::with_capacity(output_len);

    let mut quad = [0u8; 4];
    let mut q = 0usize;

    for &c in input {
        if is_whitespace(c) {
            continue;
        }

        quad[q] = c;
        q += 1;
        if q != 4 {
            continue;
        }
        q = 0;

        let a = decode_byte(quad[0])?;
        let b = decode_byte(quad[1])?;
        let c2 = if quad[2] == b'=' {
            0
        } else {
            decode_byte(quad[2])?
        };
        let d = if quad[3] == b'=' {
            0
        } else {
            decode_byte(quad[3])?
        };

        if output.len() < output_len {
            output.push((a << 2) | (b >> 4));
        }
        if output.len() < output_len {
            output.push(((b & 0x0f) << 4) | (c2 >> 2));
        }
        if output.len() < output_len {
            output.push(((c2 & 0x03) << 6) | d);
        }
    }

    debug_assert_eq!(q, 0);
    debug_assert_eq!(output.len(), output_len);
    String::from_utf8(output).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encode() {
        let input = "Hello, World!";
        let encoded = encode(input);
        assert_eq!(encoded, "SGVsbG8sIFdvcmxkIQ==");
    }

    #[test]
    fn test_encode_padding() {
        assert_eq!(encode(""), "");
        assert_eq!(encode("f"), "Zg==");
        assert_eq!(encode("fo"), "Zm8=");
        assert_eq!(encode("foo"), "Zm9v");
    }

    #[test]
    fn test_decode() {
        let input = "SGVsbG8sIFdvcmxkIQ==";
        let decoded = decode(input).expect("Decoding failed");
        assert_eq!(decoded, "Hello, World!");
    }

    #[test]
    fn test_decode_ignores_whitespace() {
        let decoded = decode("SGVs\nbG8s\r\nIFdvcmxk IQ==\n").expect("Decoding failed");
        assert_eq!(decoded, "Hello, World!");
    }

    #[test]
    fn test_decode_rejects_invalid_input() {
        assert_eq!(decode("abc"), None);
        assert_eq!(decode("SGVs!G8="), None);
        // 0xff is not valid UTF-8.
        assert_eq!(decode("/w=="), None);
    }

    #[test]
    fn test_encode_decode() {
        let input = std::iter::repeat("Hello, World!")
            .take(1000)
            .collect::<String>();
        let input = input.as_str();

        let encoded = encode(input);
        let decoded = decode(&encoded).expect("Decoding failed");
        assert_eq!(input, decoded);
    }

    #[test]
    fn test_empty_round_trip() {
        assert_eq!(encode(""), "");
        assert_eq!(decode(""), Some(String::new()));
        assert_eq!(decode(" \t\r\n"), Some(String::new()));
    }

    #[test]
    fn test_non_ascii_round_trip() {
        let input = "Hello, 世界! Zig 🦎";
        let encoded = encode(input);
        assert_eq!(decode(&encoded).as_deref(), Some(input));
    }
}
