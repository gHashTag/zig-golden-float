package goldenfloat

/*
#cgo LDFLAGS: -L../../zig-out/lib -lgoldenfloat
#cgo CFLAGS: -I../../src/c
#include "gf16.h"

extern double goldenfloat_phi();
extern double goldenfloat_trinity();
extern const char* goldenfloat_version();
*/
import "C"

import "unsafe"

type Gf16 uint16

func FromF32(x float32) Gf16 {
	return Gf16(C.gf16_from_f32(C.float(x)))
}

func (g Gf16) ToF32() float32 {
	return float32(C.gf16_to_f32(C.uint16_t(g)))
}

func (a Gf16) Add(b Gf16) Gf16 {
	return Gf16(C.gf16_add(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gf16) Sub(b Gf16) Gf16 {
	return Gf16(C.gf16_sub(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gf16) Mul(b Gf16) Gf16 {
	return Gf16(C.gf16_mul(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gf16) Div(b Gf16) Gf16 {
	return Gf16(C.gf16_div(C.uint16_t(a), C.uint16_t(b)))
}

func (g Gf16) Neg() Gf16 {
	return Gf16(C.gf16_neg(C.uint16_t(g)))
}

func (a Gf16) Eq(b Gf16) bool {
	return bool(C.gf16_eq(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gf16) Lt(b Gf16) bool {
	return bool(C.gf16_lt(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gf16) Le(b Gf16) bool {
	return bool(C.gf16_le(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gf16) Gt(b Gf16) bool {
	return bool(C.gf16_lt(C.uint16_t(b), C.uint16_t(a)))
}

func (a Gf16) Ge(b Gf16) bool {
	return bool(C.gf16_le(C.uint16_t(b), C.uint16_t(a)))
}

func (a Gf16) Cmp(b Gf16) int {
	return int(C.gf16_cmp(C.uint16_t(a), C.uint16_t(b)))
}

func (g Gf16) IsNaN() bool {
	return bool(C.gf16_is_nan(C.uint16_t(g)))
}

func (g Gf16) IsInf() bool {
	return bool(C.gf16_is_inf(C.uint16_t(g)))
}

func (g Gf16) IsZero() bool {
	return bool(C.gf16_is_zero(C.uint16_t(g)))
}

func (g Gf16) IsNegative() bool {
	return bool(C.gf16_is_negative(C.uint16_t(g)))
}

func PhiQuantize(x float32) Gf16 {
	return Gf16(C.gf16_phi_quantize(C.float(x)))
}

func (g Gf16) PhiDequantize() float32 {
	return float32(C.gf16_phi_dequantize(C.uint16_t(g)))
}

func (target Gf16) CpySign(source Gf16) Gf16 {
	return Gf16(C.gf16_copysign(C.uint16_t(target), C.uint16_t(source)))
}

func (a Gf16) Min(b Gf16) Gf16 {
	return Gf16(C.gf16_min(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gf16) Max(b Gf16) Gf16 {
	return Gf16(C.gf16_max(C.uint16_t(a), C.uint16_t(b)))
}

func (a Gf16) Fma(b, c Gf16) Gf16 {
	return Gf16(C.gf16_fma(C.uint16_t(a), C.uint16_t(b), C.uint16_t(c)))
}

const (
	Zero  Gf16 = 0x0000
	One   Gf16 = 0x3C00
	PInf  Gf16 = 0x7E00
	NInf  Gf16 = 0xFE00
	NaN   Gf16 = 0x7E01
)

func Phi() float64 {
	return float64(C.goldenfloat_phi())
}

func PhiSq() float64 {
	return Phi() * Phi()
}

func PhiInvSq() float64 {
	return 1.0 / PhiSq()
}

func Trinity() float64 {
	return float64(C.goldenfloat_trinity())
}

func Version() string {
	cs := C.goldenfloat_version()
	return C.GoString((*C.char)(unsafe.Pointer(cs)))
}
