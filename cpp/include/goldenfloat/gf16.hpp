/**
 * GoldenFloat GF16 C++ Header-Only Wrapper
 *
 * φ-optimized 16-bit floating point format: [sign:1][exp:6][mant:9]
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 * Repository: https://github.com/gHashTag/zig-golden-float
 *
 * Usage:
 *   #include <goldenfloat/gf16.hpp>
 *
 *   using namespace goldenfloat;
 *
 *   auto a = Gf16::from_f32(3.14f);
 *   auto b = Gf16::from_f32(2.71f);
 *   auto sum = a + b;
 *   std::cout << sum.to_f32() << std::endl;
 */

#ifndef GOLDENFLOAT_GF16_HPP
#define GOLDENFLOAT_GF16_HPP

#include <cstdint>
#include <cmath>
#include <iostream>
#include <stdexcept>

// Include C-ABI header (configured via CMakeLists.txt include_directories())
#include "gf16.h"

namespace goldenfloat {

/**
 * @brief GF16 value wrapper
 *
 * Provides C++ RAII wrapper around the GF16 C-ABI.
 * All operations delegate to the C library for consistency.
 */
class Gf16 {
public:
    using value_type = uint16_t;

    // ========================================================================
    // Constructors
    // ========================================================================

    /**
     * @brief Default constructor (creates zero)
     */
    constexpr Gf16() noexcept : _value(GF16_ZERO) {}

    /**
     * @brief Construct from raw 16-bit value
     */
    explicit constexpr Gf16(value_type value) noexcept : _value(value) {}

    /**
     * @brief Copy constructor
     */
    constexpr Gf16(const Gf16&) noexcept = default;

    /**
     * @brief Move constructor
     */
    constexpr Gf16(Gf16&&) noexcept = default;

    /**
     * @brief Copy assignment
     */
    constexpr Gf16& operator=(const Gf16&) noexcept = default;

    /**
     * @brief Move assignment
     */
    constexpr Gf16& operator=(Gf16&&) noexcept = default;

    /**
     * @brief Destructor
     */
    ~Gf16() = default;

    // ========================================================================
    // Static Factory Methods
    // ========================================================================

    /**
     * @brief Create GF16 from f32
     */
    static Gf16 from_f32(float x) {
        return Gf16(gf16_from_f32(x));
    }

    /**
     * @brief Zero constant
     */
    static constexpr Gf16 zero() noexcept {
        return Gf16(GF16_ZERO);
    }

    /**
     * @brief One constant
     */
    static constexpr Gf16 one() noexcept {
        return Gf16(GF16_ONE);
    }

    /**
     * @brief Positive infinity constant
     */
    static constexpr Gf16 p_inf() noexcept {
        return Gf16(GF16_PINF);
    }

    /**
     * @brief Negative infinity constant
     */
    static constexpr Gf16 n_inf() noexcept {
        return Gf16(GF16_NINF);
    }

    /**
     * @brief NaN constant
     */
    static constexpr Gf16 nan() noexcept {
        return Gf16(GF16_NAN);
    }

    // ========================================================================
    // Conversion
    // ========================================================================

    /**
     * @brief Convert to f32
     */
    float to_f32() const {
        return gf16_to_f32(_value);
    }

    /**
     * @brief Get raw 16-bit value
     */
    constexpr value_type value() const noexcept {
        return _value;
    }

    // ========================================================================
    // Arithmetic Operators
    // ========================================================================

    /**
     * @brief Addition
     */
    Gf16 operator+(const Gf16& other) const {
        return Gf16(gf16_add(_value, other._value));
    }

    /**
     * @brief Subtraction
     */
    Gf16 operator-(const Gf16& other) const {
        return Gf16(gf16_sub(_value, other._value));
    }

    /**
     * @brief Multiplication
     */
    Gf16 operator*(const Gf16& other) const {
        return Gf16(gf16_mul(_value, other._value));
    }

    /**
     * @brief Division
     */
    Gf16 operator/(const Gf16& other) const {
        return Gf16(gf16_div(_value, other._value));
    }

    /**
     * @brief Negation
     */
    Gf16 operator-() const {
        return Gf16(gf16_neg(_value));
    }

    /**
     * @brief Absolute value
     */
    Gf16 abs() const {
        return Gf16(gf16_abs(_value));
    }

    // ========================================================================
    // Comparison Operators
    // ========================================================================

