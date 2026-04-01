/* GF16: φ-optimized 16-bit floating point */
/* Generated from specs/gf16.tri */
/* MIT License — Copyright (c) 2026 Trinity Project */

#include "gf16_c.h"
#include <math.h>

gf16_t gf16_from_f32(float x) {
    /* Handle special cases */
    if (isnan(x)) return GF16_NAN;
    if (isinf(x)) return x > 0 ? GF16_PINF : GF16_NINF;
    if (x == 0.0f) return signbit(x) ? GF16_NZERO : GF16_PZERO;

    /* Extract f32 components */
    union { float f; uint32_t u; } bits = { .f = x };
    uint32_t sign = (bits.u >> 31) & 0x1;
    int32_t exp = ((bits.u >> 23) & 0xFF) - 127;
    uint32_t mant = bits.u & 0x7FFFFF;

    /* Convert to GF16 exponent */
    int16_t gf_exp = exp + 31;

    /* Handle overflow/underflow */
    if (gf_exp >= 63) return GF16_PINF;
    if (gf_exp <= 0) return GF16_PZERO;

    /* Round mantissa to 9 bits */
    uint16_t gf_mant = (mant >> 14) & 0x1FF;

    gf16_t result = {
        .raw = (uint16_t)((sign << 15) | (gf_exp << 9) | gf_mant)
    };
    return result;
}

float gf16_to_f32(gf16_t g) {
    uint16_t raw = g.raw;
    uint32_t sign = (raw >> 15) & 0x1;
    uint32_t exp = (raw >> 9) & 0x3F;
    uint32_t mant = raw & 0x1FF;

    /* Handle special values */
    if (exp == 63) {
        if (mant == 0) return sign ? -INFINITY : INFINITY;
        return NAN;
    }
    if (exp == 0 && mant == 0) {
        return sign ? -0.0f : 0.0f;
    }

    /* Convert to f32 */
    int32_t f32_exp = (int32_t)exp - 31 + 127;
    uint32_t f32_mant = mant << 14;

    union { float f; uint32_t u; } result = {
        .u = (sign << 31) | (f32_exp << 23) | f32_mant
    };
    return result.f;
}
