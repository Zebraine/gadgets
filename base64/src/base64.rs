struct BitIter<'a> {
    bytes: std::slice::Iter<'a, u8>,
    current: u8,
    bit: u8,
    msb: bool,
}

impl<'a> BitIter<'a> {
    fn new(s: &'a str, msb: bool) -> BitIter<'a> {
        BitIter {
            bytes: s.as_bytes().iter(),
            current: 0,
            bit: 0,
            msb,
        }
    }
}

impl<'a> Iterator for BitIter<'a> {
    type Item = bool;

    fn next(&mut self) -> Option<Self::Item> {
        if self.bit == 0 {
            self.current = *self.bytes.next()?;
            self.bit = 8;
        }
        let bit = if self.msb {
            (self.current >> (self.bit - 1)) & 1
        } else {
            (self.current >> (8 - self.bit)) & 1
        } != 0;
        self.bit -= 1;
        Some(bit)
    }
}

fn encode_table(value: u8) -> char {
    match value {
        0..=25 => (b'A' + value) as char,
        26..=51 => (b'a' + (value - 26)) as char,
        52..=61 => (b'0' + (value - 52)) as char,
        62 => '+',
        63 => '/',
        _ => panic!("Invalid value for base64 encoding: {}", value),
    }
}

pub fn encode(input: &str) -> String {
    let mut output = String::new();
    let mut current = 0u8;
    let mut bit_count = 0;

    for bit in BitIter::new(input, true) {
        current = (current << 1) | (bit as u8);
        bit_count += 1;

        if bit_count == 6 {
            output.push(encode_table(current));
            current = 0;
            bit_count = 0;
        }
    }

    // remaining bits
    if bit_count > 0 {
        current <<= 6 - bit_count;
        output.push(encode_table(current));
    }

    // 4 padding
    if output.len() % 4 != 0 {
        let padding = 4 - (output.len() % 4);
        output.extend(std::iter::repeat('=').take(padding));
    }

    output
}

fn decode_table(c: char) -> Option<u8> {
    match c {
        'A'..='Z' => Some((c as u8 - b'A') as u8),
        'a'..='z' => Some((c as u8 - b'a' + 26) as u8),
        '0'..='9' => Some((c as u8 - b'0' + 52) as u8),
        '+' => Some(62),
        '/' => Some(63),
        _ => None,
    }
}

pub fn decode(input: &str) -> Option<String> {
    let mut output = String::new();
    let mut buffer = [0u8; 4];
    let mut buffer_count = 0;

    for c in input.as_bytes() {
        if *c == b'=' {
            buffer = buffer.map(|c| decode_table(c as char).unwrap_or(0));
            match buffer_count {
                2 => {
                    output.push((buffer[0] << 2 | buffer[1] >> 4) as char);
                }
                3 => {
                    output.push((buffer[0] << 2 | buffer[1] >> 4) as char);
                    output.push((buffer[1] << 4 | buffer[2] >> 2) as char);
                }
                _ => {
                    return None;
                }
            }
            return Some(output);
        }

        buffer[buffer_count] = *c;
        buffer_count += 1;

        if buffer_count >= 4 {
            buffer = buffer.map(|c| decode_table(c as char).unwrap_or(0));
            output.push((buffer[0] << 2 | buffer[1] >> 4) as char);
            output.push((buffer[1] << 4 | buffer[2] >> 2) as char);
            output.push((buffer[2] << 6 | buffer[3]) as char);
            buffer_count = 0;
        }
    }

    Some(output)
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
    fn test_decode() {
        let input = "SGVsbG8sIFdvcmxkIQ==";
        let decoded = decode(input).expect("Decoding failed");
        assert_eq!(decoded, "Hello, World!");
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
}
