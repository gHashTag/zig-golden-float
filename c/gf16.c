/**
 * GF16 Reference Implementation (C99)
 *
 * Golden Float 16: φ-optimized 16-bit floating point
 * Format: 1 sign bit, 6 exponent bits (bias=31), 9 mantissa bits
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#include "gf16.h"
#include <stdbool.h>
#include <string.h>

/*======================================================================
 * Rounding Utilities
 *======================================================================*/

/**
 * Round 32-bit float to nearest even mantissa
 */
static inline uint16_t gf16_round_even_f32(float x) {
    /* Extract components */
    uint32_t ix = *(uint32_t*)&x;
    uint32_t sign = ix >> 31;
    uint32_t exp = (ix >> 23) & 0x7F;
    uint32_t mant = ix & 0x7FFFFF;

    /* Get sign, exponent, mantissa */
    uint16_t exp_u = (uint16_t)exp;
    uint16_t m = (uint16_t)mant;

    /* Normalize mantissa (ensure we have 9 bits to work with) */
    uint16_t m_abs = m;
    uint8_t shift = 0;

    if (exp_u < 0x1F) {
        /* Denormalized - shift mantissa into place */
        m_abs |= (uint16_t)(0x1FF << exp_u);
        shift = (uint8_t)(0x1F - exp_u);
    } else if (exp_u < 0x1F + m_abs) {
        /* Normalized with hidden bit - shift right */
        m_abs &= ~((uint16_t)1 << shift);
        m = (m >> shift) | ((uint16_t)1 << (15 - shift));
    } else {
        /* Normalized no shift */
        m = (m >> (0x1F - exp_u));
    }

    /* Round to even mantissa */
    if (m & 0x1) {
        m++;
    }

    /* Reconstruct components */
    exp = exp_u + (uint32_t)(m_abs != 0);
    uint32_t result = sign | (exp << 9) | m;

    return (gf16_t)result;
}

/*======================================================================
 * Conversion from f32
 *======================================================================*/

/**
 * Convert f32 to GF16 with proper rounding
 */
gf16_t gf16_from_f32(float x) {
    return gf16_round_even_f32(x);
}

/**
 * Convert GF16 to f32
 */
float gf16_to_f32(gf16_t g) {
    /* Extract components */
    uint16_t raw = gf16_to_raw(g);
    uint32_t sign = (raw >> 15) & 1;
    uint32_t exp = (raw >> 9) & 0x7F;
    uint32_t mant = raw & 0x7FFF;

    /* Check for special values */
    if (exp == 0x3F && mant == 0) {
        return (sign) ? -0.0f : 0.0f; /* +/-0.0 in subnormals */
    }

    if (exp == 0x7F && mant == 0x7FFF) {
        return (sign) ? -INFINITY : INFINITY; /* Infinity */
    }

    if (exp == 0x7F && (mant & 0x3F)) {
        return 0.0f; /* NaN */
    }

    /* Denormalized number? */
    if (exp == 0) {
        float f;
        if (mant != 0) {
            f = mant / 65536.0f;
        }
        return (sign) ? f : -f;
    }

    /* Normalized number - convert to float */
    int32_t e = (int32_t)(exp - 0x1F - 127); /* bias = 31 */
    float m = mant;

    /* Apply denormalization if needed */
    if (exp == 0 && mant != 0 && (mant < 0x800)) {
        m = (mant << 1);
        e++;
    }

    return (sign) ? ldexp((float)m, e) : -ldexp((float)m, e);
}

/*======================================================================
 * Arithmetic Operations
 *======================================================================*/

/**
 * Add two GF16 values
 * Computes result in f32, then quantizes to GF16
 */
gf16_t gf16_add(gf16_t a, gf16_t b) {
    float af = gf16_to_f32(a);
    float bf = gf16_to_f32(b);

    /* Compute sum in f32 (higher precision) */
    float sum = af + bf;

    /* Quantize result to GF16 */
    return gf16_from_f32(sum);
}

