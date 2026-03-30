#!/usr/bin/env python3
"""
TRI Format Code Generator

Reads .tri spec files and generates language implementations.

Usage: python3 tools/gen/tri_gen.py --lang rust --input specs/gf16.tri
"""

import sys
import argparse
from pathlib import Path


def parse_tri(path):
    """Parse .tri YAML spec file."""
    import yaml
    with open(path) as f:
        return yaml.safe_load(f)


def generate_c_header(spec):
    """Generate C header file."""
    typename = spec['abi']['c']['typename']

    output = f"""/**
 * GF16: φ-optimized 16-bit floating point
 * Generated from specs/gf16.tri
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#ifndef GF16_H
#define GF16_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {{
#endif

typedef struct {{
    {typename} raw;
}} gf16_t;

/* Bit extraction */
#define GF16_SIGN(g)    (((g).raw >> 15) & 0x1)
#define GF16_EXP(g)     (((g).raw >> 9)  & 0x3F)
#define GF16_MANT(g)    ((g).raw         & 0x1FF)

/* Special values */
#define GF16_PINF       ((gf16_t){{.raw = 0x7E00}})
#define GF16_NINF       ((gf16_t){{.raw = 0xFE00}})
#define GF16_NAN        ((gf16_t){{.raw = 0x7E01}})
#define GF16_PZERO     ((gf16_t){{.raw = 0x0000}})
#define GF16_NZERO     ((gf16_t){{.raw = 0x8000}}

/* Constants */
#define GF16_EXP_BIAS   31

gf16_t gf16_from_f32(float x);
float gf16_to_f32(gf16_t g);

#ifdef __cplusplus
}}
#endif

#endif /* GF16_H */
"""
    return output


def generate_c_source(spec):
    """Generate C source file."""
    output = """/**
 * GF16: φ-optimized 16-bit floating point
 * Generated from specs/gf16.tri
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#include "gf16.h"
#include <math.h>

gf16_t gf16_from_f32(float x) {
    /* Handle special cases */
    if (isnan(x)) return GF16_NAN;
    if (isinf(x)) return x > 0 ? GF16_PINF : GF16_NINF;
    if (x == 0.0f) return signbit(x) ? GF16_NZERO : GF16_PZERO;

    /* Extract f32 components */
    union {{ float f; uint32_t u; }} bits = {{.f = x};
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

    gf16_t result = {{
        .raw = (uint16_t)((sign << 15) | (gf_exp << 9) | gf_mant)
    }};
    return result;
}

float gf16_to_f32(gf16_t g) {
    uint16_t raw = g.raw;
    uint32_t sign = (raw >> 15) & 0x1;
    uint32_t exp = (raw >> 9) & 0x3F;
    uint32_t mant = raw & 0x1FF;

    /* Handle special values */
    if (exp == 63) {{
        if (mant == 0) return sign ? -INFINITY : INFINITY;
        return NAN;
    }}
    if (exp == 0 && mant == 0) {{
        return sign ? -0.0f : 0.0f;
    }}

    /* Convert to f32 */
    int32_t f32_exp = (int32_t)exp - 31 + 127;
    uint32_t f32_mant = mant << 14;

    union {{ float f; uint32_t u; }} result = {{
        .u = (sign << 31) | (f32_exp << 23) | f32_mant
    }};
    return result.f;
}
"""
    return output


