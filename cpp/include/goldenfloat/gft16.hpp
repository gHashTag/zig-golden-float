/**
 * GoldenFloat — GF-T16 C++ wrapper (header-only, thin FFI over the C-ABI).
 *
 * GF-T16 is the ternary-exponent GoldenFloat: a balanced-ternary 4-trit exponent
 * (offset in [0,80], e = offset - 40; top row reserved Inf/NaN) with GF16's 9-bit
 * mantissa — ~24 decades, no regime decode. The raw 17-bit value rides in a uint32_t.
 *
 *   #include <goldenfloat/gft16.hpp>
 *   auto a = Gft16::from_f32(3.14159f);
 *   auto b = Gft16::from_f32(2.71828f);
 *   float p = (a * b).to_f32();   // ~8.539
 *
 * phi^2 + 1/phi^2 = 3 | TRINITY
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#ifndef GOLDENFLOAT_GFT16_HPP
#define GOLDENFLOAT_GFT16_HPP

#include <cstdint>
#include <ostream>

#include "gft.h"

namespace goldenfloat {

class Gft16 {
public:
    using value_type = uint32_t;

    Gft16() : _value(0) {}
    explicit Gft16(value_type raw) : _value(raw & 0x1FFFF) {}

    static Gft16 from_f32(float x) { return Gft16(gft16_from_f32(x)); }
    float to_f32() const { return gft16_to_f32(_value); }

    Gft16 operator+(const Gft16& o) const { return Gft16(gft16_add(_value, o._value)); }
    Gft16 operator-(const Gft16& o) const { return Gft16(gft16_sub(_value, o._value)); }
    Gft16 operator*(const Gft16& o) const { return Gft16(gft16_mul(_value, o._value)); }
    Gft16 operator/(const Gft16& o) const { return Gft16(gft16_div(_value, o._value)); }
    Gft16 operator-() const { return Gft16(gft16_neg(_value)); }

    Gft16 abs() const { return Gft16(gft16_abs(_value)); }
    bool is_finite() const { return gft16_is_finite(_value) != 0; }

    value_type raw() const { return _value; }

    friend std::ostream& operator<<(std::ostream& os, const Gft16& g) {
        os << "Gft16(" << g.to_f32() << ")";
        return os;
    }

private:
    value_type _value;
};

} // namespace goldenfloat

#endif // GOLDENFLOAT_GFT16_HPP
