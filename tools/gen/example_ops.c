/**
 * GF16 Arithmetic Operations (generated from specs/ops.tri)
 *
 * Level 1: Elementary arithmetic operations on GF16 values
 */

#include "gf16.h"

/* Helper: convert to f32, perform op, convert back */
static inline gf16_t f32_op_f32_f32(gf16_t a, gf16_t b, float (*op)(float, float)) {
    float fa = gf16_to_f32(a);
    float fb = gf16_to_f32(b);
    float fr = op(fa, fb);
    return gf16_from_f32(fr);
}

/* Operations */
gf16_t gf16_add(gf16_t a, gf16_t b) {
    return f32_op_f32_f32(a, b, &faddf);
}

gf16_t gf16_sub(gf16_t a, gf16_t b) {
    return f32_op_f32_f32(a, b, &fsubf);
}

gf16_t gf16_mul(gf16_t a, gf16_t b) {
    return f32_op_f32_f32(a, b, &fmulf);
}

gf16_t gf16_div(gf16_t a, gf16_t b) {
    return f32_op_f32_f32(a, b, &fdivf);
}

gf16_t gf16_sqrt(gf16_t a) {
    float fa = gf16_to_f32(a);
    float fr = sqrtf(fa);
    return gf16_from_f32(fr);
}

/* Bit operations */
gf16_t gf16_abs(gf16_t a) {
    return (gf16_t){.raw = a.raw & 0x7FFF };
}

gf16_t gf16_neg(gf16_t a) {
    return (gf16_t){.raw = a.raw ^ 0x8000 };
}

/* Comparison flags */
typedef struct {
    uint8_t lt;
    uint8_t eq;
    uint8_t gt;
} gf16_cmp_t;

gf16_cmp_t gf16_cmp(gf16_t a, gf16_t b) {
    float fa = gf16_to_f32(a);
    float fb = gf16_to_f32(b);
    gf16_cmp_t result;
    result.lt = (fa < fb);
    result.eq = (fa == fb);
    result.gt = (fa > fb);
    return result;
}

/* Min/Max */
gf16_t gf16_min(gf16_t a, gf16_t b) {
    return (fa < fb) ? a : b;
}

gf16_t gf16_max(gf16_t a, gf16_t b) {
    return (fa > fb) ? a : b;
}
