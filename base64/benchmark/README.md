# Base64 benchmark

Compares the Rust CLI in [`../src`](../src) with the Zig CLI in [`../zig`](../zig)
on identical input. The script builds both release binaries, checks that they
agree, and then measures end-to-end `encode` and `decode` performance.

## Requirements

- Bash 5.0+ (uses `EPOCHREALTIME` for microsecond timings)
- `cargo` and `rustc`
- Zig 0.17+
- Standard Unix tools: `awk`, `cmp`, `head`, `mktemp`, `sort`, `tr`, `wc`

## Usage

```sh
# Full run: build, verify, then benchmark 30 timed runs per case
./benchmark.sh

# Short run while developing
./benchmark.sh --quick

# More samples with a 256 KiB input
./benchmark.sh --iterations 100 --warmup 10 --size 256K

# Benchmark an existing file (must be ASCII text)
./benchmark.sh --input /path/to/file.txt

# Only run the correctness checks
./benchmark.sh --verify-only

# Reuse already-built binaries
./benchmark.sh --no-build
```

### Options

| Option | Description |
| --- | --- |
| `-n`, `--iterations N` | Measured runs per case (default: 30) |
| `-w`, `--warmup N` | Warmup runs per case (default: 5) |
| `-s`, `--size SIZE` | Generated input size (default: 512K, max: 768K) |
| `-i`, `--input FILE` | Benchmark `FILE` instead of generating input |
| `--verify-only` | Run correctness checks and skip timing |
| `--no-build` | Use existing release binaries |
| `--keep` | Keep temporary files and print their location |
| `--quick` | Equivalent to `--iterations 10 --warmup 2` |
| `-h`, `--help` | Show help |

`SIZE` accepts a plain byte count or a `K`/`KiB`/`M`/`MiB` suffix.

## What it does

1. Generates deterministic input by repeating [`../zig/build.zig`](../zig/build.zig)
   and truncating it to the requested size, unless `--input` is given.
2. Builds the Rust CLI with `cargo build --release` and the Zig CLI with
   `zig build -Doptimize=ReleaseFast`.
3. Verifies known Base64 vectors (empty string, all three padding cases, and a
   longer string) against both CLIs.
4. Encodes the input with both CLIs, checks that the encodings are byte-for-byte
   identical, and decodes each encoding with both CLIs to check every
   cross-combination round-trips.
5. Warms up each case, then interleaves timed runs so that frequency/thermal
   drift affects both backends equally. Each timed run invokes the real CLI and
   writes its output to `/dev/null`.

The table reports mean, min, median, and max wall-clock time plus throughput in
source bytes per second. Timings include process startup, argument parsing, and
file I/O, so they describe the CLIs as users run them rather than the isolated
encode/decode functions.

## Notes and limitations

- **Input is ASCII-only.** The Rust decoder pushes decoded bytes as `char`,
  which treats each byte as a Latin-1 code point, so non-ASCII round-trips do
  not produce the original UTF-8 bytes. The script rejects non-ASCII input
  instead of reporting a misleading benchmark failure.
- **768K input cap.** [`../zig/src/main.zig`](../zig/src/main.zig) reads files
  with a 1 MiB limit. A 768 KiB source encodes to exactly 1 MiB, which is the
  largest input both CLIs accept for decode. Raise that limit if you need larger
  inputs.
- Timings are noisy on shared or frequency-scaling machines. Use
  `--iterations` to collect more samples and compare medians, and close other
  workloads for serious measurements.
- By default Zig's global cache is redirected to `zig/.zig-cache/global` so the
  script also works in sandboxes that cannot write to `~/.cache`. Set
  `ZIG_GLOBAL_CACHE_DIR` to override this. `CARGO_TARGET_DIR` is honoured for
  the Rust build and defaults to `../target`.

## Example

```text
Backend  Operation   Mean(ms)    Min(ms)   Median(ms)    Max(ms)        MiB/s
Rust     encode         3.580      3.313        3.557      4.190        139.7
Zig      encode         1.459      1.247        1.407      1.761        342.7
Rust     decode         2.872      2.625        2.815      3.474        174.1
Zig      decode         2.371      2.192        2.342      2.799        210.9
```

Numbers are machine-specific; run the script to measure the current binaries.
