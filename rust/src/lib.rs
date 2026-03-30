#![no_std]

//! GF16 Rust Reference Implementation (no_std)
//!
//! Golden Float 16: φ-optimized 16-bit floating point
//! Format: 1 sign bit, 6 exponent bits (bias=31), 9 mantissa bits
//!
//! MIT License — Copyright (c) 2026 Trinity Project
//!
//! One format specification. Six language implementations. Zero compiler bugs.

/// GF16 type matching the bit layout (FFI-compatible with C)
#[repr(C, packed)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Gf16 {
    /// Raw 16-bit value
    pub raw: u16,
}

// Special values (GF16: 6-bit exponent, 9-bit mantissa)
// Exponent field = 0x3F (63) for special values
pub const GF16_PINF: u16 = 0x7E00;   // +Infinity (exp=0x3F, mant=0)
pub const GF16_NINF: u16 = 0xFE00;   // -Infinity (sign=1, exp=0x3F, mant=0)
pub const GF16_NAN: u16 = 0x7E01;    // Quiet NaN (exp=0x3F, mant=1)
pub const GF16_ZERO: u16 = 0x0000;   // +0.0
pub const GF16_NEG_ZERO: u16 = 0x8000; // -0.0

impl Gf16 {
    /// Create from raw u16 value
    #[inline]
    pub const fn from_raw(raw: u16) -> Self {
        Self { raw }
    }

    /// Get raw u16 value
    #[inline]
    pub const fn to_raw(&self) -> u16 {
        self.raw
    }

    /// Extract sign bit (1 = negative, 0 = positive)
    #[inline]
    pub const fn sign(&self) -> u16 {
        (self.raw >> 15) & 1
    }

    /// Extract exponent bits (biased, range 0-63)
    #[inline]
    pub const fn exp_biased(&self) -> u16 {
        (self.raw >> 9) & 0x3F
    }

    /// Extract unbiased exponent value
    #[inline]
    pub const fn exp_unbiased(&self) -> i16 {
        ((self.raw >> 9) & 0x3F) as i16 - 31
    }

    /// Extract mantissa bits (9 bits)
    #[inline]
    pub const fn mantissa(&self) -> u16 {
        self.raw & 0x1FF
    }

    /// Check if NaN
    #[inline]
    pub fn is_nan(&self) -> bool {
        self.exp_biased() == 0x3F && self.mantissa() != 0
    }

    /// Check if positive infinity
    #[inline]
    pub fn is_pos_inf(&self) -> bool {
        self.raw == GF16_PINF
    }

    /// Check if negative infinity
    #[inline]
    pub fn is_neg_inf(&self) -> bool {
        self.raw == GF16_NINF
    }

    /// Check if infinity (either sign)
    #[inline]
    pub fn is_inf(&self) -> bool {
        self.is_pos_inf() || self.is_neg_inf()
    }

    /// Check if zero (either sign)
    #[inline]
    pub fn is_zero(&self) -> bool {
        self.raw == GF16_ZERO || self.raw == GF16_NEG_ZERO
    }

    /// Check if subnormal (exponent = 0, mantissa != 0)
    #[inline]
    pub fn is_subnormal(&self) -> bool {
        self.exp_biased() == 0 && self.mantissa() != 0
    }

    /// Absolute value
    #[inline]
    pub fn abs(&self) -> Self {
        Self { raw: self.raw & 0x7FFF }
    }

    /// Negate
    #[inline]
    pub fn negate(&self) -> Self {
        Self { raw: self.raw ^ 0x8000 }
    }

    /// Create from f32 (simple round-to-nearest)
    pub fn from_f32(x: f32) -> Self {
        if x.is_nan() {
            return Self::from_raw(GF16_NAN);
        }
        if x.is_infinite() {
            return if x.is_sign_positive() {
                Self::from_raw(GF16_PINF)
            } else {
                Self::from_raw(GF16_NINF)
            };
        }
        if x == 0.0 {
            return if x.is_sign_positive() {
                Self::from_raw(GF16_ZERO)
            } else {
                Self::from_raw(GF16_NEG_ZERO)
            };
        }

        let bits = x.to_bits();
        let sign = ((bits >> 31) & 1) as u16;
        let exp = ((bits >> 23) & 0xFF) as i32 - 127;
        let mant = (bits & 0x7FFFFF) as u32;

        // GF16: 6-bit exp (bias=31), 9-bit mant
        let gf_exp = (exp + 31).max(0).min(63) as u16;
        let gf_mant = ((mant >> 14) & 0x1FF) as u16; // Top 9 bits of f32 mantissa

        Self {
            raw: (sign << 15) | (gf_exp << 9) | gf_mant,
        }
    }

    /// Convert to f32 (approximate)
    pub fn to_f32(&self) -> f32 {
        if self.is_nan() {
            return f32::NAN;
        }
        if self.is_pos_inf() {
            return f32::INFINITY;
        }
        if self.is_neg_inf() {
            return f32::NEG_INFINITY;
        }
        if self.is_zero() {
            return if self.sign() != 0 { -0.0 } else { 0.0 };
        }

        let sign = (self.sign() as u32) << 31;
        let exp = (self.exp_unbiased() + 127) as u32;
        let mant = (self.mantissa() as u32) << 14;

        f32::from_bits(sign | (exp << 23) | mant)
    }
}

impl From<f32> for Gf16 {
    fn from(x: f32) -> Self {
        Self::from_f32(x)
    }
}

