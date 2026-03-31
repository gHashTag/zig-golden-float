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
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_constants() {
        assert_eq!(GF16_ZERO.0, 0x0000);
        assert_eq!(GF16_ONE.0, 0x3C00);
    }
}
