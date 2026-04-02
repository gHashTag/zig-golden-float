# GoldenFloat Language Bindings Specification

## Status: Complete ✅

All 5 target languages (Python, C++, Go, Rust, Zig) now have full bindings.

## Binding Locations

| Language | Path | Type |
|----------|------|------|
| Zig | `src/` | Native |
| C | `include/gf16.h` | Canonical ABI |
| Rust | `rust/goldenfloat-sys/` | FFI wrapper |
| Python | `python/goldenfloat/` | ctypes bridge |
| C++ | `cpp/include/goldenfloat/` | Header-only |
| Go | `go/goldenfloat/` | cgo wrapper |

## C-ABI Surface (Canonical Source)

### Level 1: Core Operations
- `gf16_from_f32(x: f32) -> gf16_t`
- `gf16_to_f32(g: gf16_t) -> f32`
- `gf16_add/sub/mul/div(a, b) -> gf16_t`
- `gf16_neg/abs(g) -> gf16_t`

### Level 2: Extended Operations
- `gf16_min/max(a, b) -> gf16_t`
- `gf16_fma(a, b, c) -> gf16_t`
- `gf16_copysign(target, source) -> gf16_t`

### Level 3: Predicates
- `gf16_is_nan/inf/zero/negative(g) -> bool`

### Level 4: φ-Math
- `gf16_phi_quantize(x: f32) -> gf16_t`
- `gf16_phi_dequantize(g: gf16_t) -> f32`
- `goldenfloat_phi() -> f64`
- `goldenfloat_trinity() -> f64`

## Binding Rules

1. **No native math**: All bindings MUST call C-ABI, never reimplement algorithms
2. **Conformance required**: Every binding MUST pass `conformance/vectors.json` tests
3. **Error handling**: Follow language idioms (exceptions in C++, Result in Rust, etc.)
4. **Constants**: Expose GF16_ZERO, GF16_ONE, GF16_PINF, GF16_NINF, GF16_NAN
5. **φ-math**: Expose `phi()`, `phi_sq()`, `phi_inv_sq()`, `trinity()`

## Required API Surface

Every language binding MUST implement:
- Conversions: `from_f32`, `to_f32`
- Arithmetic: `+`, `-`, `*`, `/`, unary `-`
- Predicates: `is_nan`, `is_inf`, `is_zero`, `is_negative`
- Constants: `zero`, `one`, `p_inf`, `n_inf`, `nan`
- φ-Math: `phi_quantize`, `phi_dequantize`, `phi`, `trinity`

## Running All Tests

```bash
# Run via test script
./scripts/test_bindings.sh

# Or run individually:
zig build shared                 # Build library
cd rust/goldenfloat-sys && cargo test
cd python && python -m goldenfloat.tests.test_gf16
cd cpp && mkdir build && cmake -S . -B build && cmake --build . && ./build/test_gf16
cd go/goldenfloat && go test -v ./...
```
