/**
 * GF16: φ-optimized 16-bit floating point
 * Generated from specs/gf16.tri
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#pragma once
#include <cstdint>
#include <cmath>

namespace gf16 {
struct GF16 {
    uint16_t raw;

    static constexpr uint16_t PINF = 0x7E00;
    static constexpr uint16_t NINF = 0xFE00;
    static constexpr uint16_t NAN = 0x7E01;
    static constexpr uint16_t ZERO = 0x0000;
    static constexpr uint16_t NEG_ZERO = 0x8000;

    constexpr GF16() : raw(ZERO) {}
    constexpr GF16(uint16_t r) : raw(r) {}

    static inline GF16 from_f32(float x) {
        if (std::isnan(x)) return GF16{NAN};
        if (std::isinf(x)) return x > 0 ? GF16{PINF} : GF16{NINF};
        if (x == 0.0f) return std::signbit(x) ? GF16{NEG_ZERO} : GF16{ZERO};

        union { float f; uint32_t u; } bits;
        bits.f = x;
        uint32_t sign = (bits.u >> 31) & 0x1;
        int32_t exp = ((bits.u >> 23) & 0xFF) - 127;
        uint32_t mant = bits.u & 0x7FFFFF;

        int16_t gf_exp = std::clamp(exp + 31, 0, 63);
        uint16_t gf_mant = (mant >> 14) & 0x1FF;

        return GF16{static_cast<uint16_t>((sign << 15) | (gf_exp << 9) | gf_mant)};
    }

    inline float to_f32() const {
        uint32_t sign = (raw >> 15) & 0x1;
        uint32_t exp = (raw >> 9) & 0x3F;
        uint32_t mant = raw & 0x1FF;

        if (exp == 63) {
            if (mant == 0) return sign ? -INFINITY : INFINITY;
            return NAN;
        }
        if (exp == 0 && mant == 0) {
            return sign ? -0.0f : 0.0f;
        }

        int32_t f32_exp = static_cast<int32_t>(exp) - 31 + 127;
        uint32_t f32_mant = mant << 14;

        union { float f; uint32_t u; } result;
        result.u = (sign << 31) | (f32_exp << 23) | f32_mant;
        return result.f;
    }

    inline bool is_nan() const { return ((raw >> 9) & 0x3F) == 63 && (raw & 0x1FF) != 0; }
    inline bool is_inf() const { return ((raw >> 9) & 0x3F) == 63 && (raw & 0x1FF) == 0; }
    inline bool is_zero() const { return (raw & 0x7FFF) == 0; }

    inline GF16 abs() const { return GF16{raw & 0x7FFF}; }
    inline GF16 negate() const { return GF16{raw ^ 0x8000}; };
} // namespace gf16