    /**
     * @brief Equality
     */
    bool operator==(const Gf16& other) const {
        return gf16_eq(_value, other._value);
    }

    /**
     * @brief Inequality
     */
    bool operator!=(const Gf16& other) const {
        return !gf16_eq(_value, other._value);
    }

    /**
     * @brief Less than
     */
    bool operator<(const Gf16& other) const {
        return gf16_lt(_value, other._value);
    }

    /**
     * @brief Less than or equal
     */
    bool operator<=(const Gf16& other) const {
        return gf16_le(_value, other._value);
    }

    /**
     * @brief Greater than
     */
    bool operator>(const Gf16& other) const {
        return gf16_lt(other._value, _value);
    }

    /**
     * @brief Greater than or equal
     */
    bool operator>=(const Gf16& other) const {
        return gf16_le(other._value, _value);
    }

    /**
     * @brief Three-way comparison
     */
    int cmp(const Gf16& other) const {
        return gf16_cmp(_value, other._value);
    }

    // ========================================================================
    // Predicates
    // ========================================================================

    /**
     * @brief Check if NaN
     */
    bool is_nan() const {
        return gf16_is_nan(_value);
    }

    /**
     * @brief Check if infinity
     */
    bool is_inf() const {
        return gf16_is_inf(_value);
    }

    /**
     * @brief Check if zero
     */
    bool is_zero() const {
        return gf16_is_zero(_value);
    }

    /**
     * @brief Check if subnormal (always false for GF16)
     */
    bool is_subnormal() const {
        return gf16_is_subnormal(_value);
    }

    /**
     * @brief Check if negative
     */
    bool is_negative() const {
        return gf16_is_negative(_value);
    }

    // ========================================================================
    // φ-Math Functions
    // ========================================================================

    /**
     * @brief φ-optimized quantization
     */
    static Gf16 phi_quantize(float x) {
        return Gf16(gf16_phi_quantize(x));
    }

    /**
     * @brief φ-optimized dequantization
     */
    float phi_dequantize() const {
        return gf16_phi_dequantize(_value);
    }

    /**
     * @brief Golden ratio φ constant
     */
    static constexpr double phi() noexcept {
        return GF16_PHI;
    }

    /**
     * @brief φ² constant
     */
    static constexpr double phi_sq() noexcept {
        return GF16_PHI_SQ;
    }

    /**
     * @brief 1/φ² constant
     */
    static constexpr double phi_inv_sq() noexcept {
        return GF16_PHI_INV_SQ;
    }

    /**
     * @brief Trinity constant (3.0)
     */
    static constexpr double trinity() noexcept {
        return GF16_TRINITY;
    }

    // ========================================================================
    // Utility Functions
    // ========================================================================

    /**
     * @brief Copy sign from source
     */
    Gf16 copysign(const Gf16& source) const {
        return Gf16(gf16_copysign(_value, source._value));
    }

    /**
     * @brief Minimum of two values
     */
    Gf16 min(const Gf16& other) const {
        return Gf16(gf16_min(_value, other._value));
    }

    /**
     * @brief Maximum of two values
     */
    Gf16 max(const Gf16& other) const {
        return Gf16(gf16_max(_value, other._value));
    }

    /**
     * @brief Fused multiply-add: a * b + c
     */
    static Gf16 fma(const Gf16& a, const Gf16& b, const Gf16& c) {
        return Gf16(gf16_fma(a._value, b._value, c._value));
    }

    // ========================================================================
    // I/O Stream Operators
    // ========================================================================

    /**
     * @brief Output stream operator
     */
    friend std::ostream& operator<<(std::ostream& os, const Gf16& g) {
        os << "Gf16(" << g.to_f32() << ")";
        return os;
    }

private:
    value_type _value;
};

// ============================================================================
// Standalone Functions for Convenience
// ============================================================================

/**
 * @brief Create GF16 from f32
 */
inline Gf16 make_gf16(float x) {
    return Gf16::from_f32(x);
}

/**
 * @brief Absolute value function
 */
inline Gf16 abs(const Gf16& g) {
    return g.abs();
}

/**
 * @brief Minimum function
 */
inline Gf16 min(const Gf16& a, const Gf16& b) {
    return a.min(b);
}

/**
 * @brief Maximum function
 */
inline Gf16 max(const Gf16& a, const Gf16& b) {
    return a.max(b);
}

} // namespace goldenfloat

#endif // GOLDENFLOAT_GF16_HPP
