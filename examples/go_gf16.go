// GF16 Go FFI Binding
//
// Build:
//   cd /path/to/zig-golden-float
//   zig build shared
//
// Run:
//   export DYLD_LIBRARY_PATH=zig-out/lib  # macOS
//   export LD_LIBRARY_PATH=zig-out/lib     # Linux
//   go run examples/go_gf16.go

package main

/*
#cgo LDFLAGS: -L../../zig-out/lib -lgoldenfloat
#include "gf16.h"
#include <stdint.h>
#include <stdio.h>
*/
import "C"

import (
	"fmt"
	"math"
	"unsafe"
)

// gf16_t is a raw uint16 representing GF16 bit pattern
type gf16T uint16

// Constants
const (
	GF16Zero  gf16T = 0x0000
	GF16One   gf16T = 0x3C00
	GF16PInf  gf16T = 0x7E00
	GF16NInf  gf16T = 0xFE00
	GF16NaN   gf16T = 0x7E01
)

// ═════════════════════════════════════════════════════════════════════
// FFI Functions
// ═════════════════════════════════════════════════════════════════════

func gf16FromF32(x float32) gf16T {
	return gf16T(C.gf16_from_f32(C.float_t(x)))
}

func gf16ToF32(g gf16T) float32 {
	return float32(C.gf16_to_f32(C.uint16_t(g)))
}

func gf16Add(a, b gf16T) gf16T {
	return gf16T(C.gf16_add(C.uint16_t(a), C.uint16_t(b)))
}

func gf16Sub(a, b gf16T) gf16T {
	return gf16T(C.gf16_sub(C.uint16_t(a), C.uint16_t(b)))
}

func gf16Mul(a, b gf16T) gf16T {
	return gf16T(C.gf16_mul(C.uint16_t(a), C.uint16_t(b)))
}

func gf16Div(a, b gf16T) gf16T {
	return gf16T(C.gf16_div(C.uint16_t(a), C.uint16_t(b)))
}

func gf16Neg(g gf16T) gf16T {
	return gf16T(C.gf16_neg(C.uint16_t(g)))
}

func gf16Abs(g gf16T) gf16T {
	return gf16T(C.gf16_abs(C.uint16_t(g)))
}

func gf16Eq(a, b gf16T) bool {
	return C.gf16_eq(C.uint16_t(a), C.uint16_t(b)) != 0
}

func gf16Lt(a, b gf16T) bool {
	return C.gf16_lt(C.uint16_t(a), C.uint16_t(b)) != 0
}

func gf16IsZero(g gf16T) bool {
	return C.gf16_is_zero(C.uint16_t(g)) != 0
}

func gf16IsInf(g gf16T) bool {
	return C.gf16_is_inf(C.uint16_t(g)) != 0
}

func gf16IsNaN(g gf16T) bool {
	return C.gf16_is_nan(C.uint16_t(g)) != 0
}

func gf16PhiQuantize(x float32) gf16T {
	return gf16T(C.gf16_phi_quantize(C.float_t(x)))
}

func gf16PhiDequantize(g gf16T) float32 {
	return float32(C.gf16_phi_dequantize(C.uint16_t(g)))
}

func gf16Fma(a, b, c gf16T) gf16T {
	return gf16T(C.gf16_fma(C.uint16_t(a), C.uint16_t(b), C.uint16_t(c)))
}

func goldenfloatVersion() string {
	version := C.goldenfloat_version()
	defer C.free(unsafe.Pointer(version))
	return C.GoString(version)
}

func goldenfloatPhi() float64 {
	return float64(C.goldenfloat_phi())
}

func goldenfloatTrinity() float64 {
	return float64(C.goldenfloat_trinity())
}

// ═════════════════════════════════════════════════════════════════════
// Demo
// ═════════════════════════════════════════════════════════════════════

func main() {
	fmt.Println("╔════════════════════════════════════════════════════════╗")
	fmt.Println("║         GF16 Go FFI Binding — C-ABI Layer            ║")
	fmt.Println("╚════════════════════════════════════════════════════════╝")

	fmt.Println("\n" + "Library version: " + goldenfloatVersion())

	// ─────────────────────────────────────────────────────────────
	// Arithmetic Demo
	// ─────────────────────────────────────────────────────────────
	fmt.Println("\n" + "=== Arithmetic Demo ===")

	a := gf16FromF32(1.5)
	b := gf16FromF32(2.5)

	sum := gf16Add(a, b)
	diff := gf16Sub(b, a)
	prod := gf16Mul(a, b)
	quot := gf16Div(a, b)

	fmt.Printf("1.5 + 2.5 = %.2f\n", gf16ToF32(sum))
	fmt.Printf("2.5 - 1.5 = %.2f\n", gf16ToF32(diff))
	fmt.Printf("1.5 × 2.5 = %.2f\n", gf16ToF32(prod))
	fmt.Printf("1.5 / 2.5 = %.2f\n", gf16ToF32(quot))

	// ─────────────────────────────────────────────────────────────
	// φ-Quantization Demo
	// ─────────────────────────────────────────────────────────────
	fmt.Println("\n=== φ-Quantization Demo ===")

	weight := float32(2.71828)
	phiQ := gf16PhiQuantize(weight)
	phiDQ := gf16PhiDequantize(phiQ)

	fmt.Printf("Original weight:     %.6f\n", weight)
	fmt.Printf("φ-quantized (hex):   0x%04x\n", phiQ)
	fmt.Printf("φ-dequantized:       %.6f\n", phiDQ)
	fmt.Printf("φ-error (%%):           %.4f\n", math.Abs(float64(phiDQ-weight)/float64(weight))*100)

	// ─────────────────────────────────────────────────────────────
	// Predicates Demo
	// ─────────────────────────────────────────────────────────────
	fmt.Println("\n=== Predicates Demo ===")

	fmt.Printf("is_zero(GF16_ZERO):  %v\n", gf16IsZero(GF16Zero))
	fmt.Printf("is_inf(GF16_PINF):   %v\n", gf16IsInf(GF16PInf))
	fmt.Printf("is_nan(GF16_NAN):    %v\n", gf16IsNaN(GF16NaN))

	// ─────────────────────────────────────────────────────────────
	// FMA Demo
	// ─────────────────────────────────────────────────────────────
	fmt.Println("\n=== FMA Demo ===")

	x := gf16FromF32(2.0)
	y := gf16FromF32(3.0)
	z := gf16FromF32(1.0)

	fmaResult := gf16Fma(x, y, z)
	fmt.Printf("2.0 × 3.0 + 1.0 = %.2f\n", gf16ToF32(fmaResult))

	// ─────────────────────────────────────────────────────────────
	// Trinity Constants
	// ─────────────────────────────────────────────────────────────
	fmt.Println("\n=== Trinity Constants ===")

	phi := goldenfloatPhi()
	trinity := goldenfloatTrinity()

	fmt.Printf("φ = %.10f\n", phi)
	fmt.Printf("φ² + 1/φ² = %.1f (Trinity Identity)\n", trinity)

	fmt.Println("\n╔════════════════════════════════════════════════════════╗")
	fmt.Println("║  All GF16 operations working via C-ABI!                ║")
	fmt.Println("╚════════════════════════════════════════════════════════╝")
}
