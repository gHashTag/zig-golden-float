# GoldenFloat

[![Zig](https://img.shields.io/badge/Zig-0.15+-F7A41D?logo=zig&logoColor=white)](https://ziglang.org/)
[![CI](https://github.com/gHashTag/zig-golden-float/actions/workflows/test-bindings.yml/badge.svg)](https://github.com/gHashTag/zig-golden-float/actions/workflows/test-bindings.yml)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/gHashTag/zig-golden-float?label=release)](https://github.com/gHashTag/zig-golden-float/releases/latest)
[![Golden Ratio](https://img.shields.io/badge/%CF%86-1.618033988-gold)](https://en.wikipedia.org/wiki/Golden_ratio)

> 16-bit floating point in base-φ with multi-format support, φ-optimized FMA, ternary arithmetic, VSA hypervectors, and unified JIT — the numerical core of the [Trinity](https://github.com/gHashTag/trinity) ecosystem.

---

## Formats

| Format | Layout | Bias | Range | Notes |
|--------|--------|------|-------|-------|
| **GF16** | `[s:1][e:6][m:9]` | 31 | ~±65504 | Golden ratio base, no subnormals |
| **fp16** | IEEE 754 binary16 | 15 | ±65504 | Full subnormal support |
| **bf16** | IEEE 754 brain16 | 127 | ~±3.4e38 | Canonical `(bits +\| 0x7FFF) >> 16` encoder |
| **GF8** | `[s:1][e:3][m:4]` | 7 | ~±4.24 | 3-bit φ-exponent, 4-bit mantissa; saturates outside φ³ |
| **GFTernary** | `{-1, 0, +1}` | — | ±1 | ±0.5 threshold, 100% sparse |

All formats use **round-to-nearest-even** via `quantizeValue()` dispatch.

## The GoldenFloat Ladder (GF + GF-T)

Two ladders share one idea — a φ-structured fixed-field float with **no regime
decode** (unlike posit/tekum) — differing only in how the exponent is stored.

### GF — binary-exponent rung ladder

One normative rule sizes every binary rung (FORMAT-SPEC-001 v1.2):
`e = round((N−1)/φ²)`, `m = N−1−e`, `bias = 2^(e−1)−1`, `exp_max = 2^e−1`.

| Format | Bits | Layout `[s:e:m]` | Bias | Status |
|--------|------|------------------|------|--------|
| GF4 | 4 | `[1:1:2]` | 0 | Verified |
| **GF8** | 8 | `[1:3:4]` | 3 † | Verified — edge / sensors |
| GF12 | 12 | `[1:4:7]` | 7 | Verified — mid-range / audio |
| **GF16** | 16 | `[1:6:9]` | 31 | **Primary** — FPGA 35/35 @ 323 MHz Artix-7 |
| GF20 | 20 | `[1:7:12]` | 63 | Experimental |
| GF24 | 24 | `[1:9:14]` | 255 | Experimental |
| GF32 | 32 | `[1:12:19]` | 2047 | Spec |

The ladder continues to GF1024 (17 binary rungs total); GF16 is the sole primary
production rung. The whole rule-derived ladder is implemented in
[`src/formats/gf_binary.zig`](src/formats/gf_binary.zig) as a comptime factory —
`gf_binary.GF4/GF8/GF12/GF16/GF20/GF24/GF32`, or `gf_binary.GF(bits)` for any width:

```zig
const golden = @import("golden-float");
const x = golden.gf_binary.GF12.fromF32(3.14159); // [1:4:7], bias 7
std.debug.print("{d}\n", .{x.toF32()});
const Custom = golden.gf_binary.GF(48);           // rule-sized on demand
```

(GF8/GF16 additionally have dedicated φ-FMA implementations in `formats`.) † The
normative bias for GF8 is `2^(e−1)−1 = 3` and `gf_binary.GF8` uses it; the older
standalone `gf8.zig` codec encodes bias 7 — a known code/spec discrepancy tracked
for reconciliation.

### GF-T — balanced-ternary-exponent ladder

The exponent is a **balanced-ternary** number (digits −1/0/+1, stored as codes
0/1/2) added natively in ternary — no binary exponent, no regime decode — while the
mantissa keeps GF's uniform binary precision. Value = `(−1)^sign · (1 + M/2^m) · 2^e`
with `e = offset − EXP_OFFSET`; the top offset row `3^E − 1` is reserved (Inf/NaN).

| Format | Layout `[s : E trits : M bits]` | EXP_OFFSET | Special row `3^E−1` | Exponent range | Dynamic range |
|--------|----------------------------------|-----------|---------------------|----------------|---------------|
| GF-T4 | `[1 : 2t : 1]` | 4 | 8 | ±4 | ~2.4 decades |
| GF-T8 | `[1 : 3t : 4]` | 13 | 26 | ±13 | ~8 decades |
| GF-T16 | `[1 : 4t : 9]` | 40 | 80 | ±40 | ~24 decades |
| GF-T32 | `[1 : 6t : 25]` | 364 | 728 | ±364 | ~219 decades |

GF-T16 keeps GF16's φ-optimal 9-bit mantissa across its whole range, where
tekum16 tapers to ~4 bits at the extremes. The authoritative parameters live in
[`specs/gft.tri`](specs/gft.tri); the codec is [`src/formats/gft.zig`](src/formats/gft.zig).

### Using GF-T in code

```zig
const std = @import("std");
const golden = @import("golden-float");

pub fn main() void {
    // Pick a rung by name: GFT4 / GFT8 / GFT16 / GFT32.
    const a = golden.GFT16.fromF32(3.14159);
    const b = golden.GFT16.fromF32(2.71828);

    const prod = a.mul(b);            // add / sub / mul / div
    std.debug.print("{d}\n", .{prod.toF32()}); // ~8.539

    // Inspect / round-trip the raw storage bits (FFI, serialization).
    const raw = a.bits();             // unsigned integer (GFT16.Repr)
    const a2 = golden.GFT16.fromBits(raw);
    std.debug.assert(a2.bits() == raw);

    // Specials behave like a float: Inf saturates, NaN is contagious.
    std.debug.assert(!golden.GFT16.fromF32(1e30).isFinite()); // overflow -> Inf
    std.debug.assert(golden.GFT16.fromF32(1e-30).toF32() == 0); // underflow -> 0

    // GF-T32 reaches ~219 decades (1e30, 6.022e23, ...) at 25-bit precision.
    const avo = golden.GFT32.fromF32(6.022e23);
    std.debug.print("{d}\n", .{avo.toF32()});
}
```

Every rung is one instance of a comptime factory, so you can mint a custom rung
too: `const MyRung = golden.gft.GFT(5, 12); // 5 exp-trits, 12 mantissa bits`.
Each type exposes `fromF32` / `toF32` / `add` / `sub` / `mul` / `div` / `neg` /
`abs` / `bits` / `fromBits` / `isFinite` plus the constants `EXP_TRITS`,
`MANT_BITS`, `EXP_OFFSET`, `OFFSET_MAX`, `BITS`, `Repr`. A runnable copy lives in
[`examples/gft_usage.zig`](examples/gft_usage.zig).

## Quick Start

```bash
zig fetch --save https://github.com/gHashTag/zig-golden-float/archive/refs/tags/v2.1.0.tar.gz
```

```zig
const gf = @import("golden_float");

const x = gf.GF16.fromF32(3.14);
const y = gf.GF16.fromF32(2.71);
const z = x.add(y);
std.debug.print("{d}\n", .{z.toF32()}); // 5.85...
```

## Architecture

```
src/
├── formats/         GF16/GF8 (golden_float16), gf_binary.zig (GF ladder GF4..GF32),
│                     gft.zig (GF-T4/8/16/32), fp16, bf16, GFTernary codecs
├── math/            constants, transcendental (sin, cos, exp, log)
├── ternary/         HybridBigInt, packed trit storage
├── vsa/             core, HRR, 10K-dim hypervectors, FPGA bind
├── vm/              stack interpreter, ARM64 & x86_64 JIT
├── c_abi.zig        FFI layer → libgoldenfloat.{so,dylib,dll}
└── root.zig         public API
```

## Language Bindings

| Language | Path | Status |
|----------|------|--------|
| **Zig** | `src/` | Native |
| **C/C++** | `src/c/{gf16,gf_ladder,gft}.h` + `cpp/` | C-ABI + header-only wrappers |
| **Rust** | `rust/goldenfloat-sys/` | FFI crate |
| **Python** | `python/goldenfloat/` | ctypes bridge |
| **Go** | `go/goldenfloat/` | cgo wrapper |

### Format coverage across bindings

Every rung below is a thin FFI wrapper over the **same** `libgoldenfloat` shared
library, so all languages execute the identical Zig codec — the wrappers differ only
in surface syntax.

| Format family | Zig | C-ABI | C++ | Rust | Python | Go |
|---------------|:---:|:-----:|:---:|:----:|:------:|:--:|
| **GF16** (rich: arith, cmp, min/max, fma, φ-quant, predicates) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Binary GF ladder** GF8 / GF12 / GF20 / GF24 / GF32 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **GF-T16** (arith, neg/abs, is_finite) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **GF-T8 / GF-T32** (arith, neg/abs, is_finite) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **GF-T4** (minimal E2M1 — from/to/mul/is_finite) | ✓ | ✓ | — | — | — | — |
| **GF4** (`[1:1:2]`, degenerate — no normal values) | factory | — | — | — | — | — |

Wrapper names follow the rung: C++ `goldenfloat::Gf12` / `Gft8`, Rust `gf12_t` /
`gft8_t`, Python `goldenfloat.Gf12` / `Gft8`, Go `goldenfloat.Gf12` / `Gft8`. The
binary ladder covers `from/to_f32`, `add/sub/mul/div`, unary `neg`, `abs`, and
`is_finite`; GF16 additionally carries the rich comparison / FMA / φ-quantization API.
GF4 is intentionally unwrapped — a 1-bit exponent leaves only zero / Inf / NaN.

### Building & Testing

```bash
# Build shared library (required for bindings)
zig build shared

# Run Zig tests
zig build test

# Test all bindings
./scripts/test_bindings.sh

# Individual bindings
cd rust/goldenfloat-sys && cargo test
cd python && python -m goldenfloat.tests.test_gf16
cd cpp && cmake -S . -B build && cmake --build build && ./build/test_gf16
cd go/goldenfloat && go test -v ./...
```

## φ-Optimized FMA

```c
// Standard
gf16_fma(a, b, c);   // a×b + c
gf16_fms(a, b, c);   // a×b - c
gf16_fnma(a, b, c);  // -(a×b) + c

// φ-weighted
gf16_phi_fma(a, b, c);  // (a×b)×φ + c×φ⁻¹
gf16_phi_dot(n, a, b);  // φ-weighted dot product
```

## IGLA-GF16 Architecture

Neural network architecture built on φ-math:

| Module | Description |
|--------|-------------|
| Trinity Constants | φ, α_φ, Fibonacci dimensions |
| φ-Sparse Attention | Fibonacci distance mask `{1,2,3,5,8,13,21,34,55,89,144}` — 2.15% sparsity |
| Trinity Weight Init | 4 physics sectors: gauge / higgs / lepton / cosmology |
| φ-LR Schedule | Warmup Fib(7)=21 steps, φ-decay |
| JEPA-T Predictor | Encoder 6 + Predictor 3 layers, φ-split |

## Benchmarks

| Metric | Result |
|--------|--------|
| GF16 accuracy vs fp32 (σ=1.0) | > 99.99% |
| GF16 vs bf16 MSE ratio (uniform ±100) | 16.2× better |
| GF16 sparsity at [-10,10] | 0% (no saturation) |
| GFTernary sparsity (He init σ=0.05) | 100% |
| Pearson r(φ-distance, MSE) | −0.34 |

Full results in `.trinity/results/` and benches under `benches/`.

## C-ABI

```c
#include "gf16.h"

gf16_t a = gf16_from_f32(3.14f);
gf16_t b = gf16_from_f32(2.71f);
gf16_t c = gf16_add(a, b);
printf("%.6f\n", gf16_to_f32(c));

double phi = goldenfloat_phi();       // 1.6180339887...
double trinity = goldenfloat_trinity(); // φ² + φ⁻² = 3
```

## Ecosystem

- [zig-sacred-geometry](https://github.com/gHashTag/zig-sacred-geometry)
- [zig-physics](https://github.com/gHashTag/zig-physics)
- [zig-hdc](https://github.com/gHashTag/zig-hdc)
- [trinity-training](https://github.com/gHashTag/trinity-training)
- [trinity](https://github.com/gHashTag/trinity)

## Version

**2.1.0** — see [CHANGELOG.md](CHANGELOG.md) for release history.

## License

[MIT](LICENSE) © gHashTag
