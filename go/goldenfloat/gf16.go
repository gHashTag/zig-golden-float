// Package goldenfloat provides Go bindings for GoldenFloat GF16 format.
//
// MIT License — Copyright (c) 2026 Trinity Project
// Repository: https://github.com/gHashTag/zig-golden-float

package goldenfloat

/*
#cgo LDFLAGS: -L../../zig-out/lib -lgoldenfloat
#cgo CFLAGS: -I../../include
*/
import "C"

// gf16_t is the raw 16-bit GF16 value
type Gf16 uint16

// ============================================================================
// Conversion Functions
// ============================================================================

// FromF32 converts a float32 value to GF16
func FromF32(x float32) Gf16 {
    return Gf16(C.gf16_from_f32(x))
}

// ToF32 converts GF16 to float32
func (g Gf16) ToF32() float32 {
    return C.gf16_to_f32(C.gf16_t(g))
}

// ============================================================================
// Arithmetic Functions
// ============================================================================

// Add adds two GF16 values
func (a Gf16) Add(b Gf16) Gf16 {
    return Gf16(C.gf16_add(C.gf16_t(a), C.gf16_t(b)))
}

// Sub subtracts two GF16 values
func (a Gf16) Sub(b Gf16) Gf16 {
    return Gf16(C.gf16_sub(C.gf16_t(a), C.gf16_t(b)))
}

// Mul multiplies two GF16 values
func (a Gf16) Mul(b Gf16) Gf16 {
    return Gf16(C.gf16_mul(C.gf16_t(a), C.gf16_t(b)))
}

// Div divides two GF16 values
func (a Gf16) Div(b Gf16) Gf16 {
    return Gf16(C.gf16_div(C.gf16_t(a), C.gf16_t(b)))
}

// Neg negates a GF16 value
func (g Gf16) Neg() Gf16 {
    return Gf16(C.gf16_neg(C.gf16_t(g)))
}

// ============================================================================
// Comparison Functions
// ============================================================================

// Eq returns true if two GF16 values are equal
func (a Gf16) Eq(b Gf16) bool {
    return C.gf16_eq(C.gf16_t(a), C.gf16_t(b)) != 0
}

// Lt returns true if a is less than b
func (a Gf16) Lt(b Gf16) bool {
    return C.gf16_lt(C.gf16_t(a), C.gf16_t(b)) != 0
}

// Le returns true if a is less than or equal to b
func (a Gf16) Le(b Gf16) bool {
    return C.gf16_le(C.gf16_t(a), C.gf16_t(b)) != 0
}

// Gt returns true if a is greater than b
func (a Gf16) Gt(b Gf16) bool {
    return C.gf16_lt(C.gf16_t(b), C.gf16_t(a)) != 0
}

// Ge returns true if a is greater than or equal to b
func (a Gf16) Ge(b Gf16) bool {
    return C.gf16_le(C.gf16_t(b), C.gf16_t(a)) != 0
}

// Cmp performs three-way comparison: -1 if a<b, 0 if a==b, 1 if a>b
func (a Gf16) Cmp(b Gf16) int {
    return int(C.gf16_cmp(C.gf16_t(a), C.gf16_t(b)))
}

// ============================================================================
// Predicate Functions
// ============================================================================

// IsNaN returns true if value is NaN
func (g Gf16) IsNaN() bool {
    return C.gf16_is_nan(C.gf16_t(g)) != 0
}

// IsInf returns true if value is infinity
func (g Gf16) IsInf() bool {
    return C.gf16_is_inf(C.gf16_t(g)) != 0
}

// IsZero returns true if value is zero
func (g Gf16) IsZero() bool {
    return C.gf16_is_zero(C.gf16_t(g)) != 0
}

// IsSubnormal returns false (GF16 has no true subnormals)
func (g Gf16) IsSubnormal() bool {
    return C.gf16_is_subnormal(C.gf16_t(g)) != 0
}

// IsNegative returns true if value is negative
func (g Gf16) IsNegative() bool {
    return C.gf16_is_negative(C.gf16_t(g)) != 0
}

// ============================================================================
// phi-Math Functions
// ============================================================================

// PhiQuantize performs φ-optimized quantization
func PhiQuantize(x float32) Gf16 {
    return Gf16(C.gf16_phi_quantize(x))
}

// PhiDequantize performs φ-optimized dequantization
func (g Gf16) PhiDequantize() float32 {
    return C.gf16_phi_dequantize(C.gf16_t(g))
}

// ============================================================================
// Utility Functions
// ============================================================================

// CpySign copies sign from source to target
func (target Gf16) CpySign(source Gf16) Gf16 {
    return Gf16(C.gf16_copysign(C.gf16_t(target), C.gf16_t(source)))
}

// Min returns minimum of two values
func (a Gf16) Min(b Gf16) Gf16 {
    return Gf16(C.gf16_min(C.gf16_t(a), C.gf16_t(b)))
}

// Max returns maximum of two values
func (a Gf16) Max(b Gf16) Gf16 {
    return Gf16(C.gf16_max(C.gf16_t(a), C.gf16_t(b)))
}

// FMA performs fused multiply-add: a*b + c
func (a Gf16) Fma(b, c Gf16) Gf16 {
    return Gf16(C.gf16_fma(C.gf16_t(a), C.gf16_t(b), C.gf16_t(c)))
}

// ============================================================================
// Constants
// ============================================================================

const (
    Zero  Gf16 = 0x0000
    One   Gf16 = 0x3C00
    PInf  Gf16 = 0x7E00
    NInf  Gf16 = 0xFE00
    NaN   Gf16 = 0x7E01
)

// ============================================================================
// Library Info Functions (external declarations)
// ============================================================================

//extern func goldenfloatVersion() *C.char
//extern func goldenfloatPhi() C.double
//extern func goldenfloatPhiSq() C.double
//extern func goldenfloatTrinity() C.double

// Phi returns golden ratio φ
func Phi() float64 {
    // Note: Need to add extern declarations in future if library exports these
    return 1.6180339887498948
}

// PhiSq returns φ²
func PhiSq() float64 {
    return Phi() * Phi()
}

// PhiInvSq returns 1/φ²
func PhiInvSq() float64 {
    return 1.0 / PhiSq()
}

// Trinity returns φ² + 1/φ² = 3
func Trinity() float64 {
    return PhiSq() + PhiInvSq()
}
