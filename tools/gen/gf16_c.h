/* GF16: φ-optimized 16-bit floating point */
/* Generated from specs/gf16.tri */
/* MIT License — Copyright (c) 2026 Trinity Project */

#ifndef GF16_H
#define GF16_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint16_t raw;
} gf16_t;

/* Bit extraction */
#define GF16_SIGN(g)    (((g).raw >> 15) & 0x1)
#define GF16_EXP(g)     (((g).raw >> 9)  & 0x3F)
#define GF16_MANT(g)    ((g).raw         & 0x1FF)

/* Special values */
#define GF16_PINF       ((gf16_t){.raw = 0x7E00})
#define GF16_NINF       ((gf16_t){.raw = 0xFE00})
#define GF16_NAN        ((gf16_t){.raw = 0x7E01})
#define GF16_PZERO     ((gf16_t){.raw = 0x0000})
#define GF16_NZERO     ((gf16_t){.raw = 0x8000})

/* Constants */
#define GF16_EXP_BIAS   31

gf16_t gf16_from_f32(float x);
float gf16_to_f32(gf16_t g);

#ifdef __cplusplus
}
#endif

#endif /* GF16_H */