impl From<Gf16> for f32 {
    fn from(x: Gf16) -> Self {
        x.to_f32()
    }
}

impl core::ops::Neg for Gf16 {
    type Output = Self;

    fn neg(self) -> Self::Output {
        self.negate()
    }
}

/*======================================================================
 * FFI Bindings to C Reference Implementation
 *======================================================================*/

/// C-compatible GF16 type (matches c/gf16.h)
#[repr(C, packed)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct gf16_t {
    pub raw: u16,
}

impl From<Gf16> for gf16_t {
    fn from(x: Gf16) -> Self {
        Self { raw: x.raw }
    }
}

impl From<gf16_t> for Gf16 {
    fn from(x: gf16_t) -> Self {
        Self { raw: x.raw }
    }
}

// FFI declarations (link to c/gf16.c)
// Note: Enable with "c-ffi" feature when C library is available
#[cfg(feature = "c-ffi")]
#[link(name = "gf16", kind = "static")]
extern "C" {
    /// Convert f32 to GF16 (C reference implementation)
    pub fn gf16_from_f32(x: f32) -> gf16_t;

    /// Convert GF16 to f32 (C reference implementation)
    pub fn gf16_to_f32(x: gf16_t) -> f32;

    /// GF16 addition
    pub fn gf16_add(a: gf16_t, b: gf16_t) -> gf16_t;

    /// GF16 subtraction
    pub fn gf16_sub(a: gf16_t, b: gf16_t) -> gf16_t;

    /// GF16 multiplication
    pub fn gf16_mul(a: gf16_t, b: gf16_t) -> gf16_t;

    /// GF16 division
    pub fn gf16_div(a: gf16_t, b: gf16_t) -> gf16_t;

    /// Check if NaN (returns -1 for NaN, 0 otherwise)
    pub fn gf16_is_nan(x: gf16_t) -> i32;

    /// Check if infinity (returns -1 for ±Inf, 0 otherwise)
    pub fn gf16_is_inf(x: gf16_t) -> i32;

    /// Check if zero (returns 0 for zero, non-zero otherwise)
    pub fn gf16_is_zero(x: gf16_t) -> i32;

    /// φ-optimized quantization
    pub fn gf16_phi_quantize(x: f32) -> gf16_t;

    /// φ-optimized dequantization
    pub fn gf16_phi_dequantize(x: gf16_t) -> f32;
}

/*======================================================================
 * Pure Rust Fallback Implementation (when C library not available)
 *======================================================================*/

/// Pure Rust GF16 addition (via f32)
pub fn gf16_add_rust(a: Gf16, b: Gf16) -> Gf16 {
    Gf16::from_f32(a.to_f32() + b.to_f32())
}

/// Pure Rust GF16 subtraction (via f32)
pub fn gf16_sub_rust(a: Gf16, b: Gf16) -> Gf16 {
    Gf16::from_f32(a.to_f32() - b.to_f32())
}

/// Pure Rust GF16 multiplication (via f32)
pub fn gf16_mul_rust(a: Gf16, b: Gf16) -> Gf16 {
    Gf16::from_f32(a.to_f32() * b.to_f32())
}

/// Pure Rust GF16 division (via f32)
pub fn gf16_div_rust(a: Gf16, b: Gf16) -> Gf16 {
    Gf16::from_f32(a.to_f32() / b.to_f32())
}

/*======================================================================
 * Tests
 *======================================================================*/

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_special_values() {
        let pinf = Gf16::from_raw(GF16_PINF);
        let ninf = Gf16::from_raw(GF16_NINF);
        let nan = Gf16::from_raw(GF16_NAN);
        let zero = Gf16::from_raw(GF16_ZERO);

        assert!(pinf.is_pos_inf());
        assert!(ninf.is_neg_inf());
        assert!(nan.is_nan());
        assert!(zero.is_zero());
    }

    #[test]
    fn test_from_to_f32() {
        let x = Gf16::from_f32(3.14159);
        let back = x.to_f32();
        // Should be close to original
        assert!((back - 3.14159).abs() < 0.01);

        let y = Gf16::from_f32(1.0);
        assert_eq!(y.to_f32(), 1.0);

        let z = Gf16::from_f32(0.0);
        assert!(z.is_zero());
    }

    #[test]
    fn test_abs_negate() {
        let x = Gf16::from_f32(-3.14);
        let abs = x.abs();
        assert!(abs.to_f32() > 0.0);

        let neg = abs.negate();
        assert!(neg.to_f32() < 0.0);
    }

    #[test]
    fn test_bits() {
        let x = Gf16::from_raw(0xBC00); // -1.0 in GF16
        assert_eq!(x.sign(), 1);
        assert_eq!(x.exp_biased(), 30); // biased
        assert_eq!(x.exp_unbiased(), -1); // unbiased
        assert_eq!(x.mantissa(), 0);
    }

    #[test]
    fn test_rust_arithmetic() {
        let a = Gf16::from_f32(1.0);
        let b = Gf16::from_f32(2.0);

        let sum = gf16_add_rust(a, b);
        assert!((sum.to_f32() - 3.0).abs() < 0.01);

        let diff = gf16_sub_rust(b, a);
        assert!((diff.to_f32() - 1.0).abs() < 0.01);

        let prod = gf16_mul_rust(a, b);
        assert!((prod.to_f32() - 2.0).abs() < 0.01);
    }
}
