# GF16 Format Specification

**Version:** 1.0.0
**Date:** March 31, 2026
**Status:** Stable
**Authors:** Trinity Project

---

## Abstract

GF16 (Golden Float 16) is a 16-bit floating-point format derived from the golden ratio φ = (1+√5)/2. It provides a 6:9 exponent-to-mantissa split that minimizes φ-distance (0.049) while maintaining sufficient precision for machine learning workloads.

This specification defines:
- Bit layout and encoding
- Special values (NaN, infinity, zero)
- Rounding and arithmetic behavior
- C ABI for FFI interop
- Test vectors for validation

**Key property:** `φ² + 1/φ² = 3` → exp:mant = 6:9

---

## 1. Bit Layout

GF16 is stored as a 16-bit unsigned integer in little-endian byte order:

```
┌─────────────────────────────────────────────────────────────┐
│ 15   14 13 12 11 10  9  8  7  6  5  4  3  2  1  0    │
├─────────────────────────────────────────────────────────────┤
│ S  EEEE EE  MMM MMMM MMMM                                  │
└─────────────────────────────────────────────────────────────┘
```

| Field | Bits | Range | Description |
|-------|------|-------|-------------|
| S | 1 | {0, 1} | Sign bit (0 = positive, 1 = negative) |
| E | 6 | {0..63} | Exponent (bias = 31) |
| M | 9 | {0..511} | Mantissa (fractional part) |

**Total:** 1 + 6 + 9 = 16 bits

### C Representation

```c
typedef struct {
    uint16_t raw;
} gf16_t;

// Bit extraction (little-endian)
#define GF16_SIGN(g)    (((g).raw >> 15) & 0x1)
#define GF16_EXP(g)     (((g).raw >> 9)  & 0x3F)
#define GF16_MANT(g)    ((g).raw         & 0x1FF)
```

### Zig Representation

```zig
pub const GF16 = packed struct(u16) {
    sign: u1,
    exp: u6,
    mant: u9,
};
```

### Rust Representation

```rust
#[repr(C, packed)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Gf16(pub u16);

impl Gf16 {
    pub const fn sign(self) -> u16 { (self.0 >> 15) & 1 }
    pub const fn exp(self) -> u16  { (self.0 >> 9)  & 0x3F }
    pub const fn mant(self) -> u16 { self.0 & 0x1FF }
}
```

---

## 2. Value Encoding

### Normal Values

For E ∈ {1..62} (not all zeros or all ones):

```
value = (-1)^S × 2^(E-31) × (1 + M/512)
```

| Component | Formula | Range |
|-----------|---------|-------|
| Sign | `(-1)^S` | ±1 |
| Exponent | `2^(E-31)` | 2^-30 to 2^31 |
| Mantissa | `1 + M/512` | 1.000 to 1.998 |

**Approximate range:** ±4.3×10^9

### Exponent Bias

Bias = 31 (half of 2^6 - 1)

| E | Value |
|---|-------|
| 0 | Subnormal (see below) |
| 1 | 2^-30 |
| 31 | 2^0 = 1 |
| 62 | 2^31 |
| 63 | Infinity/NaN (see below) |

### Zero

```
S = 0, E = 0, M = 0  →  +0.0
S = 1, E = 0, M = 0  →  -0.0
```

### Subnormals

```
E = 0, M ≠ 0  →  value = (-1)^S × 2^-30 × (M/512)
```

Smallest positive subnormal: 2^-30 × 1/512 ≈ 4.7×10^-10

### Infinity

```
E = 63, M = 0  →  ±∞ (sign determined by S)
```

### NaN (Not-a-Number)

```
E = 63, M ≠ 0  →  NaN
```

All NaN values are **quiet** (no signaling NaN). The mantissa field is available for payload.

---

## 3. φ-Distance

The φ-distance measures how close a format's exponent:mantissa ratio is to the golden ratio optimum (1/φ ≈ 0.618).

```
ratio = (mantissa_bits) / (exponent_bits + mantissa_bits)
φ_distance = |ratio - 1/φ|
```

