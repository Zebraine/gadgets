# Base64 benchmark

Compares the Rust CLI in [`../src`](../src) with the Zig CLI in [`../zig`](../zig)
on identical input. The script builds both release binaries, checks that they
agree, and then measures end-to-end `encode` and `decode` performance.

## Requirements

- Bash 5.0+ (uses `EPOCHREALTIME` for microsecond timings)
- `cargo` and `rustc`
- Zig 0.17+
- Standard Unix tools: `awk`, `cmp`, `head`, `mktemp`, `sort`, `wc`
- Optional: `iconv`, used to validate `--input` files as UTF-8

## Usage

```sh
# Full run: build, verify, then benchmark 30 timed runs per case
./benchmark.sh

# Short run while developing
./benchmark.sh --quick

# More samples with a 256 KiB input
./benchmark.sh --iterations 100 --warmup 10 --size 256K

# Benchmark an existing file (must be UTF-8 text)
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
3. Verifies known Base64 vectors (empty string, all padding cases, ASCII and
   non-ASCII strings) against both CLIs.
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

- **Input is UTF-8 text.** The Rust CLI reads files with `read_to_string`, and
  its decoder returns a `String`, so both the input and decoded data must be
  valid UTF-8. Binary input is not supported by the Rust CLI; the script
  validates `--input` with `iconv` when available.
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
Rust     encode         1.470      1.302        1.407      1.845        340.2
Zig      encode         1.431      1.221        1.360      2.212        349.4
Rust     decode         2.031      1.852        1.998      2.293        246.2
Zig      decode         2.316      2.098        2.295      2.694        215.9
```

Numbers are machine-specific; run the script to measure the current binaries.
