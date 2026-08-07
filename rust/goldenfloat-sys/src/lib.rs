//! GoldenFloat FFI Bindings for Rust
//!
//! φ-optimized 16-bit floating point format: [sign:1][exp:6][mant:9]
//!
//! ## Quick Start
//!
//! ```rust
//! use goldenfloat_sys::*;
//!
//! fn main() {
//!     let a = unsafe { gf16_from_f32(3.14) };
//!     let b = unsafe { gf16_from_f32(2.71) };
//!     let sum = unsafe { gf16_add(a, b) };
//!     let result = unsafe { gf16_to_f32(sum) };
//!     println!("3.14 + 2.71 = {}", result);
//! }
//! ```

#![no_std]
#![allow(non_snake_case)]
#![allow(non_camel_case_types)]

use core::ffi::c_char;

/// GF16 value type (transparent u16 wrapper)
#[repr(transparent)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct gf16_t(pub u16);

// ═════════════════════════════════════════════════════════════════════
// Constants
// ═════════════════════════════════════════════════════════════════════

pub const GF16_ZERO: gf16_t = gf16_t(0x0000);
pub const GF16_ONE: gf16_t = gf16_t(0x3C00);
pub const GF16_PINF: gf16_t = gf16_t(0x7E00);
pub const GF16_NINF: gf16_t = gf16_t(0xFE00);
pub const GF16_NAN: gf16_t = gf16_t(0x7E01);

// ═════════════════════════════════════════════════════════════════════
// FFI Functions
// ═════════════════════════════════════════════════════════════════════

extern "C" {
    // Conversion
    pub fn gf16_from_f32(x: f32) -> gf16_t;
    pub fn gf16_to_f32(g: gf16_t) -> f32;

    // Arithmetic
    pub fn gf16_add(a: gf16_t, b: gf16_t) -> gf16_t;
    pub fn gf16_sub(a: gf16_t, b: gf16_t) -> gf16_t;
    pub fn gf16_mul(a: gf16_t, b: gf16_t) -> gf16_t;
    pub fn gf16_div(a: gf16_t, b: gf16_t) -> gf16_t;

    // Unary
    pub fn gf16_neg(g: gf16_t) -> gf16_t;
    pub fn gf16_abs(g: gf16_t) -> gf16_t;

    // Comparison
    pub fn gf16_eq(a: gf16_t, b: gf16_t) -> bool;
    pub fn gf16_lt(a: gf16_t, b: gf16_t) -> bool;
    pub fn gf16_le(a: gf16_t, b: gf16_t) -> bool;
    pub fn gf16_cmp(a: gf16_t, b: gf16_t) -> i32;

    // Predicates
    pub fn gf16_is_nan(g: gf16_t) -> bool;
    pub fn gf16_is_inf(g: gf16_t) -> bool;
    pub fn gf16_is_zero(g: gf16_t) -> bool;
    pub fn gf16_is_negative(g: gf16_t) -> bool;

    // φ-Math
    pub fn gf16_phi_quantize(x: f32) -> gf16_t;
    pub fn gf16_phi_dequantize(g: gf16_t) -> f32;

    // Utility
    pub fn gf16_copysign(target: gf16_t, source: gf16_t) -> gf16_t;
    pub fn gf16_min(a: gf16_t, b: gf16_t) -> gf16_t;
    pub fn gf16_max(a: gf16_t, b: gf16_t) -> gf16_t;
    pub fn gf16_fma(a: gf16_t, b: gf16_t, c: gf16_t) -> gf16_t;

    // Library info
    pub fn goldenfloat_version() -> *const c_char;
    pub fn goldenfloat_phi() -> f64;
    pub fn goldenfloat_trinity() -> f64;

    // GF-T16 (ternary-exponent) — raw 17-bit value carried in a gft16_t (u32).
    pub fn gft16_from_f32(x: f32) -> gft16_t;
    pub fn gft16_to_f32(g: gft16_t) -> f32;
    pub fn gft16_add(a: gft16_t, b: gft16_t) -> gft16_t;
    pub fn gft16_sub(a: gft16_t, b: gft16_t) -> gft16_t;
    pub fn gft16_mul(a: gft16_t, b: gft16_t) -> gft16_t;
    pub fn gft16_div(a: gft16_t, b: gft16_t) -> gft16_t;
    pub fn gft16_neg(g: gft16_t) -> gft16_t;
    pub fn gft16_abs(g: gft16_t) -> gft16_t;
    pub fn gft16_is_finite(g: gft16_t) -> u8;
}

/// Raw GF-T16 value: the 17-bit ternary-exponent pattern in the low bits of a u32.
#[repr(transparent)]
#[derive(Copy, Clone, Debug, PartialEq, Eq, Default)]
#[allow(non_camel_case_types)]
pub struct gft16_t(pub u32);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_constants() {
        assert_eq!(GF16_ZERO.0, 0x0000);
        assert_eq!(GF16_ONE.0, 0x3C00);
    }

    #[test]
    fn test_gft16_ffi() {
        // Round-trip (9-bit mantissa -> < 0.5%).
        for &v in &[
            1.0f32, -1.0, 0.5, 2.0, 3.14159, -3.14159, 100.0, 0.001, 12345.0,
        ] {
            let q = unsafe { gft16_to_f32(gft16_from_f32(v)) };
            assert!(
                (q - v).abs() / (v.abs() + 1e-9) < 0.005,
                "roundtrip {v} -> {q}"
            );
        }
        // Raw payload is 17-bit.
        assert!(unsafe { gft16_from_f32(3.14159).0 } <= 0x1FFFF);
        // Arithmetic.
        let a = unsafe { gft16_from_f32(1.5) };
        let b = unsafe { gft16_from_f32(2.5) };
        assert!((unsafe { gft16_to_f32(gft16_add(a, b)) } - 4.0).abs() < 0.02);
        assert!((unsafe { gft16_to_f32(gft16_mul(a, b)) } - 3.75).abs() < 0.02);
        assert!((unsafe { gft16_to_f32(gft16_neg(a)) } + 1.5).abs() < 0.02);
        // is_finite: 1.0 finite, 1e30 overflows to Inf.
        assert_eq!(unsafe { gft16_is_finite(gft16_from_f32(1.0)) }, 1);
        assert_eq!(unsafe { gft16_is_finite(gft16_from_f32(1e30)) }, 0);
    }
}
