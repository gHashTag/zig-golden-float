//! GoldenFloat Sys — Raw FFI Bindings to libgoldenfloat
//!
//! This crate provides raw `extern "C"` bindings to the GoldenFloat C-ABI.
//!
//! **This is a low-level sys crate** — functions are unsafe and expect correct usage.
//!
//! ## Building the Library
//!
//! First, build the shared library from Zig:
//!
//! ```bash
//! cd /path/to/zig-golden-float
//! zig build shared
//! ```
//!
//! This produces:
//! - `zig-out/lib/libgoldenfloat.{so,dylib,dll}` — The shared library
//! - `zig-out/include/gf16.h` — The C header (specification)
//!
//! ## Usage
//!
//! ```rust
//! use goldenfloat_sys::*;
//!
//! fn main() {
//!     unsafe {
//!         // Convert f32 to GF16
//!         let a = gf16_from_f32(3.14);
//!         let b = gf16_from_f32(2.71);
//!
//!         // Arithmetic
//!         let sum = gf16_add(a, b);
//!         let prod = gf16_mul(a, b);
//!
//!         // Convert back
//!         let result = gf16_to_f32(sum);
//!         println!("3.14 + 2.71 = {:.2}", result);
//!     }
//! }
//! ```
//!
//! ## Type Definition
//!
//! - `gf16_t` = `u16` — Raw 16-bit representation
//!   - Bit layout: `[sign:1][exp:6][mant:9]`
//!   - Exponent bias: 31
//!
//! ## Safety
//!
//! All functions are `unsafe` because they:
//! 1. Call external C code (no Rust guarantees)
//! 2. May produce NaN/Infinity (IEEE 754 semantics)
//! 3. Have no bounds checking (trusts caller)
//!
//! For safe, idiomatic Rust wrappers, use the `goldenfloat` crate (when available).

#![no_std]
#![allow(non_camel_case_types)]
#![allow(dead_code)]
#![allow(non_snake_case)]

// ═══════════════════════════════════════════════════════════════════════
// Type Definitions
// ═══════════════════════════════════════════════════════════════════════

/// GF16 value stored as raw 16-bit unsigned integer
///
/// **Bit Layout:**
/// ```text
/// [15]     Sign (0 = positive, 1 = negative)
/// [14:9]   Exponent (bias = 31, range = -31..+32)
/// [8:0]    Mantissa (9 bits, fractional part)
/// ```
///
/// **Value Formula:**
/// ```text
/// value = (-1)^sign × (0.5 + mant/512) × 2^(exp - 31)
/// ```
pub type gf16_t = u16;

// ═══════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════

/// Zero constant (positive zero)
pub const GF16_ZERO: gf16_t = 0x0000;

/// One constant (1.0 in GF16)
pub const GF16_ONE: gf16_t = 0x3C00;

/// Positive infinity
pub const GF16_PINF: gf16_t = 0x7E00;

/// Negative infinity
pub const GF16_NINF: gf16_t = 0xFE00;

/// Quiet NaN
pub const GF16_NAN: gf16_t = 0x7E01;

/// Negative zero
pub const GF16_NZERO: gf16_t = 0x8000;

/// Golden ratio φ = (1 + √5) / 2 ≈ 1.6180339887498948
pub const GF16_PHI: f64 = 1.6180339887498948482;

/// φ² = φ × φ ≈ 2.6180339887498948
pub const GF16_PHI_SQ: f64 = 2.6180339887498948482;

/// 1/φ² ≈ 0.3819660112501051
pub const GF16_PHI_INV_SQ: f64 = 0.38196601125010515;

/// Trinity Identity: φ² + 1/φ² = 3
pub const GF16_TRINITY: f64 = 3.0;

/// Exponent bias for GF16
pub const GF16_EXP_BIAS: u32 = 31;

/// Maximum exponent value (before special values)
pub const GF16_EXP_MAX: u32 = 62;

/// Number of mantissa bits
pub const GF16_MANT_BITS: u32 = 9;

// ═══════════════════════════════════════════════════════════════════════
// Bit Extraction Macros (as const functions)
// ═══════════════════════════════════════════════════════════════════════

