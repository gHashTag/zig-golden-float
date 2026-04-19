/**
 * GF16: φ-optimized 16-bit floating point
 * Generated from specs/gf16.tri
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#![no_std]

/// GF16 value stored as raw u16
#[repr(C, packed)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Gf16 {
    pub raw: u16,
}

impl Gf16 {
    /* Field extraction */
    #[inline]
    pub const fn sign(&self) -> u16 {
        (self.raw >> 15) & 1
    }

    #[inline]
    pub const fn exp_biased(&self) -> u16 {
        (self.raw >> 9) & 0x3F
    }

    #[inline]
    pub const fn mantissa(&self) -> u16 {
        self.raw & 0x1FF
    }

    /* Special values */
    pub const PINF: u16 = 0x7E00;
    pub const NINF: u16 = 0xFE00;
    pub const NAN: u16 = 0x7E01;
    pub const ZERO: u16 = 0x0000;
    pub const NEG_ZERO: u16 = 0x8000;

    /* Predicates */
    #[inline]
    pub fn is_nan(&self) -> bool {
        self.exp_biased() == 0x3F && self.mantissa() != 0
    }

    #[inline]
    pub fn is_pos_inf(&self) -> bool {
        self.raw == Self::PINF
    }

    #[inline]
    pub fn is_neg_inf(&self) -> bool {
        self.raw == Self::NINF
    }

    #[inline]
    pub fn is_zero(&self) -> bool {
        (self.raw & 0x7FFF) == 0
    }

    /* Operations */
    #[inline]
    pub fn abs(&self) -> Self {
        Self { raw: self.raw & 0x7FFF }
    }

    #[inline]
    pub fn negate(&self) -> Self {
        Self { raw: self.raw ^ 0x8000 }
    }

    pub fn from_f32(x: f32) -> Self {
        if x.is_nan() {
            return Self { raw: Self::NAN };
        }
        if x.is_infinite() {
            return if x.is_sign_positive() {
                Self { raw: Self::PINF }
            } else {
                Self { raw: Self::NINF }
            };
        }
        if x == 0.0 {
            return if x.is_sign_positive() {
                Self { raw: Self::ZERO }
            } else {
                Self { raw: Self::NEG_ZERO }
            };
        }

        let bits = x.to_bits();
        let sign = ((bits >> 31) & 1) as u16;
        let exp = ((bits >> 23) & 0xFF) as i32 - 127;
        let mant = (bits & 0x7FFFFF) as u32;

        let gf_exp = (exp + 31).max(0).min(63) as u16;
        let gf_mant = ((mant >> 14) & 0x1FF) as u16;

        Self {
            raw: (sign << 15) | (gf_exp << 9) | gf_mant,
        }
    }

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
        let exp = ((self.exp_biased() as i16) - 31 + 127) as u32;
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
