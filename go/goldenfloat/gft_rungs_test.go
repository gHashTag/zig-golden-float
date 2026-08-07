package goldenfloat

import (
	"math"
	"testing"
)

func TestGft8(t *testing.T) {
	// 4-bit mantissa -> ~3%; keep values inside GF-T8's [2^-13, 2^12] range.
	for _, v := range []float32{1.0, -1.0, 0.5, 2.0, 3.0, -3.0, 100.0, 0.05} {
		q := Gft8FromF32(v).ToF32()
		if absF32(q-v)/(absF32(v)+1e-9) > 0.04 {
			t.Errorf("GF-T8 roundtrip %v -> %v", v, q)
		}
	}
	a := Gft8FromF32(1.5)
	b := Gft8FromF32(2.5)
	if !approxEqual(a.Add(b).ToF32(), 4.0, 0.05) {
		t.Errorf("add: %v", a.Add(b).ToF32())
	}
	if !approxEqual(b.Sub(a).ToF32(), 1.0, 0.05) {
		t.Errorf("sub: %v", b.Sub(a).ToF32())
	}
	if !approxEqual(a.Mul(b).ToF32(), 3.75, 0.05) {
		t.Errorf("mul: %v", a.Mul(b).ToF32())
	}
	if !approxEqual(b.Div(a).ToF32(), 2.5/1.5, 0.06) {
		t.Errorf("div: %v", b.Div(a).ToF32())
	}
	if !approxEqual(a.Neg().ToF32(), -1.5, 0.05) {
		t.Errorf("neg: %v", a.Neg().ToF32())
	}
	if !approxEqual(a.Neg().Abs().ToF32(), 1.5, 0.05) {
		t.Errorf("abs: %v", a.Neg().Abs().ToF32())
	}
	if !Gft8FromF32(1.0).IsFinite() {
		t.Errorf("1.0 should be finite")
	}
	if Gft8FromF32(1e30).IsFinite() {
		t.Errorf("1e30 should overflow to Inf")
	}
}

func TestGft32(t *testing.T) {
	// 25-bit mantissa -> near-exact; 219 decades.
	for _, v := range []float32{1.0, -1.0, 0.5, 2.0, 3.14159, -3.14159, 100.0, 0.001, 12345.0, 1e30} {
		q := Gft32FromF32(v).ToF32()
		if absF32(q-v)/(absF32(v)+1e-9) > 0.005 {
			t.Errorf("GF-T32 roundtrip %v -> %v", v, q)
		}
	}
	a := Gft32FromF32(1.5)
	b := Gft32FromF32(2.5)
	if !approxEqual(a.Add(b).ToF32(), 4.0, 0.001) {
		t.Errorf("add: %v", a.Add(b).ToF32())
	}
	if !approxEqual(b.Sub(a).ToF32(), 1.0, 0.001) {
		t.Errorf("sub: %v", b.Sub(a).ToF32())
	}
	if !approxEqual(a.Mul(b).ToF32(), 3.75, 0.001) {
		t.Errorf("mul: %v", a.Mul(b).ToF32())
	}
	if !approxEqual(b.Div(a).ToF32(), 2.5/1.5, 0.001) {
		t.Errorf("div: %v", b.Div(a).ToF32())
	}
	if !approxEqual(a.Neg().ToF32(), -1.5, 0.001) {
		t.Errorf("neg: %v", a.Neg().ToF32())
	}
	if !approxEqual(a.Neg().Abs().ToF32(), 1.5, 0.001) {
		t.Errorf("abs: %v", a.Neg().Abs().ToF32())
	}
	// Every finite f32 is finite in GF-T32; only inf overflows.
	if !Gft32FromF32(1e30).IsFinite() {
		t.Errorf("1e30 should be finite in GF-T32")
	}
	if Gft32FromF32(float32(math.Inf(1))).IsFinite() {
		t.Errorf("inf should not be finite")
	}
}