/// Extract sign bit (0 or 1)
#[inline]
pub const fn GF16_SIGN(g: gf16_t) -> u16 {
    (g >> 15) & 0x1
}

/// Extract exponent field (0..63)
#[inline]
pub const fn GF16_EXP(g: gf16_t) -> u16 {
    (g >> 9) & 0x3F
}

/// Extract mantissa field (0..511)
#[inline]
pub const fn GF16_MANT(g: gf16_t) -> u16 {
    g & 0x1FF
}

/// Construct GF16 from components
#[inline]
pub const fn GF16_MAKE(sign: u16, exp: u16, mant: u16) -> gf16_t {
    ((sign & 1) << 15) | ((exp & 0x3F) << 9) | (mant & 0x1FF)
}

// ═══════════════════════════════════════════════════════════════════════
// Conversion Functions
// ═══════════════════════════════════════════════════════════════════════

extern "C" {
    /// Convert f32 to GF16
    ///
    /// # Safety
    ///
    /// Safe to call with any f32 value.
    #[link_name = "gf16_from_f32"]
    pub fn gf16_from_f32(x: f32) -> gf16_t;

    /// Convert GF16 to f32
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_to_f32"]
    pub fn gf16_to_f32(g: gf16_t) -> f32;
}

// ═══════════════════════════════════════════════════════════════════════
// Arithmetic Functions
// ═══════════════════════════════════════════════════════════════════════

extern "C" {
    /// Add two GF16 values
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_add"]
    pub fn gf16_add(a: gf16_t, b: gf16_t) -> gf16_t;

    /// Subtract two GF16 values
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_sub"]
    pub fn gf16_sub(a: gf16_t, b: gf16_t) -> gf16_t;

    /// Multiply two GF16 values
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_mul"]
    pub fn gf16_mul(a: gf16_t, b: gf16_t) -> gf16_t;

    /// Divide two GF16 values
    ///
    /// # Safety
    ///
    /// Division by zero returns infinity (signed).
    #[link_name = "gf16_div"]
    pub fn gf16_div(a: gf16_t, b: gf16_t) -> gf16_t;
}

// ═══════════════════════════════════════════════════════════════════════
// Unary Functions
// ═══════════════════════════════════════════════════════════════════════

extern "C" {
    /// Negate GF16 value
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_neg"]
    pub fn gf16_neg(g: gf16_t) -> gf16_t;

    /// Absolute value of GF16
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_abs"]
    pub fn gf16_abs(g: gf16_t) -> gf16_t;
}

// ═══════════════════════════════════════════════════════════════════════
// Comparison Functions
// ═══════════════════════════════════════════════════════════════════════

extern "C" {
    /// Equality test
    ///
    /// Returns `true` if equal, `false` otherwise.
    /// Note: NaN != NaN (IEEE 754 semantics).
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_eq"]
    pub fn gf16_eq(a: gf16_t, b: gf16_t) -> bool;

    /// Less-than test
    ///
    /// Returns `true` if a < b, `false` otherwise.
    /// Note: Comparisons with NaN return `false`.
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_lt"]
    pub fn gf16_lt(a: gf16_t, b: gf16_t) -> bool;

    /// Less-than-or-equal test
    ///
    /// Returns `true` if a <= b, `false` otherwise.
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_le"]
    pub fn gf16_le(a: gf16_t, b: gf16_t) -> bool;

    /// Three-way comparison
    ///
    /// Returns: -1 if a < b, 0 if a == b, 1 if a > b
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_cmp"]
    pub fn gf16_cmp(a: gf16_t, b: gf16_t) -> i32;
}

// ═══════════════════════════════════════════════════════════════════════
// Predicate Functions
// ═══════════════════════════════════════════════════════════════════════

extern "C" {
    /// Check if value is NaN
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_is_nan"]
    pub fn gf16_is_nan(g: gf16_t) -> bool;

    /// Check if value is infinity (positive or negative)
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_is_inf"]
    pub fn gf16_is_inf(g: gf16_t) -> bool;

    /// Check if value is zero (positive or negative)
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_is_zero"]
    pub fn gf16_is_zero(g: gf16_t) -> bool;

    /// Check if value is subnormal
    ///
    /// Note: GF16 has no true subnormals (exp=0 means zero).
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_is_subnormal"]
    pub fn gf16_is_subnormal(g: gf16_t) -> bool;

    /// Check if value is negative
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_is_negative"]
    pub fn gf16_is_negative(g: gf16_t) -> bool;
}

