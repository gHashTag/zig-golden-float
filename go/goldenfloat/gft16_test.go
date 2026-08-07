package goldenfloat

import "testing"

func absF32(x float32) float32 {
	if x < 0 {
		return -x
	}
	return x
}

func TestGft16Roundtrip(t *testing.T) {
	vals := []float32{1.0, -1.0, 0.5, 2.0, 3.14159, -3.14159, 100.0, 0.001, 12345.0}
	for _, v := range vals {
		q := Gft16FromF32(v).ToF32()
		if absF32(q-v)/(absF32(v)+1e-9) > 0.005 {
			t.Errorf("GF-T16 roundtrip %v -> %v (>0.5%%)", v, q)
		}
	}
}

func TestGft16Arithmetic(t *testing.T) {
	a := Gft16FromF32(1.5)
	b := Gft16FromF32(2.5)
	if !approxEqual(a.Add(b).ToF32(), 4.0, 0.02) {
		t.Errorf("add: %v", a.Add(b).ToF32())
	}
	if !approxEqual(b.Sub(a).ToF32(), 1.0, 0.02) {
		t.Errorf("sub: %v", b.Sub(a).ToF32())
	}
	if !approxEqual(a.Mul(b).ToF32(), 3.75, 0.02) {
		t.Errorf("mul: %v", a.Mul(b).ToF32())
	}
	if !approxEqual(a.Div(b).ToF32(), 0.6, 0.02) {
		t.Errorf("div: %v", a.Div(b).ToF32())
	}
}

func TestGft16NegAbsFinite(t *testing.T) {
	x := Gft16FromF32(3.5)
	if !approxEqual(x.Neg().ToF32(), -3.5, 0.02) {
		t.Errorf("neg: %v", x.Neg().ToF32())
	}
	if !approxEqual(x.Neg().Abs().ToF32(), 3.5, 0.02) {
		t.Errorf("abs: %v", x.Neg().Abs().ToF32())
	}
	if !Gft16FromF32(1.0).IsFinite() {
		t.Errorf("1.0 should be finite")
	}
	if Gft16FromF32(1e30).IsFinite() {
		t.Errorf("1e30 should overflow to Inf")
	}
}
