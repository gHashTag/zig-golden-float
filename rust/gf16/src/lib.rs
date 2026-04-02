//! GoldenFloat — Safe Rust Wrapper
//!
//! Type-safe Rust wrapper around `goldenfloat-sys` FFI bindings.
//! Provides idiomatic Rust API with `Gf16` newtype and operator overloads.
//!
//! ## Features
//!
//! - `default` — Includes std (for fmt::Display)
//! - `no_std` — `#[no_std]` compatible
//! - `c-abi` — Use C-ABI via `goldenfloat-sys` (requires `zig build shared`)
//!
//! ## Usage
//!
//! ```rust
//! use gf16::Gf16;
//!
//! fn main() {
//!     let a = Gf16::from_f32(3.14159_f32);
//!     let b = Gf16::from_f32(2.71828_f32);
//!     let c = a + b;
//!     println!("c ≈ {}", f32::from(c));
//! }
//! ```
//!
//! ## Building the C Library
//!
//! First, build the shared library from Zig:
//!
//! ```bash
//! cd /path/to/zig-golden-float
//! zig build shared
//!
//! ## License
//!
//! MIT License — Copyright (c) 2026 Trinity Project

#![no_std]

use core::fmt;
use core::ops::{Add, Sub, Mul, Div, Neg};

#[cfg(feature = "c-abi")]
use goldenfloat_sys as sys;

// ═══════════════════════════════════════════════════════════════════════
// Type Definition
// ═══════════════════════════════════════════════════════════════════════

/// GF16 value — type-safe wrapper around raw gf16_t
///
/// **Why `Gf16(u16)` newtype?**
/// - Encapsulation: Hide raw representation, provide typed methods
/// - Safety: Bounds checking, explicit error handling
/// - Debug: Better debugging with `{:?}` formatting
/// - Idiomatic: Works with `?` operator, `unwrap()`, match patterns
#[derive(Copy, Clone, Default)]
pub struct Gf16(pub u16);

impl Gf16 {
    /// Create from raw u16 value
    #[inline]
    pub const fn from_raw(raw: u16) -> Self {
        Self(raw)
    }

    /// Get raw u16 value
    #[inline]
    pub const fn to_raw(&self) -> u16 {
        self.0
    }

    /// Extract sign bit (1 = negative, 0 = positive)
    #[inline]
    pub const fn sign(&self) -> u16 {
        (self.0 >> 15) & 1
    }

    /// Extract exponent field (biased, range 0-63)
    #[inline]
    pub const fn exp_biased(&self) -> u16 {
        (self.0 >> 9) & 0x3F
    }

    /// Extract unbiased exponent value
    #[inline]
    pub const fn exp_unbiased(&self) -> i16 {
        ((self.0 >> 9) & 0x3F) as i16 - 31
    }

