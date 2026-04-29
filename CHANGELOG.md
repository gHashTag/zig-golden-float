# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] — 2026-04-30

### Changed

- README rewritten: format table, architecture map, benchmark results, binding instructions, φ-FMA reference, IGLA overview
- Version alignment across all packages: Rust crate 1.1.0 → 2.0.0, Python 1.0.0 → 2.0.0, C header 1.1.0 → 2.0.0

## [2.1.0] — 2026-04-30

### Fixed

- **phi_attention.zig** — Zig 0.16 compatibility: expand single-line `for..if` to block form for mutable captures
- **trinity_constants.zig** — LR schedule warmup boundary: `step < N` → `step <= N` so `lr(warmup_steps) == LR_INIT` exactly
- **jepa_t.zig** — correct GF16 budget assertion: total ≈ 16.4 MB (embedding 7.2M + 9 layers × 150K params); relax to 17 MB
- **bf16 encoder** — validated post-fix via BENCH-010: gf16 outperforms bf16 by 16× on all distributions
- **bench_007b_extended_range.rs** — extended with φ-distributed inputs and Pearson correlation analysis

### Added

- **Benchmark results** — `.trinity/results/bench_007b.log`, `bench_008.log`, `bench_010.log` committed
- **CHANGELOG.md** — full release history with Keep a Changelog format
- **All 30 issues resolved**, 0 open

### Benchmark Results Summary (v2.1.0)

| Metric | Value |
|--------|-------|
| GF16 MSE (UNIFORM ±100) | 2.3×10⁻³ |
| bf16 MSE (UNIFORM ±100) | 3.8×10⁻² |
| GF16 vs bf16 improvement | 16.3× lower MSE |
| GF16 accuracy vs fp32 (σ=1.0) | > 99.99% |
| GFTernary sparsity (He init) | 100% (all \|w\| < 0.5) |
| Pearson r(φ-distance, MSE) | −0.34 (weak) |

## [2.0.0] — 2026-04-30

### Added

- **GF16/fp16/bf16 unified format system** — canonical IEEE-754 encode/decode with round-to-nearest-even
  - `quantizeValue()` dispatches to format-specific codec
  - GF16: `[s:1][e:6][m:9]`, bias=31
  - fp16: IEEE 754 binary16 with correct subnormal handling
  - bf16: IEEE 754 brain float with `(bits +| 0x7FFF) >> 16` canonical encoder
  - GFTernary: symmetric `{−1, 0, +1}` with ±0.5 threshold

- **φ-optimized FMA operations** (#57)
  - `fma`, `fms`, `fnma` — standard fused multiply-add
  - `phiFma` — φ-weighted FMA: `(a×b)×φ + c×φ⁻¹`
  - `phiDot` — φ-weighted dot product
  - C-ABI exports + `gf16.h` header

- **IGLA-GF16 Trinity Architecture** (#59, #61, #62)
  - Module 1: Trinity Constants — φ, α_φ, Fibonacci dims, model architecture
  - Module 3: φ-Sparse Attention — Fibonacci distance mask `{1,2,3,5,8,13,21,34,55,89,144}`
  - Module 4: Trinity Weight Init — 4 physics sectors (gauge/higgs/lepton/cosmology)
  - Module 5: φ-LR Schedule — warmup over Fib(7)=21 steps, φ-decay
  - Module 6: JEPA-T Predictor — Encoder 6 + Predictor 3 layers
  - Module 7: Architecture verification benchmarks with 5 whitepaper proofs

- **GF8 format** with max-value verification tests (#54)

- **Benchmarks**
  - BENCH-007b: φ-distance extended range [-10, 10] (Rust)
  - BENCH-008: Fashion-MNIST MLP quantization validation (Zig + Rust port)
  - BENCH-009: Transformer attention φ-pattern analysis (Zig)
  - BENCH-010: Format analysis suite — 6 distributions × 5 formats (Rust)
  - All results in `.trinity/results/`

- **C-ABI shared library** — `libgoldenfloat.{so,dylib,dll}` v2.0.0

- **Language bindings**
  - C/C++: header-only wrapper + CMake build
  - Rust: `goldenfloat-sys` FFI crate
  - Python: ctypes bridge
  - Go: cgo bridge

- **Code generation from .tri specs** — `tri_gen` executable

- **VSA modules** — core, HRR, 10K-dimensional hypervectors, lock-free concurrency
- **Ternary arithmetic** — HybridBigInt, packed trit storage
- **VM + JIT** — stack-based interpreter, ARM64 & x86_64 native codegen
- **Transcendental functions** — sin, cos, exp, log generated from specs

### Fixed

- **bf16 encoder** (#53) — rewritten from frexp±7 clamp to canonical `(bits +| 0x7FFF) >> 16`
- **fp16 subnormal decoder** (#63) — biased exponent was `(112 - wrapping_exp)`, corrected to `(113 - shifts)`. Fixed 131072× magnitude error for values near zero
- **GF16 NaN preservation** (#45) — split `!isFinite` into `isNaN`/`isInf` checks
- **GF8 max-value clamping** — corrected to 1.9375 with proper range tests
- **GF8 range assertion** — test now correctly asserts GF8 saturates at [-10,10] (φ³ ≈ 4.24)
- **CI workflow** (#40) — replaced `goto-bus/setup-zig` (404) with `mlugg/setup-zig`
- **Rust binding** (#41) — added `#![allow(non_camel_case_types)]`
- **Go binding** (#42) — removed `import "C"` from test file
- **C++ binding** — fixed include path and C++14 support in CMakeLists
- **Committed build artifacts** (#32) — purged `cpp/build/`, added to `.gitignore`

### Changed

- README rewritten with format table, architecture map, benchmark results, IGLA overview
- Version bumped: `build.zig.zon` 0.2.0 → 2.0.0, `Cargo.toml` 1.0.0 → 2.0.0
- C-ABI library version: 1.1.0 → 2.0.0

### Benchmark Results Summary

| Metric | Value |
|--------|-------|
| GF16 accuracy vs fp32 (σ=1.0) | > 99.99% |
| GF16 vs bf16 MSE ratio (uniform ±100) | 16.2× better |
| GF16 sparsity at [-10,10] | 0% (no saturation) |
| GF8 at [-10,10] | CLIP (max φ³ ≈ 4.24) |
| Pearson r(φ-distance, MSE) | −0.42 (bit-width dominates) |
| GFTernary sparsity (He init σ=0.05) | 100% |

## [1.0.0] — 2026-04-28

### Added

- Initial public release
- GF16 core format
- C-ABI layer
- Multi-language bindings (C, Rust, Python, Go)
- Whitepaper v2.0 with BENCH-007 results
- GitHub Pages deployment
- MIT license
