package goldenfloat

/*
#include "gft.h"
*/
import "C"

// Gft32 is a GF-T32 value: the raw 36-bit ternary-exponent pattern (E=6 trits, M=25 bits)
// in a uint64 — ~219 decades of range. (#cgo flags come from gf16.go, package-wide.)
type Gft32 uint64

// Gft32FromF32 encodes an IEEE float32 into GF-T32 (round-to-nearest, saturate to Inf).
func Gft32FromF32(x float32) Gft32 {
	return Gft32(C.gft32_from_f32(C.float(x)))
}

// ToF32 decodes a GF-T32 value back to float32.
func (g Gft32) ToF32() float32 {
	return float32(C.gft32_to_f32(C.uint64_t(g)))
}

func (a Gft32) Add(b Gft32) Gft32 {
	return Gft32(C.gft32_add(C.uint64_t(a), C.uint64_t(b)))
}

func (a Gft32) Sub(b Gft32) Gft32 {
	return Gft32(C.gft32_sub(C.uint64_t(a), C.uint64_t(b)))
}

func (a Gft32) Mul(b Gft32) Gft32 {
	return Gft32(C.gft32_mul(C.uint64_t(a), C.uint64_t(b)))
}

func (a Gft32) Div(b Gft32) Gft32 {
	return Gft32(C.gft32_div(C.uint64_t(a), C.uint64_t(b)))
}

func (g Gft32) Neg() Gft32 {
	return Gft32(C.gft32_neg(C.uint64_t(g)))
}

func (g Gft32) Abs() Gft32 {
	return Gft32(C.gft32_abs(C.uint64_t(g)))
}

// IsFinite reports whether g is finite (not the reserved Inf/NaN row).
func (g Gft32) IsFinite() bool {
	return C.gft32_is_finite(C.uint64_t(g)) != 0
}
