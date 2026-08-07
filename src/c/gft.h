/**
 * GoldenFloat — GF-T16 C-ABI Header
 *
 * Minimal C99 header for GF-T16 (ternary-exponent Golden Float).
 * SPECIFICATION for the gft16_* symbols in libgoldenfloat.{so,dylib,dll}
 * (implemented in src/c_abi.zig over src/formats/gft.zig).
 *
 * **Format:** [sign:1][exp:4 balanced-ternary trits][mant:9] — the exponent is a
 * balanced-ternary number stored as an unsigned OFFSET in [0,80]; the balanced
 * exponent is e = offset - 40; the top offset row (80) is reserved (Inf/NaN).
 * value = (-1)^sign * (1 + M/2^9) * 2^e,  e in [-40,+39]  (~24 decades).
 *
 * The 17-bit packed value is carried in the low bits of a uint32_t (gft16_t).
 *
 * **Usage:**
 * ```c
 * #include <gft.h>
 * gft16_t a = gft16_from_f32(3.14159f);
 * gft16_t b = gft16_from_f32(2.71828f);
 * float p = gft16_to_f32(gft16_mul(a, b));  // ~8.539
 * ```
 *
 * phi^2 + 1/phi^2 = 3 | TRINITY
 */

#ifndef GOLDENFLOAT_GFT_H
#define GOLDENFLOAT_GFT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Raw 17-bit GF-T16 pattern carried in the low bits of a uint32_t. */
typedef uint32_t gft16_t;

/** Encode an IEEE float32 into GF-T16 (round-to-nearest, saturate to Inf). */
gft16_t gft16_from_f32(float x);
/** Decode a GF-T16 value back to float32. */
float gft16_to_f32(gft16_t g);

gft16_t gft16_add(gft16_t a, gft16_t b);
gft16_t gft16_sub(gft16_t a, gft16_t b);
gft16_t gft16_mul(gft16_t a, gft16_t b);
gft16_t gft16_div(gft16_t a, gft16_t b);

gft16_t gft16_neg(gft16_t g);
gft16_t gft16_abs(gft16_t g);

/** 1 if g is finite (not the reserved Inf/NaN row), else 0. */
uint8_t gft16_is_finite(gft16_t g);

/** Balanced zero point: offset that encodes exponent 0 (value in [1,2)). */
#define GFT16_EXP_OFFSET 40
/** Reserved special row (Inf/NaN): offset 3^4 - 1. */
#define GFT16_OFFSET_MAX 80
/** Number of exponent trits. */
#define GFT16_EXP_TRITS  4
/** Number of mantissa bits. */
#define GFT16_MANT_BITS  9

#ifdef __cplusplus
}
#endif

#endif /* GOLDENFLOAT_GFT_H */
