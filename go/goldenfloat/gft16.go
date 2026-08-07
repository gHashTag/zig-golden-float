package goldenfloat

/*
#include "gft.h"
*/
import "C"

// Gft16 is a GF-T16 value: the raw 17-bit ternary-exponent pattern in a uint32.
// (#cgo CFLAGS/LDFLAGS are declared once in gf16.go and apply package-wide.)
type Gft16 uint32

// Gft16FromF32 encodes an IEEE float32 into GF-T16 (round-to-nearest, saturate to Inf).
func Gft16FromF32(x float32) Gft16 {
	return Gft16(C.gft16_from_f32(C.float(x)))
}

// ToF32 decodes a GF-T16 value back to float32.
func (g Gft16) ToF32() float32 {
	return float32(C.gft16_to_f32(C.uint32_t(g)))
}

func (a Gft16) Add(b Gft16) Gft16 {
	return Gft16(C.gft16_add(C.uint32_t(a), C.uint32_t(b)))
}

func (a Gft16) Sub(b Gft16) Gft16 {
	return Gft16(C.gft16_sub(C.uint32_t(a), C.uint32_t(b)))
}

func (a Gft16) Mul(b Gft16) Gft16 {
	return Gft16(C.gft16_mul(C.uint32_t(a), C.uint32_t(b)))
}

func (a Gft16) Div(b Gft16) Gft16 {
	return Gft16(C.gft16_div(C.uint32_t(a), C.uint32_t(b)))
}

func (g Gft16) Neg() Gft16 {
	return Gft16(C.gft16_neg(C.uint32_t(g)))
}

func (g Gft16) Abs() Gft16 {
	return Gft16(C.gft16_abs(C.uint32_t(g)))
}

// IsFinite reports whether g is finite (not the reserved Inf/NaN row).
func (g Gft16) IsFinite() bool {
	return C.gft16_is_finite(C.uint32_t(g)) != 0
}
