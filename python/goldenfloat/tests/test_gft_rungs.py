"""GF-T8 / GF-T32 Python binding smoke tests (the non-16 ternary rungs)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from goldenfloat import Gft8, Gft32


def test_gft8_roundtrip():
    # 4-bit mantissa -> ~3% worst case; keep values inside GF-T8's [2^-13, 2^12] range.
    for v in [1.0, -1.0, 0.5, 2.0, 3.0, -3.0, 100.0, 0.05]:
        q = Gft8.from_f32(v).to_f32()
        assert abs(q - v) / (abs(v) + 1e-9) < 0.04, (v, q)


def test_gft8_arithmetic_finite():
    a = Gft8.from_f32(1.5)
    b = Gft8.from_f32(2.5)
    assert abs((a + b).to_f32() - 4.0) < 0.05
    assert abs((b - a).to_f32() - 1.0) < 0.05
    assert abs((a * b).to_f32() - 3.75) < 0.05
    assert abs((b / a).to_f32() - (2.5 / 1.5)) < 0.06  # 4-bit mantissa
    assert abs((-a).to_f32() + 1.5) < 0.05
    assert abs(abs(-a).to_f32() - 1.5) < 0.05
    assert Gft8.from_f32(1.0).is_finite()
    assert not Gft8.from_f32(1e30).is_finite()  # out of range -> Inf


def test_gft32_roundtrip():
    # 25-bit mantissa -> near-exact; ~219 decades of range.
    for v in [1.0, -1.0, 0.5, 2.0, 3.14159, -3.14159, 100.0, 0.001, 12345.0, 1e30]:
        q = Gft32.from_f32(v).to_f32()
        assert abs(q - v) / (abs(v) + 1e-9) < 0.005, (v, q)


def test_gft32_arithmetic_finite():
    a = Gft32.from_f32(1.5)
    b = Gft32.from_f32(2.5)
    assert abs((a + b).to_f32() - 4.0) < 0.001
    assert abs((b - a).to_f32() - 1.0) < 0.001
    assert abs((a * b).to_f32() - 3.75) < 0.001
    assert abs((b / a).to_f32() - (2.5 / 1.5)) < 0.001
    assert abs((-a).to_f32() + 1.5) < 0.001
    assert abs(abs(-a).to_f32() - 1.5) < 0.001
    # Every finite f32 is finite in GF-T32 (219 decades); only inf overflows.
    assert Gft32.from_f32(1e30).is_finite()
    assert not Gft32.from_f32(float("inf")).is_finite()


if __name__ == "__main__":
    test_gft8_roundtrip()
    test_gft8_arithmetic_finite()
    test_gft32_roundtrip()
    test_gft32_arithmetic_finite()
    print("GF-T8/GF-T32 python bindings: ALL PASS")