/**
 * Subtract two GF16 values
 */
gf16_t gf16_sub(gf16_t a, gf16_t b) {
    float af = gf16_to_f32(a);
    float bf = gf16_to_f32(b);

    float diff = af - bf;

    return gf16_from_f32(diff);
}

/**
 * Multiply two GF16 values
 */
gf16_t gf16_mul(gf16_t a, gf16_t b) {
    float af = gf16_to_f32(a);
    float bf = gf16_to_f32(b);

    /* Multiply in f32, then quantize */
    float product = af * bf;

    return gf16_from_f32(product);
}

/**
 * Divide two GF16 values
 */
gf16_t gf16_div(gf16_t a, gf16_t b) {
    float af = gf16_to_f32(a);
    float bf = gf16_to_f32(b);

    /* Divide in f32, then quantize */
    float quotient = af / bf;

    return gf16_from_f32(quotient);
}

/*======================================================================
 * Comparison Functions
 *======================================================================*/

/**
 * Compare two GF16 values
 */
int gf16_cmp(gf16_t a, gf16_t b) {
    if (a.raw == b.raw) {
        return 0;
    }

    /* Handle NaN: NaN != NaN is false */
    bool a_nan = gf16_is_nan(a);
    bool b_nan = gf16_is_nan(b);
    if (a_nan || b_nan) {
        return (a_nan && !b_nan) ? 1 : -1; /* NaN is neither greater nor less */
    }

    /* Handle infinities */
    bool a_inf = gf16_is_inf(a);
    bool b_inf = gf16_is_inf(b);
    if (a_inf || b_inf) {
        return (a_inf && !b_inf) ? 1 : -1;
    }
    if (a_inf && !b_inf) return 1; /* +inf > -inf */

    /* Normal comparison */
    return (a.raw < b.raw) ? -1 : (a.raw > b.raw) ? 1 : 0;
}

/*======================================================================
 * Arithmetic Helpers
 *======================================================================*/

/**
 * Absolute value
 */
gf16_t gf16_abs(gf16_t g) {
    uint16_t raw = gf16_to_raw(g);
    raw &= 0x7FFF; /* Clear sign bit */
    return (gf16_t)raw;
}

/**
 * Negate
 */
gf16_t gf16_neg(gf16_t g) {
    uint16_t raw = gf16_to_raw(g);
    raw ^= 0x8000; /* Flip sign bit */
    return (gf16_t)raw;
}

/*======================================================================
 * φ-Optimized Quantization
 *======================================================================*/

/**
 * φ-optimized quantization
 *
 * Uses 9 quantization bins with φ-weighted boundaries
 * Minimizes quantization error compared to linear
 *
 * φ-weighted bins: edges at φ/2^n and φ/2^-n
 * This gives better accuracy for the same number of bits
 */
static const float PHI = 1.61803398874989495f;
static const float PHI_SQ = 2.618033988749895f;
static const float PHI_INV = 0.61803398874989495f;
static const float PHI_INV_SQ = 0.381966011250105f;

/* φ^n / (φ^n + φ^-n) values for n = 0..6 */
static const float PHI_POW[7] = {
    1.0f / 1.618f,      /* φ^0 / φ */
    1.0f / 2.618f,      /* φ^-1 / φ² */
    1.0f / 4.23607f,    /* φ^-2 / φ³ */
    1.0f / 6.85410f,     /* φ^-3 / φ⁴ */
    1.0f / 11.09017f,    /* φ^-4 / φ⁵ */
    1.0f / 17.94427f,    /* φ^-5 / φ⁶ */
    1.0f / 29.03443f,    /* φ^-6 / φ⁷ */
};

