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
| **GF8** | `[s:1][e:4][m:3]` | 7 | ~±4.24 | Saturates outside φ³ |
| **GFTernary** | `{-1, 0, +1}` | — | ±1 | ±0.5 threshold, 100% sparse |

All formats use **round-to-nearest-even** via `quantizeValue()` dispatch.

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
├── formats/         GF16, GF8, fp16, bf16, GFTernary codecs
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
| **C/C++** | `src/c/gf16.h` + `cpp/` | C-ABI + header-only wrapper |
| **Rust** | `rust/goldenfloat-sys/` | FFI crate |
| **Python** | `python/goldenfloat/` | ctypes bridge |
| **Go** | `go/goldenfloat/` | cgo wrapper |

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
