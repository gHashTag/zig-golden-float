package goldenfloat

import (
	"math"
	"testing"
)

// checkRung drives one binary-GF rung through the shared closures. Values stay inside
// Gf8's tight ~[0.25, 15.5] range; the non-finite path is exercised via inf.
func checkRung(
	t *testing.T, name string, rtTol, opTol float32,
	rt func(float32) float32,
	add, sub, mul, div func(float32, float32) float32,
	neg, abs func(float32) float32,
	fin func(float32) bool,
) {
	for _, v := range []float32{0.5, 1.0, 1.5, 2.0, 3.0, -2.5, 4.0} {
		if absF32(rt(v)-v)/(absF32(v)+1e-9) > rtTol {
			t.Errorf("%s roundtrip %v -> %v", name, v, rt(v))
		}
	}
	if !approxEqual(add(1.5, 2.5), 4.0, opTol) {
		t.Errorf("%s add: %v", name, add(1.5, 2.5))
	}
	if !approxEqual(sub(2.5, 1.5), 1.0, opTol) {
		t.Errorf("%s sub: %v", name, sub(2.5, 1.5))
	}
	if !approxEqual(mul(1.5, 2.5), 3.75, opTol) {
		t.Errorf("%s mul: %v", name, mul(1.5, 2.5))
	}
	if !approxEqual(div(2.5, 1.5), 2.5/1.5, opTol) {
		t.Errorf("%s div: %v", name, div(2.5, 1.5))
	}
	if !approxEqual(neg(1.5), -1.5, opTol) {
		t.Errorf("%s neg: %v", name, neg(1.5))
	}
	if !approxEqual(abs(1.5), 1.5, opTol) {
		t.Errorf("%s abs: %v", name, abs(1.5))
	}
	if !fin(1.0) {
		t.Errorf("%s 1.0 should be finite", name)
	}
	if fin(float32(math.Inf(1))) {
		t.Errorf("%s inf should not be finite", name)
	}
}

func TestGf8Ladder(t *testing.T) {
	checkRung(t, "Gf8", 0.05, 0.05,
		func(v float32) float32 { return Gf8FromF32(v).ToF32() },
		func(a, b float32) float32 { return Gf8FromF32(a).Add(Gf8FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf8FromF32(a).Sub(Gf8FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf8FromF32(a).Mul(Gf8FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf8FromF32(a).Div(Gf8FromF32(b)).ToF32() },
		func(v float32) float32 { return Gf8FromF32(v).Neg().ToF32() },
		func(v float32) float32 { return Gf8FromF32(v).Neg().Abs().ToF32() },
		func(v float32) bool { return Gf8FromF32(v).IsFinite() })
}

func TestGf12Ladder(t *testing.T) {
	checkRung(t, "Gf12", 0.01, 0.01,
		func(v float32) float32 { return Gf12FromF32(v).ToF32() },
		func(a, b float32) float32 { return Gf12FromF32(a).Add(Gf12FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf12FromF32(a).Sub(Gf12FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf12FromF32(a).Mul(Gf12FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf12FromF32(a).Div(Gf12FromF32(b)).ToF32() },
		func(v float32) float32 { return Gf12FromF32(v).Neg().ToF32() },
		func(v float32) float32 { return Gf12FromF32(v).Neg().Abs().ToF32() },
		func(v float32) bool { return Gf12FromF32(v).IsFinite() })
}

func TestGf20Ladder(t *testing.T) {
	checkRung(t, "Gf20", 0.001, 0.001,
		func(v float32) float32 { return Gf20FromF32(v).ToF32() },
		func(a, b float32) float32 { return Gf20FromF32(a).Add(Gf20FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf20FromF32(a).Sub(Gf20FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf20FromF32(a).Mul(Gf20FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf20FromF32(a).Div(Gf20FromF32(b)).ToF32() },
		func(v float32) float32 { return Gf20FromF32(v).Neg().ToF32() },
		func(v float32) float32 { return Gf20FromF32(v).Neg().Abs().ToF32() },
		func(v float32) bool { return Gf20FromF32(v).IsFinite() })
}

func TestGf24Ladder(t *testing.T) {
	checkRung(t, "Gf24", 0.0005, 0.0005,
		func(v float32) float32 { return Gf24FromF32(v).ToF32() },
		func(a, b float32) float32 { return Gf24FromF32(a).Add(Gf24FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf24FromF32(a).Sub(Gf24FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf24FromF32(a).Mul(Gf24FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf24FromF32(a).Div(Gf24FromF32(b)).ToF32() },
		func(v float32) float32 { return Gf24FromF32(v).Neg().ToF32() },
		func(v float32) float32 { return Gf24FromF32(v).Neg().Abs().ToF32() },
		func(v float32) bool { return Gf24FromF32(v).IsFinite() })
}

func TestGf32Ladder(t *testing.T) {
	checkRung(t, "Gf32", 0.0002, 0.0002,
		func(v float32) float32 { return Gf32FromF32(v).ToF32() },
		func(a, b float32) float32 { return Gf32FromF32(a).Add(Gf32FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf32FromF32(a).Sub(Gf32FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf32FromF32(a).Mul(Gf32FromF32(b)).ToF32() },
		func(a, b float32) float32 { return Gf32FromF32(a).Div(Gf32FromF32(b)).ToF32() },
		func(v float32) float32 { return Gf32FromF32(v).Neg().ToF32() },
		func(v float32) float32 { return Gf32FromF32(v).Neg().Abs().ToF32() },
		func(v float32) bool { return Gf32FromF32(v).IsFinite() })
}
