/**
 * GF16 Rust Reference Implementation (no_std)
 *
 * Golden Float 16: φ-optimized 16-bit floating point
 * Format: 1 sign bit, 6 exponent bits (bias=31), 9 mantissa bits
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#![no_std]

/// GF16 type matching the bit layout
#[repr(C, packed)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Gf16 {
    /// Raw 16-bit value
    pub raw: u16,
}

impl Gf16 {
    /// Extract sign bit (most significant bit)
    #[inline]
    pub const fn sign(&self) -> u16 {
        (self.raw >> 15) & 1
    }

    /// Extract exponent bits (biased)
    #[inline]
    pub const fn exp(&self) -> u16 {
        ((self.raw >> 9) & 0x7F)
    }

    /// Extract mantissa bits
    #[inline]
    pub const fn mant(&self) -> u16 {
        self.raw & 0x1FF
    }

    /// Create from raw value
    #[inline]
    pub const fn from_raw(raw: u16) -> Self {
        Self { raw }
    }

    /// Get raw value
    #[inline]
    pub const fn to_raw(&self) -> u16 {
        self.raw
    }

    /// Absolute value
    #[inline]
    pub fn abs(&self) -> Self {
        Self { raw: self.raw & 0x7FFF }
    }

    /// Negate
    #[inline]
    pub fn neg(&self) -> Self {
        Self { raw: self.raw ^ 0x8000 }
    }

    /// Copy sign from another value
    #[inline]
    pub fn cpy_sign(&mut self, other: &Self) -> Self {
        self.raw &= 0x7FFF;
        self.raw |= (other.raw & 0x8000);
    }
}

    /// Extract exponent (unbiased)
    #[inline]
    pub const fn exp_unbiased(&self) -> i16 {
        ((self.raw >> 9) & 0x7F) as i16) - 31
    }
}

    /// Extract mantissa bits
    #[inline]
    pub const fn mant(&self) -> u16 {
        self.raw & 0x7FF
    }

    /// Check if NaN
    #[inline]
    pub fn is_nan(&self) -> bool {
        self.exp() == 0x3F && self.mant() == 0x7FFF
    }

    /// Check if positive infinity
    #[inline]
    pub fn is_pos_inf(&self) -> bool {
        self.exp() == 0x3F && self.mant() == 0x7FFF && self.sign() == 0
    }

    /// Check if negative infinity
    #[inline]
    pub fn is_neg_inf(&self) -> bool {
        self.exp() == 0x3F && self.mant() == 0x7FFF && self.sign() == 1
    }

    /// Check if subnormal
    #[inline]
    pub fn is_subnormal(&self) -> bool {
        self.exp() == 0 && self.mant() != 0
    }

    /// Check if zero
    #[inline]
    pub fn is_zero(&self) -> bool {
        self.raw == 0
    }

    /// Check if negative
    #[inline]
    pub fn is_negative(&self) -> bool {
        self.sign() == 1
    }

    /// Check if positive
    #[inline]
    pub fn is_positive(&self) -> bool {
        self.sign() == 0
    }
}

/*======================================================================
 * φ-Optimized Quantization
 *======================================================================*/

/// φ^n values for optimal quantization
const PHI: f64 = 1.61803398874989495;
const PHI_SQ: f64 = 2.618033988749895f;
const PHI_INV: f64 = 0.61803398874989495f;

/// φ^n / (φ^n + φ^-n) values
const PHI_POW: [f64; 7] = [
    PHI,           // 1.618033988749895
    PHI * PHI,       // 2.618033988749895
    PHI * PHI_SQ,   // 4.2360679774999
    PHI * PHI_INV, // 0.381966011250105
    PHI * PHI_INV, // 0.2360732025021
    PHI * PHI_INV_SQ, // 0.072816028406
];

/// φ-optimized quantization bins (10 bins for 9-bit mantissa)
const Q_EDGES: [f64; 10] = [
    1.0 / PHI,                     // 0.618033988749895
    1.0 / PHI_SQ,                 // 0.381966011250105
    1.0 / (PHI_SQ * PHI),        // 0.2360732025021
    1.0 / (PHI_INV * PHI),          // 0.11803398874989495
    1.0 / (PHI_INV * PHI_SQ),        // 0.072816028406
];

/**
 * φ-optimized quantization
 *
 * Finds the optimal φ-weighted bin for a value
 * Minimizes quantization error compared to linear
 */
