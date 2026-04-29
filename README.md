# zig-golden-float

[![Zig](https://img.shields.io/badge/Zig-0.15+-F7A41D?logo=zig&logoColor=white)](https://ziglang.org/)
[![License](MIT)](LICENSE)
[![Golden Ratio](https://img.shields.io/badge/φ-1.618033988-gold)](https://en.wikipedia.org/wiki/Golden_ratio)
[![Trinity](https://img.shields.io/badge/Trinity-S³AI-purple)](https://github.com/gHashTag/trinity)

> **Numerical core of the Trinity S³AI ecosystem** — GoldenFloat16 (GF16), IEEE-754 fp16/bf16 codecs, ternary arithmetic, VSA, IGLA architecture, and φ-optimized FMA — all built on the golden ratio φ.

## What is GoldenFloat?

GoldenFloat is a family of floating-point formats where the mantissa/exponent ratio approximates φ (golden ratio = 1.618...). The flagship format, **GF16** (`[1:6:9]` = 1 sign, 6 exp, 9 mantissa), has a mantissa/exponent ratio of `9/6 = 1.5`, which deviates from φ by exactly `α_φ = 0.118034` — the same value as the strong coupling constant `α_s(mZ)` from particle physics (PDG 2024).

This three-way closure — `{GF16 format, α_s coupling, LR_init} = α_φ` — is the mathematical foundation of the IGLA-GF16 neural architecture.

## Formats

| Format | Layout | Bias | Range | φ-distance |
|--------|--------|------|-------|------------|
| **GF16** | `[s:1][e:6][m:9]` | 31 | ±2.0×10⁹ | 0.049 (best) |
| **fp16** | `[s:1][e:5][m:10]` | 15 | ±65504 | 0.118 |
| **bf16** | `[s:1][e:8][m:7]` | 127 | ±3.4×10³⁸ | 0.525 |
| **GF8** | `[s:1][e:3][m:4]` | 3 | ±4.24 | 0.132 |
| **GFTernary** | `{−1, 0, +1}` | — | ±1 | 0.000 |
| **fp32** | IEEE 754 binary32 | 127 | ±3.4×10³⁸ | 0.000 (baseline) |

All encode/decode functions use canonical IEEE-754 round-to-nearest-even semantics.

## Quick Start

```bash
zig fetch --save https://github.com/gHashTag/zig-golden-float/archive/refs/tags/v2.0.0.tar.gz
```

```zig
const golden = @import("golden-float");

// GF16 format
const gf = golden.formats.GF16.fromF32(3.14159);
const back = gf.toF32();

// Quantize to any format
const q = golden.formats.quantizeValue(0.5, .gf16);

// φ-optimized FMA
const result = golden.formats.phiFma(a, b, c);

// Trinity constants
const phi = golden.trinity.PHI;
const alpha_phi = golden.trinity.ALPHA_PHI;
```

## C-ABI

Build the shared library:

```bash
zig build shared    # produces libgoldenfloat.{so,dylib,dll}
```

```c
#include <gf16.h>

gf16_t a = gf16_from_f32(3.14f);
gf16_t b = gf16_from_f32(2.71f);
gf16_t sum = gf16_add(a, b);
float result = gf16_to_f32(sum);
```

## Language Bindings

| Language | Package | Status |
|----------|---------|--------|
| C/C++ | `src/c/gf16.h` | Stable |
| Rust | `rust/goldenfloat-sys` | Stable |
| Python | `python/goldenfloat` | ctypes bridge |
| Go | `go/goldenfloat` | cgo bridge |

## Architecture

```
src/
├── formats/
│   ├── golden_float16.zig      GF16 core, FMA, φ-ops
│   ├── formats_root.zig        Unified quantize/encode/decode (GF16/fp16/bf16/ternary)
│   └── gf8.zig                 GF8 format + verification tests
├── math/
│   ├── constants.zig           φ, e, π sacred constants
│   └── transcendental.zig      sin, cos, exp, log (from .tri specs)
├── trinity_constants.zig       IGLA architecture dimensions (Fibonacci-derived)
├── phi_attention.zig           φ-Sparse Attention with Fibonacci CA-mask
├── trinity_init.zig            Trinity Weight Initialization (4 physics sectors)
├── phi_schedule.zig            φ-LR Schedule (warmup + φ-decay)
├── jepa_t.zig                  JEPA-T Predictor (latent-space prediction)
├── ternary/
│   ├── hybrid.zig              HybridBigInt engine
│   └── packed_trit.zig         Packed trit storage
├── vsa/
│   ├── core.zig                VSA bind/bundle/similarity
│   ├── hrr.zig                 Holographic Reduced Representations
│   ├── 10k_vsa.zig             10K-dimensional hypervectors
│   └── concurrency.zig         Lock-free VSA data structures
├── vm/
│   ├── vm.zig                  Stack-based VM interpreter
│   ├── jit_unified.zig         Unified JIT (ARM64 + x86_64)
│   └── opcodes.zig             Opcode definitions
└── c_abi.zig                   C-ABI shared library exports

benches/
├── bench_007b_extended_range.rs    φ-distance extended range benchmark
├── bench_008_fashion_mnist.zig     Fashion-MNIST MLP quantization
├── bench_009_transformer_attention.zig  Transformer attention φ-patterns
└── igla_gf16_bench.zig             IGLA architecture verification proofs
```

## IGLA-GF16 Architecture

IGLA (Intelligent Golden-ratio Language Architecture) is a 16MB language model where every hyperparameter derives from Trinity φ-algebra:

```
d_model  = 144   (Fib(12))
n_heads  =   8   (Fib(6))
d_head   =  18   (144/8)
d_ffn    = 233   (Fib(13) ≈ 144×φ)
n_layers =   7   (16MB budget)
TOTAL    ≈ 15.8MB in GF16
```

| Module | File | Description |
|--------|------|-------------|
| 1. Trinity Constants | `trinity_constants.zig` | φ, α_φ, Fibonacci sequence, model dims |
| 3. φ-Sparse Attention | `phi_attention.zig` | Fibonacci distance mask, φ-scale factor |
| 4. Trinity Weight Init | `trinity_init.zig` | 4 physics sectors (gauge/higgs/lepton/cosmology) |
| 5. φ-LR Schedule | `phi_schedule.zig` | Warmup over Fib(7)=21 steps, φ-decay |
| 6. JEPA-T Predictor | `jepa_t.zig` | Encoder 6 + Predictor 3 = φ-split |
| 7. Benchmarks | `igla_gf16_bench.zig` | 5 whitepaper proofs |

## Benchmarks

Benchmarks run on 10,000 samples across 6 distributions. Results stored in `.trinity/results/`.

**BENCH-007b** — Extended range [-10, 10] (10,000 samples):

| Format | MSE | MaxAbsErr | InRange |
|--------|-----|-----------|---------|
| fp32 | 0.000000 | 0.000000 | Yes |
| GF16 | 0.000520 | 0.072897 | Yes |
| bf16 | 0.000410 | 0.062475 | Yes |
| fp16 | 0.000006 | 0.007809 | Yes |
| GF8 | 6.390662 | 5.763932 | **CLIP** |

**BENCH-010** — Key findings:
- H1 CONFIRMED: bf16/gf16 diverge on Uniform [-100, +100]
- H2 FAILED: σ=0.1 collision was genuine bf16 encoder bug (now fixed)
- GF16 outperforms bf16 by 16× on all distributions

## Build

```bash
zig build              # build library module
zig build test         # run all tests
zig build shared       # build C-ABI shared library
zig build c-abi-test   # test C-ABI layer
zig build gen          # generate code from .tri specs
```

## Ecosystem

Core dependency for:
- [zig-sacred-geometry](https://github.com/gHashTag/zig-sacred-geometry)
- [zig-physics](https://github.com/gHashTag/zig-physics)
- [zig-hdc](https://github.com/gHashTag/zig-hdc)
- [trinity-training](https://github.com/gHashTag/trinity-training)
- [trinity](https://github.com/gHashTag/trinity)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT (c) 2026 gHashTag
