# goldenfloat-sys

FFI bindings to [GoldenFloat](https://github.com/gHashTag/zig-golden-float) — φ-optimized 16-bit floating point format for machine learning.

## Format Specification

GF16 uses a **[sign:1][exp:6][mant:9]** bit layout:

```
┌──────┬─────────┬─────────┐
│ sign │   exp   │  mant   │
│ 1bit │   6bit  │   9bit  │
└──────┴─────────┴─────────┘
```

**Key Properties:**
- φ-distance: **0.049** (best among 16-bit formats)
- Max value: **4.30×10⁹** (65,000× wider than IEEE fp16)
- No subnormals (simplifies hardware)

## Installation

Add to `Cargo.toml`:

```toml
[dependencies]
goldenfloat-sys = "1.1"
```

## Building the Native Library

Before using this crate, build the GoldenFloat shared library:

```bash
git clone https://github.com/gHashTag/zig-golden-float
cd zig-golden-float
zig build shared
```

Then set the library path when running:

```bash
# macOS
export DYLD_LIBRARY_PATH=/path/to/zig-golden-float/zig-out/lib

# Linux
export LD_LIBRARY_PATH=/path/to/zig-golden-float/zig-out/lib
```

Or set `GOLDENFLOAT_LIB_DIR` environment variable.

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
        println!("3.14 + 2.71 = {}", result);  // 5.85
        println!("3.14 × 2.71 = {}", gf16_to_f32(prod));  // 8.51
        
        // φ-optimized quantization
        let weight = 2.71828;
        let phi_q = gf16_phi_quantize(weight);
        let phi_dq = gf16_phi_dequantize(phi_q);
        println!("φ-quantization error: {:.4}%", 
                 (phi_dq - weight).abs() / weight * 100.0);
        
        // Predicates
        assert!(gf16_is_zero(GF16_ZERO));
        assert!(gf16_is_inf(GF16_PINF));
        
        // Library info
        let version = std::ffi::CStr::from_ptr(goldenfloat_version())
            .to_str().unwrap();
        println!("GoldenFloat version: {}", version);
        println!("φ = {}", goldenfloat_phi());
        println!("φ² + 1/φ² = {}", goldenfloat_trinity());  // 3.0
    }
}
```

## Constants

```rust
use goldenfloat_sys::*;

GF16_ZERO   // 0.0
GF16_ONE    // 1.0
GF16_PINF   // +Infinity
GF16_NINF   // -Infinity
GF16_NAN    // NaN
```

## Functions

### Conversion
- `gf16_from_f32(x: f32) -> gf16_t`
- `gf16_to_f32(g: gf16_t) -> f32`

### Arithmetic
- `gf16_add(a, b) -> gf16_t`
- `gf16_sub(a, b) -> gf16_t`
- `gf16_mul(a, b) -> gf16_t`
- `gf16_div(a, b) -> gf16_t`

### Unary
- `gf16_neg(g) -> gf16_t`
- `gf16_abs(g) -> gf16_t`

### Comparison
- `gf16_eq(a, b) -> bool`
- `gf16_lt(a, b) -> bool`
- `gf16_le(a, b) -> bool`
- `gf16_cmp(a, b) -> i32`

### Predicates
- `gf16_is_nan(g) -> bool`
- `gf16_is_inf(g) -> bool`
- `gf16_is_zero(g) -> bool`
- `gf16_is_negative(g) -> bool`

### φ-Math
- `gf16_phi_quantize(x) -> gf16_t`
- `gf16_phi_dequantize(g) -> f32`

### Utility
- `gf16_copysign(target, source) -> gf16_t`
- `gf16_min(a, b) -> gf16_t`
- `gf16_max(a, b) -> gf16_t`
- `gf16_fma(a, b, c) -> gf16_t`

## Scientific Comparison

See [GF16 Whitepaper](https://github.com/gHashTag/zig-golden-float/blob/main/docs/whitepaper/gf16_comparison.md) for detailed comparison with IEEE fp16, bfloat16, and DLFloat-6:9.

| Format | φ-distance | Avg Error | Gradient Range |
|--------|-----------|-----------|----------------|
| IEEE f16 | 0.118 | 0.085% | 2.15×10⁹ |
| bfloat16 | 0.525 | 0.282% | 3.39×10³⁸ |
| **GF16** | **0.049** | **0.140%** | **4.30×10⁹** |

## License

MIT License. See [GoldenFloat LICENSE](https://github.com/gHashTag/zig-golden-float/blob/main/LICENSE).