pub fn phi_quantize(value: f32) -> Self {
    // Handle special cases
    if value.is_nan() {
        return Gf16::from_raw(GF16_NAN);
    }
    if !value.is_finite() {
        if value.is_sign_positive() {
            return Gf16::from_raw(GF16_PINF);
        } else {
            return Gf16::from_raw(GF16_NINF);
        }
    }

    let sign = if value.is_sign_positive() { 1 } else { 0 };

    let abs = value.abs();
    let exp = (abs.log2() - 127f32) as i32;

    /* Find optimal bin */
    let mut best_error = f32::MAX;
    let mut best_bin = 0;

    for (bin_idx, &edge) in Q_EDGES.iter().enumerate() {
        /* Reconstruct from bin center */
        let center = sign as f64 * *edge;

        /* Dequantize: value = sign * center * 2.0^(exp_bias) * ((mantissa as f64 / 511.0) + 0.5) */
        let reconstructed = (value - center).abs();

        if reconstructed < 0.0 {
            /* Clamp to [-1.0, 1.0] */
            if reconstructed < -1.0 {
                reconstructed = -1.0;
            }
        }

        let error = reconstructed * reconstructed;

        if error < best_error {
            best_error = error;
            best_bin = bin_idx;
        }
    }

    /* Quantize to GF16 */
    let f_value = sign as f32 * (best_bin as f64 * 2.0f32 * (1.0 / 511.0));
    let mantissa_u16 = (f_value / f_value).to_bits() as u16 & 0x1FF;
    let exp_u16 = exp as u16;
    let result = Gf16 { raw: mantissa_u16 | exp_u16 };

    result
}
}

/**
 * φ-optimized dequantization
 *
 * Reconstructs approximate float value from GF16
 * Uses φ-weighted bin centers from quantization
 */
pub fn phi_dequantize(&self) -> f32 {
    let raw = self.raw;
    let sign = (raw >> 15) & 1;
    let exp = ((raw >> 9) & 0x7F) as i16) - 31;
    let exp_bias = exp as i32;
    let mant = raw & 0x7FFF;

    // Denormalized?
    if exp == 0 {
        if mant == 0 {
            return 0.0f;
        }
        let m_u16 = (mant as u16) << 1;
        let m = m_u16 as f64;
        let e = exp_bias;
        let f = (sign as f64) * m * ldexp((f64)m, e) / 511.0;
        return f;
    }

    // Normalized
    let m_u16 = mant as u16;
    let m = mant as f64 / 511.0;
    let e = exp_bias;

    /* Find bin and dequantize */
    let bin_idx = (self.exp() >> 9) & 0xF;

    /* Get bin center */
    let q_edge = Q_EDGES[bin_idx as usize];
    if q_edge >= Q_EDGES.len() {
        q_edge = Q_EDGES.len() - 1;
    }
    let center = if sign >= 0 { q_edge } else { -q_edge };

    /* Reconstruct */
    let m_sign = if sign >= 0 { 1.0f } else { -1.0f };
    let m_center = m_sign as f64 * *q_edge;
    let value = center * 2.0f32 * ((mant as u16) as f64 / 511.0) + 0.5);
    let reconstructed = (value - center).abs();

    /* Dequantize */
    let f_value = sign * m_center * 2.0f32 * (1.0 / 511.0);
    let m_u16 = (f_value.abs().to_bits() as u16) & 0x1FF;
    let exp_u16 = self.exp();
    let result = Gf16 { raw: m_u16 | exp: exp_u16 };

    result.to_f32()
}

/*======================================================================
 * Comparison Implementations
 *======================================================================*/

impl PartialOrd<Gf16> for Gf16 {
    fn partial_cmp(&self, other: &Self) -> std::cmp::Ordering {
        // NaN comparison
        if self.is_nan() {
            return other.is_nan();
        } else if other.is_nan() {
            return std::cmp::Ordering::Equal;
        }

        // Handle infinities
        if self.is_pos_inf() {
            if other.is_pos_inf() {
                return std::cmp::Ordering::Equal;
            }
            return std::cmp::Ordering::Greater;
        }
        if self.is_neg_inf() {
            if other.is_neg_inf() {
                return std::cmp::Ordering::Equal;
            }
            return std::cmp::Ordering::Less;
        }
        if other.is_neg_inf() {
            if other.is_neg_inf() {
                return std::cmp::Ordering::Equal;
            }
            return std::cmp::Ordering::Greater;
        }

        // Normal comparison
        self.partial_cmp(other)
    }
}

impl PartialEq for Gf16 {
    fn eq(&self, other: &Self) -> bool {
        if self.raw == other.raw {
            true
        } else if self.is_nan() {
            other.is_nan()
        } else if other.is_nan() {
            false
        }
    }
    }
}