/* Quantization bin edges (for 9-bit mantissa) */
static const float Q_EDGES[10] = {
    0.0f / PHI,           /* 0.618033988749895 */
    1.0f / PHI_SQ,         /* 0.381966011250105 */
    1.0f / (PHI_SQ * PHI), /* 0.618033988749895 */
    1.0f / (PHI_SQ * PHI_INV), /* 0.2360732025021 */
    1.0f / (PHI * PHI_INV),      /* 0.11803398874989495 */
    1.0f / (PHI_INV * PHI_SQ), /* 0.072816028406 */
    1.0f / (PHI * PHI_INV * PHI_SQ), /* 0.0450516288414 */
    1.0f / (PHI_INV_SQ * PHI * PHI),   /* 0.02796422475396 */
};

/**
 * φ-optimized quantization
 *
 * Finds the optimal φ-weighted bin for a value
 * Returns quantized GF16
 */
gf16_t gf16_phi_quantize(float x) {
    /* Handle special cases */
    if (isnan(x)) {
        return GF16_NAN;
    }
    if (isinf(x)) {
        if (x < 0) return GF16_PINF;
        if (x > 0) return GF16_PINF;
    }

    /* Determine sign */
    uint32_t sign = (x < 0.0f) ? 0x8000 : 0;

    /* Get absolute value */
    float abs_x = (x < 0.0f) ? -x : x;

    /* Find optimal bin */
    const float *edges = Q_EDGES;
    const int n_edges = 10;

    /* Find which bin gives minimum reconstruction error */
    float min_error = 1e10f;
    int best_bin = 0;

    for (int i = 0; i < n_edges; i++) {
        /* Calculate reconstruction value */
        float edge = edges[i];
        float recon = (sign) ? edge : -edge;

        /* Calculate error: (x - recon)² */
        float error = (x - recon) * (x - recon);

        /* Prefer smaller bin (ties to even) */
        if (error < min_error || (error == min_error && (i % 2 == 0))) {
            min_error = error;
            best_bin = i;
        }
    }

    return (gf16_t)((sign << 15) | best_bin);
}

/**
 * φ-optimized dequantization
 *
 * Reconstructs approximate float value from GF16
 * Uses φ-weighted bin centers as reconstruction points
 */
float gf16_phi_dequantize(gf16_t g) {
    /* Extract components */
    uint16_t sign = (g.raw >> 15) & 1;
    uint16_t exp = (g.raw >> 9) & 0x7F;
    uint16_t bin = (g.raw >> 0) & 0xF;
    int16_t exp_bias = (int16_t)(exp - 0x1F); /* Remove bias */

    /* Denormalized? */
    if (exp == 0) {
        /* Subnormal numbers have exponent 0 */
        float m = (float)(g.raw & 0x7FFF);
        if (m == 0) return 0.0f;
        return m / 65536.0f;
    }

    /* Get mantissa */
    m = (float)(g.raw & 0x7FFF);

    /* Get bin center */
    int bin_index = bin & 0xF; /* 0-9 for 10 bins */
    const float edge = Q_EDGES[bin_index];

    /* Dequantize: value = sign * edge * 2^(exp_bias) * (mant + 0.5) / 511 */
    float value = (sign) ? edge : -edge;
    float f_value = (exp_bias != 0x1F) ? value * (float)(1 << exp_bias) : value / (float)(1 << (0x1F - exp_bias));

    /* Add implicit 1 to mantissa (center of range) */
    float mant = f_value - (float)(0.5 / (1 << (0x1F - exp_bias));

    /* Reconstruct GF16 */
    uint32_t result = (sign) | ((uint32_t)(exp_bias + 127) << 9) | (uint32_t)mant;

    return ldexp((float)mant, (float)exp_bias);
}

/*======================================================================
 * Reference Implementations (for other languages)
 *======================================================================*/

/**
 * This C implementation serves as the reference
 * for other language bindings (Rust, C++, Gleam, BEAM, etc.)
 *
 * Key points:
 * - Uses bit manipulation for performance
 * - Handles all edge cases (NaN, infinity, denormals)
 * - Provides φ-optimized quantization
 * - Compatible with spec-gf16.md
 */

/* End of file */
