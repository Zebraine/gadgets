#!/usr/bin/env bash
#
# Compare the Rust and Zig base64 CLIs on the same input.
#
# The script builds both implementations in release mode, verifies that they
# agree on a set of known vectors and on a generated input, then times
# encode/decode end to end. Timed runs write to /dev/null so that the numbers
# reflect process startup, file read, and the algorithm rather than disk I/O.
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

# Honour CARGO_TARGET_DIR, resolving a relative value the same way cargo does.
CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$ROOT/target}
if [[ $CARGO_TARGET_DIR != /* ]]; then
    CARGO_TARGET_DIR=$PWD/$CARGO_TARGET_DIR
fi
export CARGO_TARGET_DIR

ITERATIONS=30
WARMUP=5
SIZE=512K
SIZE_SET=0
INPUT=
NO_BUILD=0
VERIFY_ONLY=0
KEEP=0

usage() {
    cat <<'EOF'
Usage: benchmark.sh [OPTIONS]

Build and benchmark the Rust and Zig base64 CLIs on the same input.

Options:
  -n, --iterations N   Measured runs per case (default: 30)
  -w, --warmup N       Warmup runs per case (default: 5)
  -s, --size SIZE      Generated input size (default: 512K; max: 768K)
  -i, --input FILE     Benchmark FILE instead of generating input
      --verify-only    Run correctness checks, skip timing
      --no-build       Use existing release binaries
      --keep           Keep temporary files and print their location
      --quick          Shorthand for --iterations 10 --warmup 2
  -h, --help           Show this help

SIZE accepts a plain byte count or a K/KiB/M/MiB suffix. The input must be
valid UTF-8 text. The Zig CLI reads at most 1 MiB, so the generated input is
capped at 768K, the largest source size whose encoded form also fits in 1 MiB.
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

parse_size() {
    local value=$1 number unit multiplier

    if [[ ! $value =~ ^([0-9]+)([KkMm]([Ii]?[Bb])?)?$ ]]; then
        die "invalid size: $value (use e.g. 512K, 1M, or 524288)"
    fi
    number=$((10#${BASH_REMATCH[1]}))
    unit=${BASH_REMATCH[2]:-}

    case ${unit^^} in
        '')       multiplier=1 ;;
        K|KB|KIB) multiplier=1024 ;;
        M|MB|MIB) multiplier=$((1024 * 1024)) ;;
        *)        die "invalid size suffix: $value" ;;
    esac

    (( number > 0 )) || die "size must be greater than zero"
    printf '%s\n' "$((number * multiplier))"
}

while (( $# > 0 )); do
    case $1 in
        -n|--iterations)
            (( $# >= 2 )) || die "$1 requires an argument"
            ITERATIONS=$2
            shift 2
            ;;
        -w|--warmup)
            (( $# >= 2 )) || die "$1 requires an argument"
            WARMUP=$2
            shift 2
            ;;
        -s|--size)
            (( $# >= 2 )) || die "$1 requires an argument"
            SIZE=$2
            SIZE_SET=1
            shift 2
            ;;
        -i|--input)
            (( $# >= 2 )) || die "$1 requires an argument"
            INPUT=$2
            shift 2
            ;;
        --verify-only)
            VERIFY_ONLY=1
            shift
            ;;
        --no-build)
            NO_BUILD=1
            shift
            ;;
        --keep)
            KEEP=1
            shift
            ;;
        --quick)
            ITERATIONS=10
            WARMUP=2
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1 (try --help)"
            ;;
    esac
done

(( BASH_VERSINFO[0] >= 5 )) || die "bash >= 5.0 is required (EPOCHREALTIME)"
[[ $ITERATIONS =~ ^[1-9][0-9]*$ ]] || die "iterations must be a positive integer"
[[ $WARMUP =~ ^[0-9]+$ ]] || die "warmup must be a non-negative integer"
[[ -z $INPUT || $SIZE_SET -eq 0 ]] || die "use either --input or --size, not both"

need awk
need cmp
need head
need mktemp
need sort
need wc
need cat
if (( ! NO_BUILD )); then
    need cargo
    need zig
fi

mkdir -p -- "$CARGO_TARGET_DIR"
WORKDIR=$(mktemp -d "$CARGO_TARGET_DIR/base64-benchmark.XXXXXX")

cleanup() {
    if (( KEEP )); then
        printf '\nTemporary files kept in %s\n' "$WORKDIR" >&2
    else
        rm -rf -- "$WORKDIR"
    fi
}
trap cleanup EXIT

MAX_SOURCE_BYTES=$(( (1024 * 1024 / 4) * 3 )) # 786432

if [[ -n $INPUT ]]; then
    [[ -f $INPUT ]] || die "input file not found: $INPUT"
    INPUT=$(cd -- "$(dirname -- "$INPUT")" && pwd)/$(basename -- "$INPUT")
    INPUT_SIZE=$(wc -c < "$INPUT")
    printf '==> Using input %s\n' "$INPUT"
else
    INPUT_SIZE=$(parse_size "$SIZE")
    (( INPUT_SIZE <= MAX_SOURCE_BYTES )) \
        || die "size $SIZE is too large: the Zig CLI reads at most 1 MiB, so the source must be <= 768K (${MAX_SOURCE_BYTES} bytes)"

    SEED="$ROOT/zig/build.zig"
    [[ -f $SEED ]] || SEED="$ROOT/src/base64.rs"
    [[ -f $SEED ]] || die "cannot find a seed file for generated input"

    SEED_SIZE=$(wc -c < "$SEED")
    REPS=$(( (INPUT_SIZE + SEED_SIZE - 1) / SEED_SIZE ))
    INPUT="$WORKDIR/input.txt"
    for ((i = 0; i < REPS; i++)); do
        cat -- "$SEED"
    done > "$WORKDIR/input.raw"
    head -c "$INPUT_SIZE" -- "$WORKDIR/input.raw" > "$INPUT"
    rm -f -- "$WORKDIR/input.raw"
    printf '==> Generated %s bytes from %s\n' "$INPUT_SIZE" "${SEED#"$ROOT/"}"
fi

(( INPUT_SIZE > 0 )) || die "input must not be empty"

ENCODED_SIZE=$(( (INPUT_SIZE + 2) / 3 * 4 ))
(( ENCODED_SIZE <= 1024 * 1024 )) \
    || die "input is too large: its ${ENCODED_SIZE}-byte encoding exceeds the Zig CLI's 1 MiB reader limit"

if command -v iconv >/dev/null 2>&1; then
    iconv -f UTF-8 -t UTF-8 "$INPUT" >/dev/null 2>&1 \
        || die "input must be valid UTF-8 text: the Rust CLI reads files as UTF-8"
fi

if (( ! NO_BUILD )); then
    printf '==> Building Rust CLI (release)\n'
    cargo build --release --quiet --manifest-path "$ROOT/Cargo.toml"

    printf '==> Building Zig CLI (ReleaseFast)\n'
    (
        cd -- "$ROOT/zig"
        # Keep Zig's global cache inside the repo: sandboxed environments often
        # cannot write to ~/.cache, and .zig-cache/ is already gitignored.
        ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$ROOT/zig/.zig-cache/global}" \
            zig build -Doptimize=ReleaseFast
    )
else
    printf '==> Using existing release binaries (--no-build)\n'
fi

RUST_BIN="$CARGO_TARGET_DIR/release/base64"
ZIG_BIN="$ROOT/zig/zig-out/bin/base64"
[[ -x $RUST_BIN ]] || die "Rust binary not found: $RUST_BIN"
[[ -x $ZIG_BIN ]] || die "Zig binary not found: $ZIG_BIN"

printf '    Rust: %s\n' "$RUST_BIN"
printf '    Zig:  %s\n' "$ZIG_BIN"

# ---------------------------------------------------------------------------
# Correctness checks
# ---------------------------------------------------------------------------

printf '\n==> Checking known vectors\n'
VECTORS=(
    "" ""
    "f" "Zg=="
    "fo" "Zm8="
    "foo" "Zm9v"
    "Hello, World!" "SGVsbG8sIFdvcmxkIQ=="
    "Hello, 世界! Zig 🦎" "SGVsbG8sIOS4lueVjCEgWmlnIPCfpo4="
)
for ((i = 0; i < ${#VECTORS[@]}; i += 2)); do
    plain=${VECTORS[i]}
    expected=${VECTORS[i + 1]}
    printf '%s' "$expected" > "$WORKDIR/expected.b64"
    printf '%s' "$plain" > "$WORKDIR/expected.txt"

    for backend in rust zig; do
        if [[ $backend == rust ]]; then
            bin=$RUST_BIN
        else
            bin=$ZIG_BIN
        fi

        "$bin" encode -s "$plain" -o "$WORKDIR/$backend.vector.b64"
        cmp -s -- "$WORKDIR/expected.b64" "$WORKDIR/$backend.vector.b64" \
            || die "$backend encoded $(printf '%q' "$plain") incorrectly"

        "$bin" decode -f "$WORKDIR/expected.b64" -o "$WORKDIR/$backend.vector.txt"
        cmp -s -- "$WORKDIR/expected.txt" "$WORKDIR/$backend.vector.txt" \
            || die "$backend decoded $(printf '%q' "$expected") incorrectly"
    done
done
printf '    ok: %d vectors x 2 backends\n' "$(( ${#VECTORS[@]} / 2 ))"

printf '\n==> Checking input compatibility\n'
"$RUST_BIN" encode -f "$INPUT" -o "$WORKDIR/rust.b64"
"$ZIG_BIN" encode -f "$INPUT" -o "$WORKDIR/zig.b64"
cmp -s -- "$WORKDIR/rust.b64" "$WORKDIR/zig.b64" \
    || die "Rust and Zig produced different encodings"

for backend in rust zig; do
    if [[ $backend == rust ]]; then
        bin=$RUST_BIN
    else
        bin=$ZIG_BIN
    fi
    for encoded_by in rust zig; do
        "$bin" decode -f "$WORKDIR/$encoded_by.b64" -o "$WORKDIR/$backend-from-$encoded_by.txt"
        cmp -s -- "$INPUT" "$WORKDIR/$backend-from-$encoded_by.txt" \
            || die "$backend failed to decode $encoded_by output"
    done
done
printf '    ok: encodings are identical; every decode combination round-trips\n'

if (( VERIFY_ONLY )); then
    printf '\nVerification only; skipping benchmark.\n'
    exit 0
fi

# ---------------------------------------------------------------------------
# Timed runs
# ---------------------------------------------------------------------------

printf '\n==> Benchmarking (end-to-end CLI)\n'
printf '    input:   %s bytes\n' "$INPUT_SIZE"
printf '    encoded: %s bytes\n' "$ENCODED_SIZE"
printf '    runs:    %s measured, %s warmup per case\n' "$ITERATIONS" "$WARMUP"

# EPOCHREALTIME has microsecond resolution. Compute the timestamp in the
# current shell; command substitution would add fork latency to the measured
# interval at these millisecond-scale durations.
US_NOW=0
_us_now() {
    local t=$EPOCHREALTIME
    local seconds=${t%.*}
    local fraction=${t#*.}
    fraction=${fraction}000000
    US_NOW=$((10#$seconds * 1000000 + 10#${fraction:0:6}))
}

CASE_US=0
run_case() {
    local bin=$1
    local op=$2
    local file=$3
    local start

    _us_now
    start=$US_NOW
    "$bin" "$op" -f "$file" -o /dev/null
    _us_now
    CASE_US=$((US_NOW - start))
}

CASE_NAMES=(rust_encode zig_encode rust_decode zig_decode)
CASE_BACKENDS=(Rust Zig Rust Zig)
CASE_OPS=(encode encode decode decode)
CASE_BINS=("$RUST_BIN" "$ZIG_BIN" "$RUST_BIN" "$ZIG_BIN")
CASE_FILES=("$INPUT" "$INPUT" "$WORKDIR/rust.b64" "$WORKDIR/rust.b64")

declare -A SAMPLES=()
for name in "${CASE_NAMES[@]}"; do
    SAMPLES[$name]=
done

# Interleave cases so slow frequency/thermal changes affect both backends.
for ((w = 0; w < WARMUP; w++)); do
    for idx in "${!CASE_NAMES[@]}"; do
        run_case "${CASE_BINS[idx]}" "${CASE_OPS[idx]}" "${CASE_FILES[idx]}"
    done
done

for ((i = 0; i < ITERATIONS; i++)); do
    for idx in "${!CASE_NAMES[@]}"; do
        run_case "${CASE_BINS[idx]}" "${CASE_OPS[idx]}" "${CASE_FILES[idx]}"
        name=${CASE_NAMES[idx]}
        SAMPLES[$name]+="$CASE_US"$'\n'
    done
done

printf '\n%-8s %-9s %10s %10s %12s %10s %12s\n' \
    "Backend" "Operation" "Mean(ms)" "Min(ms)" "Median(ms)" "Max(ms)" "MiB/s"

declare -A MEAN_US=()
for idx in "${!CASE_NAMES[@]}"; do
    name=${CASE_NAMES[idx]}
    mapfile -t sorted < <(printf '%s' "${SAMPLES[$name]}" | sort -n)
    n=${#sorted[@]}
    (( n == ITERATIONS )) \
        || die "internal error: expected $ITERATIONS samples for $name, got $n"

    min=${sorted[0]}
    max=${sorted[0]}
    sum=0
    for us in "${sorted[@]}"; do
        sum=$((sum + us))
        if (( us < min )); then
            min=$us
        fi
        if (( us > max )); then
            max=$us
        fi
    done

    if (( n % 2 == 1 )); then
        median=${sorted[n / 2]}
    else
        median=$(( (sorted[n / 2 - 1] + sorted[n / 2]) / 2 ))
    fi

    mean=$(awk -v s="$sum" -v n="$n" 'BEGIN { printf "%.1f", s / n }')
    MEAN_US[$name]=$mean
    mean_ms=$(awk -v v="$mean" 'BEGIN { printf "%.3f", v / 1000 }')
    min_ms=$(awk -v v="$min" 'BEGIN { printf "%.3f", v / 1000 }')
    median_ms=$(awk -v v="$median" 'BEGIN { printf "%.3f", v / 1000 }')
    max_ms=$(awk -v v="$max" 'BEGIN { printf "%.3f", v / 1000 }')
    mibs=$(awk -v b="$INPUT_SIZE" -v us="$mean" \
        'BEGIN { printf "%.1f", (b * 1000000 / us) / (1024 * 1024) }')

    printf '%-8s %-9s %10s %10s %12s %10s %12s\n' \
        "${CASE_BACKENDS[idx]}" "${CASE_OPS[idx]}" \
        "$mean_ms" "$min_ms" "$median_ms" "$max_ms" "$mibs"
done

printf '\nMean speedup:\n'
for op in encode decode; do
    rust=${MEAN_US[rust_$op]}
    zig=${MEAN_US[zig_$op]}
    if awk -v r="$rust" -v z="$zig" 'BEGIN { exit !(r > z) }'; then
        factor=$(awk -v r="$rust" -v z="$zig" 'BEGIN { printf "%.2f", r / z }')
        printf '  %-7s Zig is %sx faster than Rust\n' "$op:" "$factor"
    elif awk -v r="$rust" -v z="$zig" 'BEGIN { exit !(z > r) }'; then
        factor=$(awk -v r="$rust" -v z="$zig" 'BEGIN { printf "%.2f", z / r }')
        printf '  %-7s Rust is %sx faster than Zig\n' "$op:" "$factor"
    else
        printf '  %-7s both backends have the same mean time\n' "$op:"
    fi
done

printf '\nNote: times include process startup and file I/O; throughput is source bytes per second.\n'