def generate_rust(spec):
    """Generate Rust implementation."""
    typename = spec['abi']['rust']['typename']

    output = f"""/**
 * GF16: φ-optimized 16-bit floating point
 * Generated from specs/gf16.tri
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#![no_std]

/// GF16 value stored as raw {typename}
#[repr(C, packed)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Gf16 {{
    pub raw: {typename},
}}

impl Gf16 {{
    /* Field extraction */
    #[inline]
    pub const fn sign(&self) -> {typename} {{
        (self.raw >> 15) & 1
    }}

    #[inline]
    pub const fn exp_biased(&self) -> {typename} {{
        (self.raw >> 9) & 0x3F
    }}

    #[inline]
    pub const fn mantissa(&self) -> {typename} {{
        self.raw & 0x1FF
    }}

    /* Special values */
    pub const PINF: {typename} = 0x7E00;
    pub const NINF: {typename} = 0xFE00;
    pub const NAN: {typename} = 0x7E01;
    pub const ZERO: {typename} = 0x0000;
    pub const NEG_ZERO: {typename} = 0x8000;

    /* Predicates */
    #[inline]
    pub fn is_nan(&self) -> bool {{
        self.exp_biased() == 0x3F && self.mantissa() != 0
    }}

    #[inline]
    pub fn is_pos_inf(&self) -> bool {{
        self.raw == Self::PINF
    }}

    #[inline]
    pub fn is_neg_inf(&self) -> bool {{
        self.raw == Self::NINF
    }}

    #[inline]
    pub fn is_zero(&self) -> bool {{
        (self.raw & 0x7FFF) == 0
    }}

    /* Operations */
    #[inline]
    pub fn abs(&self) -> Self {{
        Self {{ raw: self.raw & 0x7FFF }}
    }}

    #[inline]
    pub fn negate(&self) -> Self {{
        Self {{ raw: self.raw ^ 0x8000 }}
    }}

    pub fn from_f32(x: f32) -> Self {{
        if x.is_nan() {{
            return Self {{ raw: Self::NAN }};
        }}
        if x.is_infinite() {{
            return if x.is_sign_positive() {{
                Self {{ raw: Self::PINF }}
            }} else {{
                Self {{ raw: Self::NINF }}
            }};
        }}
        if x == 0.0 {{
            return if x.is_sign_positive() {{
                Self {{ raw: Self::ZERO }}
            }} else {{
                Self {{ raw: Self::NEG_ZERO }}
            }};
        }}

        let bits = x.to_bits();
        let sign = ((bits >> 31) & 1) as {typename};
        let exp = ((bits >> 23) & 0xFF) as i32 - 127;
        let mant = (bits & 0x7FFFFF) as u32;

        let gf_exp = (exp + 31).max(0).min(63) as {typename};
        let gf_mant = ((mant >> 14) & 0x1FF) as {typename};

        Self {{
            raw: (sign << 15) | (gf_exp << 9) | gf_mant,
        }}
    }}

    pub fn to_f32(&self) -> f32 {{
        if self.is_nan() {{
            return f32::NAN;
        }}
        if self.is_pos_inf() {{
            return f32::INFINITY;
        }}
        if self.is_neg_inf() {{
            return f32::NEG_INFINITY;
        }}
        if self.is_zero() {{
            return if self.sign() != 0 {{ -0.0 }} else {{ 0.0 }};
        }}

        let sign = (self.sign() as u32) << 31;
        let exp = ((self.exp_biased() as i16) - 31 + 127) as u32;
        let mant = (self.mantissa() as u32) << 14;

        f32::from_bits(sign | (exp << 23) | mant)
    }}
}}

impl From<f32> for Gf16 {{
    fn from(x: f32) -> Self {{
        Self::from_f32(x)
    }}
}}

impl From<Gf16> for f32 {{
    fn from(x: Gf16) -> Self {{
        x.to_f32()
    }}
}}
"""
    return output


def generate_zig(spec):
    """Generate Zig implementation."""
    typename = spec['abi']['zig']['typename']

    output = f"""//! GF16: φ-optimized 16-bit floating point
//! Generated from specs/gf16.tri
//!
//! MIT License — Copyright (c) 2026 Trinity Project

const GF16 = packed struct({typename}) {{
    sign: u1,
    exponent: u6,
    mantissa: u9,

    pub const PINF: GF16 = @bitCast(@as({typename}, 0x7E00));
    pub const NINF: GF16 = @bitCast(@as({typename}, 0xFE00));
    pub const NAN: GF16 = @bitCast(@as({typename}, 0x7E01));
    pub const ZERO: GF16 = @bitCast(@as({typename}, 0x0000));
    pub const NEG_ZERO: GF16 = @bitCast(@as({typename}, 0x8000));

    pub inline fn fromRaw(raw: {typename}) GF16 {{
        return @bitCast(raw);
    }}

    pub inline fn toRaw(self: GF16) {typename} {{
        return @bitCast(self);
    }}

    pub inline fn signBit(self: GF16) u1 {{
        return self.sign;
    }}

    pub inline fn expBiased(self: GF16) u6 {{
        return self.exponent;
    }}

    pub inline fn expUnbiased(self: GF16) i16 {{
        return @as(i16, @intCast(self.exponent)) - 31;
    }}

    pub inline fn mantissa(self: GF16) u9 {{
        return self.mantissa;
    }}

    pub inline fn isNan(self: GF16) bool {{
        return self.exponent == 63 and self.mantissa != 0;
    }}

    pub inline fn isInf(self: GF16) bool {{
        return self.exponent == 63 and self.mantissa == 0;
    }}

    pub inline fn isZero(self: GF16) bool {{
        return self.exponent == 0 and self.mantissa == 0;
    }}

    pub inline fn abs(self: GF16) GF16 {{
        var result = self;
        result.sign = 0;
        return result;
    }}

    pub inline fn negate(self: GF16) GF16 {{
        var result = self;
        result.sign = ~result.sign;
        return result;
    }}
}};

comptime {{
    // Validate bit layout
    std.debug.assert(@bitSizeOf(GF16) == 16);
    std.debug.assert(@alignOf(GF16) >= 2);
}}
"""
    return output