| Format | Exp | Mant | Ratio | φ-Distance |
|--------|-----|------|-------|------------|
| TF3-9 | 3 | 5 | 0.625 | 0.007 |
| **GF16** | **6** | **9** | **0.600** | **0.018** |
| IEEE f16 | 5 | 10 | 0.667 | 0.049 |
| BF16 | 8 | 7 | 0.467 | 0.151 |
| FP8-E4M3 | 4 | 3 | 0.429 | 0.189 |

**GF16 has the smallest φ-distance of any practical 16-bit format.**

---

## 4. Rounding Rules

### Round-to-Nearest, Ties-to-Even

When converting from higher precision (f32/f64) to GF16:

1. Compute exact value in higher precision
2. Find two adjacent GF16 values (lower and upper)
3. If exact value is exactly halfway:
   - Choose the value with **even mantissa** (LSB of mantissa = 0)
4. Otherwise:
   - Choose the nearest value

### Conversion from f32

```c
gf16_t gf16_from_f32(float x) {
    if (isnan(x)) return GF16_NAN;
    if (isinf(x)) return x > 0 ? GF16_PINF : GF16_NINF;

    // Extract IEEE 754 bits
    uint32_t bits = *(uint32_t*)&x;
    int32_t  exp  = (bits >> 23) & 0xFF;
    uint32_t mant = bits & 0x7FFFFF;

    // Apply rounding
    // ... (see reference implementation)
}
```

---

## 5. C ABI

### Struct Layout

```c
typedef struct {
    uint16_t raw;  // 2 bytes, aligned to 2-byte boundary
} gf16_t;

static_assert(sizeof(gf16_t) == 2, "GF16 must be exactly 16 bits");
static_assert(alignof(gf16_t) == 2, "GF16 must be 2-byte aligned");
```

### Function Signatures

```c
// Conversion
gf16_t gf16_from_f32(float x);
float   gf16_to_f32(gf16_t g);

// Arithmetic
gf16_t gf16_add(gf16_t a, gf16_t b);
gf16_t gf16_sub(gf16_t a, gf16_t b);
gf16_t gf16_mul(gf16_t a, gf16_t b);
gf16_t gf16_div(gf16_t a, gf16_t b);

// Comparison
int gf16_eq(gf16_t a, gf16_t b);  // -1, 0, 1
int gf16_lt(gf16_t a, gf16_t b);
int gf16_le(gf16_t a, gf16_t b);

// Special values
int  gf16_is_nan(gf16_t g);
int  gf16_is_inf(gf16_t g);
int  gf16_is_zero(gf16_t g);
```

### FFI Convention

- Calling convention: platform default `cdecl`
- Argument passing: by value (in registers or on stack)
- Return value: by value (in RAX/eax or on stack)

---

## 6. Zig ABI

### Type Definition

```zig
pub const GF16 = packed struct(u16) {
    sign: u1,
    exp: u6,
    mant: u9,

    pub inline fn fromF32(x: f32) GF16 { /* ... */ }
    pub inline fn toF32(self: GF16) f32 { /* ... */ }
};
```

### Export Convention

```zig
comptime {
    @export(*GF16 = 2, extern "C" gf16_from_f32) fn fromF32(x: f32) GF16;
}
```

---

## 7. Rust ABI

### Type Definition

```rust
#[repr(C, packed)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Gf16(pub u16);

impl Gf16 {
    pub const fn from_f32(x: f32) -> Self { /* ... */ }
    pub const fn to_f32(self) -> f32 { /* ... */ }
}

// FFI bindings
#[link(name = "gf16")]
extern "C" {
    fn gf16_from_f32(x: f32) -> Gf16;
    fn gf16_to_f32(g: Gf16) -> f32;
}
```

### no_std Support

```rust
#![no_std]

// All operations are pure integer bitwise ops
// No std library required
```

---

## 8. Test Vectors

### Basic Values