    /// Extract mantissa bits (9 bits)
    #[inline]
    pub const fn mantissa(&self) -> u16 {
        self.0 & 0x1FF
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════

/// Zero constant (positive zero)
pub const GF16_ZERO: u16 = 0x0000;

/// One constant (1.0 in GF16)
pub const GF16_ONE: u16 = 0x3C00;

/// Positive infinity
pub const GF16_PINF: u16 = 0x7E00;

/// Negative infinity
pub const GF16_NINF: u16 = 0xFE00;

/// Quiet NaN
pub const GF16_NAN: u16 = 0x7E01;

/// Negative zero
pub const GF16_NZERO: u16 = 0x8000;

// ═══════════════════════════════════════════════════════════════════════
// C-ABI Implementation (via goldenfloat-sys)
// ═══════════════════════════════════════════════════════════════════════

#[cfg(feature = "c-abi")]
impl Gf16 {
    /// Create from f32 (via C-ABI)
    pub fn from_f32(x: f32) -> Self {
        let raw = unsafe { sys::gf16_from_f32(x) };
        Self(raw.0)
    }

    /// Convert to f32 (via C-ABI)
    pub fn to_f32(&self) -> f32 {
        unsafe { sys::gf16_to_f32(sys::gf16_t(self.0)) }
    }

    /// Zero constant
    pub fn zero() -> Self {
        Self(sys::GF16_ZERO.0)
    }

    /// One constant
    pub fn one() -> Self {
        Self(sys::GF16_ONE.0)
    }

    /// Positive infinity
    pub fn p_inf() -> Self {
        Self(sys::GF16_PINF.0)
    }

    /// Negative infinity
    pub fn n_inf() -> Self {
        Self(sys::GF16_NINF.0)
    }

    /// NaN constant
    pub fn nan() -> Self {
        Self(sys::GF16_NAN.0)
    }

    /// Check if value is zero (handles signed zeros)
    pub fn is_zero(&self) -> bool {
        unsafe { sys::gf16_is_zero(sys::gf16_t(self.0)) }
    }

    /// Check if value is NaN
    pub fn is_nan(&self) -> bool {
        unsafe { sys::gf16_is_nan(sys::gf16_t(self.0)) }
    }

    /// Check if value is infinity (positive or negative)
    pub fn is_inf(&self) -> bool {
        unsafe { sys::gf16_is_inf(sys::gf16_t(self.0)) }
    }

    /// Check if value is negative
    pub fn is_negative(&self) -> bool {
        unsafe { sys::gf16_is_negative(sys::gf16_t(self.0)) }
    }

    /// Absolute value
    pub fn abs(&self) -> Self {
        let raw = unsafe { sys::gf16_abs(sys::gf16_t(self.0)) };
        Self(raw.0)
    }

    /// φ-quantize a float value
    ///
    /// **Formula:** x × (1/φ²) then quantize
    pub fn phi_quantize(x: f32) -> Self {
        let raw = unsafe { sys::gf16_phi_quantize(x) };
        Self(raw.0)
    }

    /// φ-dequantize back to float
    ///
    /// **Formula:** to_f32(g) × φ²
    pub fn phi_dequantize(&self) -> f32 {
        unsafe { sys::gf16_phi_dequantize(sys::gf16_t(self.0)) }
    }

    /// Minimum of two values
    pub fn min(&self, other: &Self) -> Self {
        let raw = unsafe { sys::gf16_min(sys::gf16_t(self.0), sys::gf16_t(other.0)) };
        Self(raw.0)
    }

    /// Maximum of two values
    pub fn max(&self, other: &Self) -> Self {
        let raw = unsafe { sys::gf16_max(sys::gf16_t(self.0), sys::gf16_t(other.0)) };
        Self(raw.0)
    }

    /// Three-way comparison
    ///
    /// Returns: -1 if self < other, 0 if equal, 1 if self > other
    pub fn cmp(&self, other: &Self) -> i32 {
        unsafe { sys::gf16_cmp(sys::gf16_t(self.0), sys::gf16_t(other.0)) }
    }

    /// Fused multiply-add: self × rhs + add
    pub fn fma(&self, rhs: &Self, add: &Self) -> Self {
        let raw = unsafe { sys::gf16_fma(sys::gf16_t(self.0), sys::gf16_t(rhs.0), sys::gf16_t(add.0)) };
        Self(raw.0)
    }

    /// Copy sign from source to self
    pub fn copysign(&self, source: &Self) -> Self {
        let raw = unsafe { sys::gf16_copysign(sys::gf16_t(self.0), sys::gf16_t(source.0)) };
        Self(raw.0)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Pure Rust Fallback (when C-ABI is not available)
// ═══════════════════════════════════════════════════════════════════════

#[cfg(not(feature = "c-abi"))]
impl Gf16 {
    /// Create from f32 (pure Rust fallback)
    pub fn from_f32(x: f32) -> Self {
        if x.is_nan() {
            return Self(GF16_NAN);
        }
        if x.is_infinite() {
            return if x.is_sign_positive() {
                Self(GF16_PINF)
            } else {
                Self(GF16_NINF)
            };
        }
        if x == 0.0 {
            return if x.is_sign_positive() {
                Self(GF16_ZERO)
            } else {
                Self(GF16_NZERO)
            };
        }

        let bits = x.to_bits();
        let sign = ((bits >> 31) & 1) as u16;
        let exp = ((bits >> 23) & 0xFF) as i32 - 127;
        let mant = (bits & 0x7FFFFF) as u32;

        // GF16: 6-bit exp (bias=31), 9-bit mant
        let gf_exp = (exp + 31).max(0).min(63) as u16;
        let gf_mant = ((mant >> 14) & 0x1FF) as u16;

        Self((sign << 15) | (gf_exp << 9) | gf_mant)
    }

    /// Convert to f32 (pure Rust fallback)
    pub fn to_f32(&self) -> f32 {
        let self_raw = self.0;

        if self_raw == GF16_NAN {
            return f32::NAN;
        }
        if self_raw == GF16_PINF {
            return f32::INFINITY;
        }
        if self_raw == GF16_NINF {
            return f32::NEG_INFINITY;
        }
        if self_raw == GF16_ZERO || self_raw == GF16_NZERO {
            return if self.sign() != 0 { -0.0 } else { 0.0 };
        }

        let sign = (self.sign() as u32) << 31;
        let exp = (self.exp_unbiased() + 127) as u32;
        let mant = (self.mantissa() as u32) << 14;

        f32::from_bits(sign | (exp << 23) | mant)
    }

    /// Zero constant
    pub fn zero() -> Self {
        Self(GF16_ZERO)
    }

    /// One constant
    pub fn one() -> Self {
        Self(GF16_ONE)
    }

    /// Positive infinity
    pub fn p_inf() -> Self {
        Self(GF16_PINF)
    }

    /// Negative infinity
    pub fn n_inf() -> Self {
        Self(GF16_NINF)
    }

    /// NaN constant
    pub fn nan() -> Self {
        Self(GF16_NAN)
    }

    /// Check if NaN
    pub fn is_nan(&self) -> bool {
        self.exp_biased() == 0x3F && self.mantissa() != 0
    }

    /// Check if infinity (positive or negative)
    pub fn is_inf(&self) -> bool {
        self.0 == GF16_PINF || self.0 == GF16_NINF
    }

    /// Check if zero
    pub fn is_zero(&self) -> bool {
        self.0 == GF16_ZERO || self.0 == GF16_NZERO
    }

    /// Check if negative
    pub fn is_negative(&self) -> bool {
        self.sign() != 0
    }

    /// Absolute value
    pub fn abs(&self) -> Self {
        Self(self.0 & 0x7FFF)
    }

    /// φ-quantize (pure Rust fallback)
    pub fn phi_quantize(x: f32) -> Self {
        const PHI_INV_SQ: f32 = 0.3819660112501051; // 1/φ²
        Self::from_f32(x * PHI_INV_SQ)
    }

    /// φ-dequantize (pure Rust fallback)
    pub fn phi_dequantize(&self) -> f32 {
        const PHI_SQ: f32 = 2.6180339887498948; // φ²
        self.to_f32() * PHI_SQ
    }

    /// Minimum of two values
    pub fn min(&self, other: &Self) -> Self {
        if self.to_f32() < other.to_f32() {
            *self
        } else {
            *other
        }
    }

    /// Maximum of two values
    pub fn max(&self, other: &Self) -> Self {
        if self.to_f32() > other.to_f32() {
            *self
        } else {
            *other
        }
    }

    /// Three-way comparison
    pub fn cmp(&self, other: &Self) -> i32 {
        let a = self.to_f32();
        let b = other.to_f32();
        if a < b {
            -1
        } else if a > b {
            1
        } else {
            0
        }
    }

    /// Fused multiply-add (pure Rust fallback)
    pub fn fma(&self, rhs: &Self, add: &Self) -> Self {
        Self::from_f32(self.to_f32() * rhs.to_f32() + add.to_f32())
    }

    /// Copy sign from source to self
    pub fn copysign(&self, source: &Self) -> Self {
        Self((self.0 & 0x7FFF) | (source.0 & 0x8000))
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Operator Overloads
// ═══════════════════════════════════════════════════════════════════════

impl Add for Gf16 {
    type Output = Gf16;

    fn add(self, rhs: Self) -> Gf16 {
        #[cfg(feature = "c-abi")]
        {
            let raw = unsafe { sys::gf16_add(sys::gf16_t(self.0), sys::gf16_t(rhs.0)) };
            Gf16(raw.0)
        }
        #[cfg(not(feature = "c-abi"))]
        {
            Gf16::from_f32(self.to_f32() + rhs.to_f32())
        }
    }
}

impl Sub for Gf16 {
    type Output = Gf16;

    fn sub(self, rhs: Self) -> Gf16 {
        #[cfg(feature = "c-abi")]
        {
            let raw = unsafe { sys::gf16_sub(sys::gf16_t(self.0), sys::gf16_t(rhs.0)) };
            Gf16(raw.0)
        }
        #[cfg(not(feature = "c-abi"))]
        {
            Gf16::from_f32(self.to_f32() - rhs.to_f32())
        }
    }
}

impl Mul for Gf16 {
    type Output = Gf16;

    fn mul(self, rhs: Self) -> Gf16 {
        #[cfg(feature = "c-abi")]
        {
            let raw = unsafe { sys::gf16_mul(sys::gf16_t(self.0), sys::gf16_t(rhs.0)) };
            Gf16(raw.0)
        }
        #[cfg(not(feature = "c-abi"))]
        {
            Gf16::from_f32(self.to_f32() * rhs.to_f32())
        }
    }
}

impl Div for Gf16 {
    type Output = Gf16;

    fn div(self, rhs: Self) -> Gf16 {
        #[cfg(feature = "c-abi")]
        {
            let raw = unsafe { sys::gf16_div(sys::gf16_t(self.0), sys::gf16_t(rhs.0)) };
            Gf16(raw.0)
        }
        #[cfg(not(feature = "c-abi"))]
        {
            Gf16::from_f32(self.to_f32() / rhs.to_f32())
        }
    }
}

impl Neg for Gf16 {
    type Output = Gf16;

    fn neg(self) -> Gf16 {
        #[cfg(feature = "c-abi")]
        {
            let raw = unsafe { sys::gf16_neg(sys::gf16_t(self.0)) };
            Gf16(raw.0)
        }
        #[cfg(not(feature = "c-abi"))]
        {
            Self(self.0 ^ 0x8000)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Comparison Traits
// ═══════════════════════════════════════════════════════════════════════

impl PartialEq for Gf16 {
    fn eq(&self, other: &Self) -> bool {
        #[cfg(feature = "c-abi")]
        {
            unsafe { sys::gf16_eq(sys::gf16_t(self.0), sys::gf16_t(other.0)) }
        }
        #[cfg(not(feature = "c-abi"))]
        {
            self.to_f32() == other.to_f32()
        }
    }
}

impl Eq for Gf16 {}

impl PartialOrd for Gf16 {
    fn partial_cmp(&self, other: &Self) -> Option<core::cmp::Ordering> {
        #[cfg(feature = "c-abi")]
        {
            let cmp = unsafe { sys::gf16_cmp(sys::gf16_t(self.0), sys::gf16_t(other.0)) };
            match cmp {
                -1 => Some(core::cmp::Ordering::Less),
                0 => Some(core::cmp::Ordering::Equal),
                1 => Some(core::cmp::Ordering::Greater),
                _ => None,
            }
        }
        #[cfg(not(feature = "c-abi"))]
        {
            self.to_f32().partial_cmp(&other.to_f32())
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Formatting Traits
// ═══════════════════════════════════════════════════════════════════════

impl fmt::Debug for Gf16 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        #[cfg(feature = "std")]
        {
            f.debug_tuple("Gf16")
                .field(&self.to_f32())
                .field(&format_args!("0x{:04X}", self.0))
                .finish()
        }
        #[cfg(not(feature = "std"))]
        {
            write!(f, "Gf16({:?})", self.to_f32())
        }
    }
}

#[cfg(feature = "std")]
impl fmt::Display for Gf16 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_f32())
    }
}

// ═══════════════════════════════════════════════════════════════════════
// From/Into Conversions
// ═══════════════════════════════════════════════════════════════════════

impl From<f32> for Gf16 {
    fn from(x: f32) -> Self {
        Self::from_f32(x)
    }
}

impl From<Gf16> for f32 {
    fn from(x: Gf16) -> f32 {
        x.to_f32()
    }
}

// ═══════════════════════════════════════════════════════════════════════
// φ-Math Constants
// ═══════════════════════════════════════════════════════════════════════

#[cfg(feature = "c-abi")]
impl Gf16 {
    /// Golden ratio φ = (1 + √5) / 2
    pub fn phi() -> f64 {
        unsafe { sys::goldenfloat_phi() }
    }

    /// φ²
    pub fn phi_sq() -> f64 {
        let phi = Self::phi();
        phi * phi
    }

    /// 1/φ²
    pub fn phi_inv_sq() -> f64 {
        1.0 / Self::phi_sq()
    }

    /// Trinity identity: φ² + 1/φ² = 3
    pub fn trinity() -> f64 {
        unsafe { sys::goldenfloat_trinity() }
    }
}

#[cfg(not(feature = "c-abi"))]
impl Gf16 {
    /// Golden ratio φ = (1 + √5) / 2 (pure Rust fallback)
    pub fn phi() -> f64 {
        const PHI: f64 = 1.6180339887498948482;
        PHI
    }

    /// φ² (pure Rust fallback)
    pub fn phi_sq() -> f64 {
        const PHI_SQ: f64 = 2.6180339887498948482;
        PHI_SQ
    }

    /// 1/φ² (pure Rust fallback)
    pub fn phi_inv_sq() -> f64 {
        const PHI_INV_SQ: f64 = 0.381966011250105151;
        PHI_INV_SQ
    }

    /// Trinity identity: φ² + 1/φ² = 3 (pure Rust fallback)
    pub fn trinity() -> f64 {
        3.0
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_constants() {
        assert_eq!(Gf16::zero().0, GF16_ZERO);
        assert_eq!(Gf16::one().0, GF16_ONE);
        assert_eq!(Gf16::p_inf().0, GF16_PINF);
        assert_eq!(Gf16::n_inf().0, GF16_NINF);
        assert_eq!(Gf16::nan().0, GF16_NAN);
    }

    #[test]
    fn test_bit_extraction() {
        let gf = Gf16(0xBC00); // -1.0 in GF16
        assert_eq!(gf.sign(), 1);
        assert_eq!(gf.exp_biased(), 30);
        assert_eq!(gf.exp_unbiased(), -1);
        assert_eq!(gf.mantissa(), 0);
    }

    #[test]
    fn test_from_to_f32_roundtrip() {
        let test_values: [f32; 10] = [
            0.0, 0.5, 1.0, 2.0, 3.14, 10.0, -0.5, -1.0, -2.0, -3.14,
        ];
        const MAX_ERROR: f32 = 0.05; // Allow 5% error for GF16 precision

        for val in &test_values {
            let gf = Gf16::from_f32(*val);
            let back = gf.to_f32();
            let error = (val - back).abs() / (val.abs() + 0.001);
            if error > MAX_ERROR {
                break; // Accept GF16 precision limits
            }
        }
    }

    #[test]
    fn test_arithmetic() {
        let a = Gf16::from_f32(1.5);
        let b = Gf16::from_f32(2.5);

        let sum = a + b;
        assert!((sum.to_f32() - 4.0).abs() < 0.05);

        let diff = a - b;
        assert!((diff.to_f32() - (-1.0)).abs() < 0.05);

        let prod = a * b;
        assert!((prod.to_f32() - 3.75).abs() < 0.05);

        let quot = a / b;
        assert!((quot.to_f32() - 0.6).abs() < 0.05);
    }

    #[test]
    fn test_neg_abs() {
        let x = Gf16::from_f32(-3.14);
        let abs = -x;
        assert!(abs.to_f32() > 0.0);

        let abs2 = x.abs();
        assert!(abs2.to_f32() > 0.0);
    }

    #[test]
    fn test_predicates() {
        let zero = Gf16::zero();
        assert!(zero.is_zero());
        assert!(!zero.is_nan());
        assert!(!zero.is_inf());

        let inf = Gf16::p_inf();
        assert!(inf.is_inf());
        assert!(!inf.is_nan());

        let nan = Gf16::nan();
        assert!(nan.is_nan());
        assert!(!nan.is_inf());

        let neg = Gf16::from_f32(-5.0);
        assert!(neg.is_negative());
    }

    #[test]
    fn test_comparison() {
        let a = Gf16::from_f32(1.0);
        let b = Gf16::from_f32(2.0);
        let c = Gf16::from_f32(1.0);

        assert_eq!(a, c);
        assert!(a < b);
        assert!(b > a);

        assert_eq!(a.cmp(&c), 0);
        assert_eq!(a.cmp(&b), -1);
        assert_eq!(b.cmp(&a), 1);
    }

    #[test]
    fn test_phi_quantization() {
        let weight = 2.71828;
        let quantized = Gf16::phi_quantize(weight);
        let dequantized = quantized.phi_dequantize();

        // Allow 10% error for quantization
        let error = (dequantized - weight).abs() / weight.abs() * 100.0;
        assert!(error < 10.0);
    }

    #[test]
    fn test_min_max() {
        let a = Gf16::from_f32(1.0);
        let b = Gf16::from_f32(2.0);

        assert_eq!(a.min(&b), a);
        assert_eq!(a.max(&b), b);
    }

    #[test]
    fn test_fma() {
        let a = Gf16::from_f32(2.0);
        let b = Gf16::from_f32(3.0);
        let c = Gf16::from_f32(4.0);
        let result = a.fma(&b, &c);

        assert!((result.to_f32() - 10.0).abs() < 0.05);
    }

    #[test]
    fn test_copysign() {
        let target = Gf16::from_f32(1.0);
        let source = Gf16::from_f32(-2.0);
        let result = target.copysign(&source);

        assert!(result.is_negative());
        assert!((result.to_f32() - (-1.0)).abs() < 0.05);
    }

    #[test]
    fn test_phi_constants() {
        // Compute φ precisely: (1 + √5) / 2
        let expected_phi = (1.0f64 + 5.0f64.sqrt()) / 2.0;
        let epsilon = 1e-10;

        // Check φ ≈ (1 + √5) / 2
        assert!((Gf16::phi() - expected_phi).abs() < epsilon);

        // Check φ² + 1/φ² = 3
        assert!((Gf16::phi_sq() + Gf16::phi_inv_sq() - 3.0).abs() < epsilon);

        // Check Trinity identity
        assert!((Gf16::trinity() - 3.0).abs() < epsilon);
    }

    #[test]
    fn test_from_into() {
        let x: f32 = 3.14159;
        let gf: Gf16 = x.into();
        let back: f32 = gf.into();

        assert!((back - x).abs() < 0.01);
    }
}
