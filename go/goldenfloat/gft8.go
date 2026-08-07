package goldenfloat

/*
#include "gft.h"
*/
import "C"

// Gft8 is a GF-T8 value: the raw 10-bit ternary-exponent pattern (E=3 trits, M=4 bits)
// in a uint16. (#cgo CFLAGS/LDFLAGS are declared once in gf16.go and apply package-wide.)
type Gft8 uint16

// Gft8FromF32 encodes an IEEE float32 into GF-T8 (round-to-nearest, saturate to Inf).
func Gft8FromF32(x float32) Gft8 {
	return Gft8(C.gft8_from_f32(C.float(x)))
}

// ToF32 decodes a GF-T8 value back to float32.
func (g Gft8) ToF32() float32 {
	return float32(C.gft8_to_f32(C.uint16_t(g)))
}

func (a Gft8) Add(b Gft8) Gft8 {
	return Gft8(C.gft8_add(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gft8) Sub(b Gft8) Gft8 {
	return Gft8(C.gft8_sub(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gft8) Mul(b Gft8) Gft8 {
	return Gft8(C.gft8_mul(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gft8) Div(b Gft8) Gft8 {
	return Gft8(C.gft8_div(C.uint16_t(a), C.uint16_t(b)))
}

func (g Gft8) Neg() Gft8 {
	return Gft8(C.gft8_neg(C.uint16_t(g)))
}

func (g Gft8) Abs() Gft8 {
	return Gft8(C.gft8_abs(C.uint16_t(g)))
}

// IsFinite reports whether g is finite (not the reserved Inf/NaN row).
func (g Gft8) IsFinite() bool {
	return C.gft8_is_finite(C.uint16_t(g)) != 0
}