| Input (f32) | GF16 (hex) | GF16 (dec) | Error (vs f32) |
|-------------|-------------|-------------|-----------------|
| 0.0 | 0x0000 | 0 | 0% |
| -0.0 | 0x8000 | 32768 | 0% |
| 1.0 | 0x3C00 | 15360 | 0% |
| -1.0 | 0xBC00 | 48128 | 0% |
| 2.0 | 0x3D00 | 15616 | 0% |
| 3.14159 | 0x3E23 | 15907 | 0.01% |
| -3.14159 | 0xBE23 | 48675 | 0.01% |
| +∞ | 0x7C00 | 31744 | - |
| -∞ | 0xFC00 | 64512 | - |
| NaN | 0x7C01 | 31745 | - |

### Subnormals

| Input (f32) | GF16 (hex) | Value |
|-------------|-------------|-------|
| 1.0e-10 | 0x0001 | ~4.7e-10 |
| 2.0e-9 | 0x0008 | ~1.9e-9 |

---

## 9. Validation

### Self-Test

Every implementation MUST pass these tests:

```c
// C
assert(gf16_to_f32(gf16_from_f32(0.0f)) == 0.0f);
assert(gf16_to_f32(gf16_from_f32(1.0f)) == 1.0f);
assert(gf16_to_f32(gf16_from_f32(-1.0f)) == -1.0f);
assert(gf16_is_nan(gf16_from_f32(NAN)));
assert(gf16_is_inf(gf16_from_f32(INFINITY)));
```

```zig
// Zig
try std.testing.expectEqual(@as(f32, 0.0), GF16.fromF32(0.0).toF32());
try std.testing.expectEqual(@as(f32, 1.0), GF16.fromF32(1.0).toF32());
try std.testing.expect(gf16.fromF32(math.inf(f32)).isInf());
```

```rust
// Rust
assert_eq!(0.0_f32, Gf16::from_f32(0.0).to_f32());
assert_eq!(1.0_f32, Gf16::from_f32(1.0).to_f32());
assert!(Gf16::from_f32(f32::NAN).is_nan());
assert!(Gf16::from_f32(f32::INFINITY).is_infinite());
```

---

## 10. Reference Implementations

- **Zig:** `src/gf16.zig` — Pure Zig, no FFI
- **C:** `c/gf16.h`, `c/gf16.c` — Pure C99, no stdlib
- **Rust:** `rust/gf16/src/lib.rs` — FFI to C + idiomatic wrapper
- **LLVM IR:** `llvm_ir/gf16.ll` — Reference LLVM IR

All implementations MUST produce **bit-identical results** for all test vectors.

---

## 11. License

This specification is licensed under MIT License. Implementations may use any OSI-approved license.

---

## Appendix A: φ-Derivation

The 6:9 split is derived from the Trinity Identity:

```
φ = (1 + √5) / 2 = 1.618033988749895...
φ² = 2.618033988749895...
φ⁻² = 0.3819660112501051...
φ² + φ⁻² = 3 (EXACT)
```

For n bits total with k exponent bits:

```
ratio = k/n
optimal_ratio = 1/φ = 0.618...
φ_distance = |ratio - 1/φ|
```

For n=16, the φ-optimal split is:

```
k_optimal = n × (1 - 1/φ) = 16 × 0.382 = 6.11
```

Rounding to integers gives **k=6** exponent bits, **9** mantissa bits.

---

## Appendix B: Comparison with Other Formats

| Metric | IEEE f16 | BF16 | FP8-E4M3 | **GF16** |
|--------|----------|------|----------|----------|
| Bits | 16 | 16 | 8 | **16** |
| Exp bits | 5 | 8 | 4 | **6** |
| Mant bits | 10 | 7 | 3 | **9** |
| Ratio | 0.5 | 1.14 | 1.33 | **0.6** |
| φ-distance | 0.082 | 0.525 | 0.715 | **0.018** |
| Max value | 65,504 | 3.4e38 | 448 | **4.3e9** |
| Min subnormal | 6.1e-5 | 1.2e-38 | 0.0039 | **4.7e-10** |
| Precision | 3.3 digits | 2.4 digits | 1.2 digits | **2.8 digits** |

---

## Appendix C: Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-03-31 | Initial release |