// ═══════════════════════════════════════════════════════════════════════
// φ-Math Functions
// ═══════════════════════════════════════════════════════════════════════

extern "C" {
    /// φ-optimized quantization
    ///
    /// Quantizes f32 to GF16 using φ-weighted bins.
    /// Better distribution for ML weights.
    ///
    /// Formula: x × (1/φ²) then quantize
    ///
    /// # Safety
    ///
    /// Safe to call with any f32 value.
    #[link_name = "gf16_phi_quantize"]
    pub fn gf16_phi_quantize(x: f32) -> gf16_t;

    /// φ-optimized dequantization
    ///
    /// Dequantizes GF16 to f32 using φ-weighted bins.
    ///
    /// Formula: to_f32(g) × φ²
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t value.
    #[link_name = "gf16_phi_dequantize"]
    pub fn gf16_phi_dequantize(g: gf16_t) -> f32;
}

// ═══════════════════════════════════════════════════════════════════════
// Utility Functions
// ═══════════════════════════════════════════════════════════════════════

extern "C" {
    /// Copy sign from source to target
    ///
    /// Returns target with source's sign.
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_copysign"]
    pub fn gf16_copysign(target: gf16_t, source: gf16_t) -> gf16_t;

    /// Minimum of two values
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_min"]
    pub fn gf16_min(a: gf16_t, b: gf16_t) -> gf16_t;

    /// Maximum of two values
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_max"]
    pub fn gf16_max(a: gf16_t, b: gf16_t) -> gf16_t;

    /// Fused multiply-add: a × b + c
    ///
    /// Computed in f32, then rounded to GF16.
    ///
    /// # Safety
    ///
    /// Safe to call with any gf16_t values.
    #[link_name = "gf16_fma"]
    pub fn gf16_fma(a: gf16_t, b: gf16_t, c: gf16_t) -> gf16_t;
}

// ═══════════════════════════════════════════════════════════════════════
// Library Info
// ═══════════════════════════════════════════════════════════════════════

extern "C" {
    /// Get library version string
    ///
    /// Returns "1.1.0" or similar.
    ///
    /// # Safety
    ///
    /// Safe to call. Returns a static null-terminated string.
    #[link_name = "goldenfloat_version"]
    pub fn goldenfloat_version() -> *const u8;

    /// Get golden ratio constant φ
    ///
    /// # Safety
    ///
    /// Safe to call.
    #[link_name = "goldenfloat_phi"]
    pub fn goldenfloat_phi() -> f64;

    /// Get trinity constant (φ² + 1/φ² = 3)
    ///
    /// # Safety
    ///
    /// Safe to call.
    #[link_name = "goldenfloat_trinity"]
    pub fn goldenfloat_trinity() -> f64;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_constants() {
        assert_eq!(GF16_ZERO, 0x0000);
        assert_eq!(GF16_ONE, 0x3C00);
        assert_eq!(GF16_PINF, 0x7E00);
        assert_eq!(GF16_NINF, 0xFE00);
        assert_eq!(GF16_NAN, 0x7E01);
    }

    #[test]
    fn test_bit_extraction() {
        // Test GF16_ONE = 0x3C00
        // sign=0, exp=0x1E (30), mant=0
        assert_eq!(GF16_SIGN(GF16_ONE), 0);
        assert_eq!(GF16_EXP(GF16_ONE), 30);
        assert_eq!(GF16_MANT(GF16_ONE), 0);

        // Test negative zero = 0x8000
        assert_eq!(GF16_SIGN(GF16_NZERO), 1);
        assert_eq!(GF16_EXP(GF16_NZERO), 0);
        assert_eq!(GF16_MANT(GF16_NZERO), 0);
    }

    #[test]
    fn test_make() {
        // sign=0, exp=30, mant=0 => GF16_ONE
        assert_eq!(GF16_MAKE(0, 30, 0), GF16_ONE);

        // sign=1, exp=0, mant=0 => negative zero
        assert_eq!(GF16_MAKE(1, 0, 0), GF16_NZERO);
    }
}
