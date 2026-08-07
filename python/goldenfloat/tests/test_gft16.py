"""GF-T16 Python binding smoke tests."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from goldenfloat import Gft16


def test_roundtrip():
    for v in [1.0, -1.0, 0.5, 2.0, 3.14159, -3.14159, 100.0, 0.001, 12345.0]:
        q = Gft16.from_f32(v).to_f32()
        assert abs(q - v) / (abs(v) + 1e-9) < 0.005, (v, q)


def test_arithmetic():
    a = Gft16.from_f32(1.5)
    b = Gft16.from_f32(2.5)
    assert abs((a + b).to_f32() - 4.0) < 0.02
    assert abs((b - a).to_f32() - 1.0) < 0.02
    assert abs((a * b).to_f32() - 3.75) < 0.02
    assert abs((a / b).to_f32() - 0.6) < 0.02


def test_neg_abs_finite():
    x = Gft16.from_f32(3.5)
    assert abs((-x).to_f32() + 3.5) < 0.02
    assert abs(abs(-x).to_f32() - 3.5) < 0.02
    assert Gft16.from_f32(1.0).is_finite()
    assert not Gft16.from_f32(1e30).is_finite()  # overflow -> Inf


if __name__ == "__main__":
    test_roundtrip()
    test_arithmetic()
    test_neg_abs_finite()
    print("GF-T16 python binding: ALL PASS")
