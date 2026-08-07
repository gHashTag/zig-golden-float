/**
 * GoldenFloat — GF-T8 / GF-T32 C++ wrappers (header-only, thin FFI over the C-ABI).
 *
 * The non-16 ternary-exponent rungs, mirroring Gft16:
 *   - Gft8  : E=3 trits, M=4 bits  (offset in [0,26],  e = offset - 13).  10-bit value in uint16_t.
 *   - Gft32 : E=6 trits, M=25 bits (offset in [0,728], e = offset - 364). 36-bit value in uint64_t.
 *
 *   #include <goldenfloat/gft_rungs.hpp>
 *   auto a = goldenfloat::Gft32::from_f32(3.14159f);
 *   float p = (a * a).to_f32();
 *
 * phi^2 + 1/phi^2 = 3 | TRINITY
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#ifndef GOLDENFLOAT_GFT_RUNGS_HPP
#define GOLDENFLOAT_GFT_RUNGS_HPP

#include <cstdint>
#include <ostream>

#include "gft.h"

namespace goldenfloat {

class Gft8 {
public:
    using value_type = uint16_t;

    Gft8() : _value(0) {}
    explicit Gft8(value_type raw) : _value(raw & 0x3FF) {} // 10-bit payload

    static Gft8 from_f32(float x) { return Gft8(gft8_from_f32(x)); }
    float to_f32() const { return gft8_to_f32(_value); }

    Gft8 operator+(const Gft8& o) const { return Gft8(gft8_add(_value, o._value)); }
    Gft8 operator-(const Gft8& o) const { return Gft8(gft8_sub(_value, o._value)); }
    Gft8 operator*(const Gft8& o) const { return Gft8(gft8_mul(_value, o._value)); }
    Gft8 operator/(const Gft8& o) const { return Gft8(gft8_div(_value, o._value)); }
    Gft8 operator-() const { return Gft8(gft8_neg(_value)); }

    Gft8 abs() const { return Gft8(gft8_abs(_value)); }
    bool is_finite() const { return gft8_is_finite(_value) != 0; }

    value_type raw() const { return _value; }

    friend std::ostream& operator<<(std::ostream& os, const Gft8& g) {
        os << "Gft8(" << g.to_f32() << ")";
        return os;
    }

private:
    value_type _value;
};

class Gft32 {
public:
    using value_type = uint64_t;

    Gft32() : _value(0) {}
    explicit Gft32(value_type raw) : _value(raw & 0xFFFFFFFFFULL) {} // 36-bit payload

    static Gft32 from_f32(float x) { return Gft32(gft32_from_f32(x)); }
    float to_f32() const { return gft32_to_f32(_value); }

    Gft32 operator+(const Gft32& o) const { return Gft32(gft32_add(_value, o._value)); }
    Gft32 operator-(const Gft32& o) const { return Gft32(gft32_sub(_value, o._value)); }
    Gft32 operator*(const Gft32& o) const { return Gft32(gft32_mul(_value, o._value)); }
    Gft32 operator/(const Gft32& o) const { return Gft32(gft32_div(_value, o._value)); }
    Gft32 operator-() const { return Gft32(gft32_neg(_value)); }

    Gft32 abs() const { return Gft32(gft32_abs(_value)); }
    bool is_finite() const { return gft32_is_finite(_value) != 0; }

    value_type raw() const { return _value; }

    friend std::ostream& operator<<(std::ostream& os, const Gft32& g) {
        os << "Gft32(" << g.to_f32() << ")";
        return os;
    }

private:
    value_type _value;
};

} // namespace goldenfloat

#endif // GOLDENFLOAT_GFT_RUNGS_HPP
