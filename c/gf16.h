/**
 * GF16 Reference Implementation (C99)
 *
 * Golden Float 16: φ-optimized 16-bit floating point
 * Format: 1 sign bit, 6 exponent bits (bias=31), 9 mantissa bits
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#ifndef GF16_H
#define GF16_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * GF16 value stored as raw 16-bit unsigned integer
 *
 * Bit layout:
 *   [15]     Sign (0 = positive, 1 = negative)
 *   [14:9]   Exponent (bias = 31)
 *   [8:0]    Mantissa (fractional part)
 */
typedef struct {
    uint16_t raw;
} gf16_t;

/* Bit extraction macros */
#define GF16_SIGN(g)    (((g).raw >> 15) & 0x1)
#define GF16_EXP(g)     (((g).raw >> 9)  & 0x3F)
#define GF16_MANT(g)    ((g).raw         & 0x1FF)

/* Special values (GF16: 6-bit exp, 9-bit mantissa) */
/* Exponent field = 0x3F (63) for special values */
#define GF16_PINF       ((gf16_t){.raw = 0x7E00})  /* +Infinity (exp=0x3F, mant=0) */
#define GF16_NINF       ((gf16_t){.raw = 0xFE00})  /* -Infinity (sign=1, exp=0x3F, mant=0) */
#define GF16_NAN        ((gf16_t){.raw = 0x7E01})  /* Quiet NaN (exp=0x3F, mant=1) */
#define GF16_PZERO     ((gf16_t){.raw = 0x0000})  /* +0.0 */
#define GF16_NZERO     ((gf16_t){.raw = 0x8000})  /* -0.0 */

/* Constants */
#define GF16_EXP_BIAS   31
#define GF16_EXP_MAX    62   /* All ones = infinity/NaN */
#define GF16_MANT_BITS  9

/*======================================================================
 * Conversion Functions
 *======================================================================*/

/**
 * Convert f32 to GF16 with round-to-nearest, ties-to-even
 */
gf16_t gf16_from_f32(float x);

/**
 * Convert GF16 to f32
 */
float gf16_to_f32(gf16_t g);

/*======================================================================
 * Arithmetic Functions
 *======================================================================*/

/**
 * Add two GF16 values
 * Computes in f32, rounds result to GF16
 */
gf16_t gf16_add(gf16_t a, gf16_t b);

/**
 * Subtract two GF16 values
 */
gf16_t gf16_sub(gf16_t a, gf16_t b);

/**
 * Multiply two GF16 values
 */
gf16_t gf16_mul(gf16_t a, gf16_t b);

/**
 * Divide two GF16 values
 */
gf16_t gf16_div(gf16_t a, gf16_t b);

/*======================================================================
 * Comparison Functions
 *======================================================================*/

/**
 * Compare two GF16 values
 * Returns: -1 if a < b, 0 if a == b, 1 if a > b
 */
int gf16_cmp(gf16_t a, gf16_t b);

/**
 * Equality test (handles signed zeros)
 */
bool gf16_eq(gf16_t a, gf16_t b);

/**
 * Less-than test
 */
bool gf16_lt(gf16_t a, gf16_t b);

/**
 * Less-than-or-equal test
 */
bool gf16_le(gf16_t a, gf16_t b);

/*======================================================================
 * Predicates
 *======================================================================*/

/**
 * Check if value is NaN
 */
static inline bool gf16_is_nan(gf16_t g) {
    return GF16_EXP(g) == 63 && GF16_MANT(g) != 0;
}

/**
 * Check if value is infinity (positive or negative)
 */
static inline bool gf16_is_inf(gf16_t g) {
    return GF16_EXP(g) == 63 && GF16_MANT(g) == 0;
}

/**
 * Check if value is zero (positive or negative)
 */
static inline bool gf16_is_zero(gf16_t g) {
    return (g.raw & 0x7FFF) == 0;
}

/**
 * Check if value is subnormal
 */
static inline bool gf16_is_subnormal(gf16_t g) {
    return GF16_EXP(g) == 0 && GF16_MANT(g) != 0;
}

/**
 * Check if value is negative
 */
static inline bool gf16_is_negative(gf16_t g) {
    return GF16_SIGN(g) == 1;
}

/*======================================================================
 * Utility Functions
 *======================================================================*/

/**
 * Create GF16 from raw bits
 */
static inline gf16_t gf16_from_raw(uint16_t raw) {
    return (gf16_t){.raw = raw};
}

/**
 * Get raw bits from GF16
 */
static inline uint16_t gf16_to_raw(gf16_t g) {
    return g.raw;
}

/**
 * Absolute value
 */
gf16_t gf16_abs(gf16_t g);

/**
 * Negate
 */
static inline gf16_t gf16_neg(gf16_t g) {
    return (gf16_t){.raw = g.raw ^ 0x8000};
}

/**
 * Copy sign from b to a
 */
gf16_t gf16_copysign(gf16_t a, gf16_t b);

/**
 * Minimum of two values
 */
static inline gf16_t gf16_min(gf16_t a, gf16_t b) {
    return gf16_lt(a, b) ? a : b;
}

/**
 * Maximum of two values
 */
static inline gf16_t gf16_max(gf16_t a, gf16_t b) {
    return gf16_lt(a, b) ? b : a;
}

/*======================================================================
 * φ-Math Functions
 *======================================================================*/

/**
 * φ-optimized quantization
 * Quantizes f32 to GF16 using φ-weighted bins
 */
gf16_t gf16_phi_quantize(float x);

/**
 * φ-optimized dequantization
 * Dequantizes GF16 to f32 using φ-weighted bins
 */
float gf16_phi_dequantize(gf16_t g);

#ifdef __cplusplus
}
#endif

#endif /* GF16_H */
