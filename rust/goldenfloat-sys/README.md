# goldenfloat-sys

Rust sys crate providing raw FFI bindings to [GoldenFloat](https://github.com/gHashTag/zig-golden-float) C-ABI.

## Overview

This crate contains `extern "C"` function declarations that directly call the `libgoldenfloat` shared library. All functions are `unsafe` and provide no additional safety guarantees beyond what the C library provides.

**For safe, idiomatic Rust wrappers**, use the `gf16` crate (coming soon).

## Building

First, build the shared library from Zig:

```bash
cd /path/to/zig-golden-float
zig build shared
```

This creates:
- `zig-out/lib/libgoldenfloat.{so,dylib,dll}` — The shared library
- `zig-out/include/gf16.h` — The C header specification

Then add `goldenfloat-sys` to your `Cargo.toml`:

```toml
[dependencies]
goldenfloat-sys = "1.1.0"
```

Or for local development:

```toml
[dependencies]
goldenfloat-sys = { path = "../zig-golden-float/rust/goldenfloat-sys" }
```

## Usage

```rust
use goldenfloat_sys::*;

fn main() {
    unsafe {
        // Convert f32 to GF16
        let a = gf16_from_f32(3.14);
        let b = gf16_from_f32(2.71);

        // Arithmetic
        let sum = gf16_add(a, b);
        let prod = gf16_mul(a, b);

        // Convert back
        let result = gf16_to_f32(sum);
        println!("3.14 + 2.71 = {:.2}", result);
    }
}
```

## Running with Correct Library Path

### macOS

```bash
DYLD_LIBRARY_PATH=/path/to/zig-golden-float/zig-out/lib cargo run
```

### Linux

```bash
LD_LIBRARY_PATH=/path/to/zig-golden-float/zig-out/lib cargo run
```

### Windows

```powershell
$env:PATH += ";C:\path\to\zig-golden-float\zig-out\lib"
cargo run
```

## Type Definition

- `gf16_t` = `u16` — Raw 16-bit representation
  - Bit layout: `[sign:1][exp:6][mant:9]`
  - Exponent bias: 31

## Functions

### Conversion
- `gf16_from_f32(x: f32) -> gf16_t`
- `gf16_to_f32(g: gf16_t) -> f32`

### Arithmetic
- `gf16_add(a: gf16_t, b: gf16_t) -> gf16_t`
- `gf16_sub(a: gf16_t, b: gf16_t) -> gf16_t`
- `gf16_mul(a: gf16_t, b: gf16_t) -> gf16_t`
- `gf16_div(a: gf16_t, b: gf16_t) -> gf16_t`

### Unary
- `gf16_neg(g: gf16_t) -> gf16_t`
- `gf16_abs(g: gf16_t) -> gf16_t`

### Comparison
- `gf16_eq(a: gf16_t, b: gf16_t) -> bool`
- `gf16_lt(a: gf16_t, b: gf16_t) -> bool`
- `gf16_le(a: gf16_t, b: gf16_t) -> bool`
- `gf16_cmp(a: gf16_t, b: gf16_t) -> i32`

### Predicates
- `gf16_is_nan(g: gf16_t) -> bool`
- `gf16_is_inf(g: gf16_t) -> bool`
- `gf16_is_zero(g: gf16_t) -> bool`
- `gf16_is_subnormal(g: gf16_t) -> bool`
- `gf16_is_negative(g: gf16_t) -> bool`

### φ-Math
- `gf16_phi_quantize(x: f32) -> gf16_t`
- `gf16_phi_dequantize(g: gf16_t) -> f32`

### Utility
- `gf16_copysign(target: gf16_t, source: gf16_t) -> gf16_t`
- `gf16_min(a: gf16_t, b: gf16_t) -> gf16_t`
- `gf16_max(a: gf16_t, b: gf16_t) -> gf16_t`
- `gf16_fma(a: gf16_t, b: gf16_t, c: gf16_t) -> gf16_t`

### Library Info
- `goldenfloat_version() -> *const u8`
- `goldenfloat_phi() -> f64`
- `goldenfloat_trinity() -> f64`

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `GF16_ZERO` | 0x0000 | Zero |
| `GF16_ONE` | 0x3C00 | One (1.0) |
| `GF16_PINF` | 0x7E00 | Positive infinity |
| `GF16_NINF` | 0xFE00 | Negative infinity |
| `GF16_NAN` | 0x7E01 | Quiet NaN |
| `GF16_TRINITY` | 3.0 | φ² + 1/φ² = 3 |

## Bit Extraction

```rust
use goldenfloat_sys::*;

let bits: gf16_t = 0x4292; // Some GF16 value
let sign = GF16_SIGN(bits);   // Extract sign bit
let exp = GF16_EXP(bits);     // Extract exponent
let mant = GF16_MANT(bits);   // Extract mantissa

// Construct from parts
let reconstructed = GF16_MAKE(sign, exp, mant);
```

## Safety

All functions are `unsafe` because they:

1. Call external C code (no Rust guarantees)
2. May produce NaN/Infinity (IEEE 754 semantics)
3. Have no bounds checking (trusts caller)

## License

MIT License — See [LICENSE](../../LICENSE) file for details.
