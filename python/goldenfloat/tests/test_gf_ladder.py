"""Binary GF ladder Python binding smoke tests (Gf8/Gf12/Gf20/Gf24/Gf32)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from goldenfloat import Gf8, Gf12, Gf20, Gf24, Gf32

# (class, roundtrip tol, arithmetic tol) — tol scales with mantissa width.
RUNGS = [
    (Gf8, 0.05, 0.05),
    (Gf12, 0.01, 0.01),
    (Gf20, 0.001, 0.001),
    (Gf24, 0.0005, 0.0005),
    (Gf32, 0.0002, 0.0002),
]

# Values inside every rung's normal range (Gf8 is the tightest: ~[0.25, 15.5]).
VALUES = [0.5, 1.0, 1.5, 2.0, 3.0, -2.5, 4.0]


def test_roundtrip():
    for cls, rt_tol, _ in RUNGS:
        for v in VALUES:
            q = cls.from_f32(v).to_f32()
            assert abs(q - v) / (abs(v) + 1e-9) < rt_tol, (cls.__name__, v, q)


def test_arithmetic():
    for cls, _, tol in RUNGS:
        a = cls.from_f32(1.5)
        b = cls.from_f32(2.5)
        assert abs((a + b).to_f32() - 4.0) < tol, cls.__name__
        assert abs((b - a).to_f32() - 1.0) < tol, cls.__name__
        assert abs((a * b).to_f32() - 3.75) < tol, cls.__name__
        assert abs((b / a).to_f32() - (2.5 / 1.5)) < tol, cls.__name__
        assert abs((-a).to_f32() + 1.5) < tol, cls.__name__
        assert abs(abs(-a).to_f32() - 1.5) < tol, cls.__name__


def test_finiteness():
    for cls, _, _ in RUNGS:
        assert cls.from_f32(1.0).is_finite(), cls.__name__
        # inf overflows to the reserved Inf row on every rung.
        assert not cls.from_f32(float("inf")).is_finite(), cls.__name__


if __name__ == "__main__":
    test_roundtrip()
    test_arithmetic()
    test_finiteness()
    print("Binary GF ladder python bindings: ALL PASS")
