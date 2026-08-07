package goldenfloat

/*
#include "gf_ladder.h"
*/
import "C"

// Binary GF ladder — the φ²-sized rungs (mirroring Gf16), full op set each.
// Gf16 [1:6:9] b31 is the rich API (gf16.go); Gf4 is omitted (degenerate).
// (#cgo CFLAGS/LDFLAGS are declared once in gf16.go and apply package-wide.)

// Gf8 is a binary GF8 value [1:3:4] b3 — ~[0.25, 15.5]. 8-bit value in a uint8.
type Gf8 uint8

func Gf8FromF32(x float32) Gf8   { return Gf8(C.gf8_from_f32(C.float(x))) }
func (g Gf8) ToF32() float32     { return float32(C.gf8_to_f32(C.uint8_t(g))) }
func (a Gf8) Add(b Gf8) Gf8      { return Gf8(C.gf8_add(C.uint8_t(a), C.uint8_t(b))) }
func (a Gf8) Sub(b Gf8) Gf8      { return Gf8(C.gf8_sub(C.uint8_t(a), C.uint8_t(b))) }
func (a Gf8) Mul(b Gf8) Gf8      { return Gf8(C.gf8_mul(C.uint8_t(a), C.uint8_t(b))) }
func (a Gf8) Div(b Gf8) Gf8      { return Gf8(C.gf8_div(C.uint8_t(a), C.uint8_t(b))) }
func (g Gf8) Neg() Gf8           { return Gf8(C.gf8_neg(C.uint8_t(g))) }
func (g Gf8) Abs() Gf8           { return Gf8(C.gf8_abs(C.uint8_t(g))) }
func (g Gf8) IsFinite() bool     { return C.gf8_is_finite(C.uint8_t(g)) != 0 }

// Gf12 is a binary GF12 value [1:4:7] b7 — ~[0.016, 256]. 12-bit value in a uint16.
type Gf12 uint16

func Gf12FromF32(x float32) Gf12 { return Gf12(C.gf12_from_f32(C.float(x))) }
func (g Gf12) ToF32() float32    { return float32(C.gf12_to_f32(C.uint16_t(g))) }
func (a Gf12) Add(b Gf12) Gf12   { return Gf12(C.gf12_add(C.uint16_t(a), C.uint16_t(b))) }
func (a Gf12) Sub(b Gf12) Gf12   { return Gf12(C.gf12_sub(C.uint16_t(a), C.uint16_t(b))) }
func (a Gf12) Mul(b Gf12) Gf12   { return Gf12(C.gf12_mul(C.uint16_t(a), C.uint16_t(b))) }
func (a Gf12) Div(b Gf12) Gf12   { return Gf12(C.gf12_div(C.uint16_t(a), C.uint16_t(b))) }
func (g Gf12) Neg() Gf12         { return Gf12(C.gf12_neg(C.uint16_t(g))) }
func (g Gf12) Abs() Gf12         { return Gf12(C.gf12_abs(C.uint16_t(g))) }
func (g Gf12) IsFinite() bool    { return C.gf12_is_finite(C.uint16_t(g)) != 0 }

// Gf20 is a binary GF20 value [1:7:12] b63. 20-bit value in a uint32.
type Gf20 uint32

func Gf20FromF32(x float32) Gf20 { return Gf20(C.gf20_from_f32(C.float(x))) }
func (g Gf20) ToF32() float32    { return float32(C.gf20_to_f32(C.uint32_t(g))) }
func (a Gf20) Add(b Gf20) Gf20   { return Gf20(C.gf20_add(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf20) Sub(b Gf20) Gf20   { return Gf20(C.gf20_sub(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf20) Mul(b Gf20) Gf20   { return Gf20(C.gf20_mul(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf20) Div(b Gf20) Gf20   { return Gf20(C.gf20_div(C.uint32_t(a), C.uint32_t(b))) }
func (g Gf20) Neg() Gf20         { return Gf20(C.gf20_neg(C.uint32_t(g))) }
func (g Gf20) Abs() Gf20         { return Gf20(C.gf20_abs(C.uint32_t(g))) }
func (g Gf20) IsFinite() bool    { return C.gf20_is_finite(C.uint32_t(g)) != 0 }

// Gf24 is a binary GF24 value [1:9:14] b255. 24-bit value in a uint32.
type Gf24 uint32

func Gf24FromF32(x float32) Gf24 { return Gf24(C.gf24_from_f32(C.float(x))) }
func (g Gf24) ToF32() float32    { return float32(C.gf24_to_f32(C.uint32_t(g))) }
func (a Gf24) Add(b Gf24) Gf24   { return Gf24(C.gf24_add(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf24) Sub(b Gf24) Gf24   { return Gf24(C.gf24_sub(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf24) Mul(b Gf24) Gf24   { return Gf24(C.gf24_mul(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf24) Div(b Gf24) Gf24   { return Gf24(C.gf24_div(C.uint32_t(a), C.uint32_t(b))) }
func (g Gf24) Neg() Gf24         { return Gf24(C.gf24_neg(C.uint32_t(g))) }
func (g Gf24) Abs() Gf24         { return Gf24(C.gf24_abs(C.uint32_t(g))) }
func (g Gf24) IsFinite() bool    { return C.gf24_is_finite(C.uint32_t(g)) != 0 }

// Gf32 is a binary GF32 value [1:12:19] b2047. 32-bit value in a uint32.
type Gf32 uint32

func Gf32FromF32(x float32) Gf32 { return Gf32(C.gf32_from_f32(C.float(x))) }
func (g Gf32) ToF32() float32    { return float32(C.gf32_to_f32(C.uint32_t(g))) }
func (a Gf32) Add(b Gf32) Gf32   { return Gf32(C.gf32_add(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf32) Sub(b Gf32) Gf32   { return Gf32(C.gf32_sub(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf32) Mul(b Gf32) Gf32   { return Gf32(C.gf32_mul(C.uint32_t(a), C.uint32_t(b))) }
func (a Gf32) Div(b Gf32) Gf32   { return Gf32(C.gf32_div(C.uint32_t(a), C.uint32_t(b))) }
func (g Gf32) Neg() Gf32         { return Gf32(C.gf32_neg(C.uint32_t(g))) }
func (g Gf32) Abs() Gf32         { return Gf32(C.gf32_abs(C.uint32_t(g))) }
func (g Gf32) IsFinite() bool    { return C.gf32_is_finite(C.uint32_t(g)) != 0 }