def generate_cpp(spec):
    """Generate C++ header-only implementation."""
    typename = spec['abi']['cpp']['typename']

    output = f"""/**
 * GF16: φ-optimized 16-bit floating point
 * Generated from specs/gf16.tri
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#pragma once
#include <cstdint>
#include <cmath>

namespace gf16 {{
struct GF16 {{
    {typename} raw;

    static constexpr {typename} PINF = 0x7E00;
    static constexpr {typename} NINF = 0xFE00;
    static constexpr {typename} NAN = 0x7E01;
    static constexpr {typename} ZERO = 0x0000;
    static constexpr {typename} NEG_ZERO = 0x8000;

    constexpr GF16() : raw(ZERO) {{}}
    constexpr GF16({typename} r) : raw(r) {{}}

    static inline GF16 from_f32(float x) {{
        if (std::isnan(x)) return GF16{{NAN}};
        if (std::isinf(x)) return x > 0 ? GF16{{PINF}} : GF16{{NINF}};
        if (x == 0.0f) return std::signbit(x) ? GF16{{NEG_ZERO}} : GF16{{ZERO}};

        union {{ float f; uint32_t u; }} bits;
        bits.f = x;
        uint32_t sign = (bits.u >> 31) & 0x1;
        int32_t exp = ((bits.u >> 23) & 0xFF) - 127;
        uint32_t mant = bits.u & 0x7FFFFF;

        int16_t gf_exp = std::clamp(exp + 31, 0, 63);
        uint16_t gf_mant = (mant >> 14) & 0x1FF;

        return GF16{{static_cast<{typename}>((sign << 15) | (gf_exp << 9) | gf_mant)}};
    }}

    inline float to_f32() const {{
        uint32_t sign = (raw >> 15) & 0x1;
        uint32_t exp = (raw >> 9) & 0x3F;
        uint32_t mant = raw & 0x1FF;

        if (exp == 63) {{
            if (mant == 0) return sign ? -INFINITY : INFINITY;
            return NAN;
        }}
        if (exp == 0 && mant == 0) {{
            return sign ? -0.0f : 0.0f;
        }}

        int32_t f32_exp = static_cast<int32_t>(exp) - 31 + 127;
        uint32_t f32_mant = mant << 14;

        union {{ float f; uint32_t u; }} result;
        result.u = (sign << 31) | (f32_exp << 23) | f32_mant;
        return result.f;
    }}

    inline bool is_nan() const {{ return ((raw >> 9) & 0x3F) == 63 && (raw & 0x1FF) != 0; }}
    inline bool is_inf() const {{ return ((raw >> 9) & 0x3F) == 63 && (raw & 0x1FF) == 0; }}
    inline bool is_zero() const {{ return (raw & 0x7FFF) == 0; }}

    inline GF16 abs() const {{ return GF16{{raw & 0x7FFF}}; }}
    inline GF16 negate() const {{ return GF16{{raw ^ 0x8000}}; }}
}};
}} // namespace gf16
"""
    return output


def main():
    parser = argparse.ArgumentParser(description="Generate code from .tri spec")
    parser.add_argument("--lang", "-l", required=True,
                        choices=["c", "rust", "zig", "cpp", "all"])
    parser.add_argument("--input", "-i", default="specs/gf16.tri")
    parser.add_argument("--output", "-o")

    args = parser.parse_args()

    spec = parse_tri(args.input)

    outputs = {}

    if args.lang in ["c", "all"]:
        outputs["c/gf16.h"] = generate_c_header(spec)
        outputs["c/gf16.c"] = generate_c_source(spec)

    if args.lang in ["rust", "all"]:
        outputs["rust/src/lib.rs"] = generate_rust(spec)

    if args.lang in ["zig", "all"]:
        outputs["zig/src/formats/gf16.zig"] = generate_zig(spec)

    if args.lang in ["cpp", "all"]:
        outputs["cpp/gf16.hpp"] = generate_cpp(spec)

    # Write outputs
    for path, content in outputs.items():
        out_path = Path(path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(content)
        print(f"Generated {path}")


if __name__ == "__main__":
    main()
