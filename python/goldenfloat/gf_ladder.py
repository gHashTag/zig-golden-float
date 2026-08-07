"""
Binary GF ladder — Python wrappers for the φ²-sized rungs (Gf8/Gf12/Gf20/Gf24/Gf32).

Each rung sizes its exponent by e = round((N-1)/φ²), tracking 1/φ at every width:

    Rung   Layout       bias   ~normal range
    Gf8    [1:3:4]      3      ~[0.25, 15.5]
    Gf12   [1:4:7]      7      ~[0.016, 256]
    Gf20   [1:7:12]     63     wide
    Gf24   [1:9:14]     255    very wide
    Gf32   [1:12:19]    2047   very wide

Gf16 [1:6:9] b31 is the rich API (see gf16.py). Gf4 is omitted — a 1-bit exponent leaves
no normal values. The raw N-bit value is carried in an int. Full ops: + - * /, unary -,
abs, is_finite. Semantics: round-to-nearest, saturate to Inf, flush subnormals to zero.

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
"""

from ._binding import _get_lib


def _make_rung(clsname: str, prefix: str, payload_bits: int):
    mask = (1 << payload_bits) - 1

    class _Rung:
        __slots__ = ("raw",)
        PREFIX = prefix
        PAYLOAD_BITS = payload_bits

        def __init__(self, raw: int = 0):
            self.raw = raw & mask

        @classmethod
        def from_f32(cls, x: float) -> "_Rung":
            return cls(getattr(_get_lib(), prefix + "_from_f32")(float(x)))

        def to_f32(self) -> float:
            return getattr(_get_lib(), prefix + "_to_f32")(self.raw)

        def __add__(self, other: "_Rung") -> "_Rung":
            return type(self)(getattr(_get_lib(), prefix + "_add")(self.raw, other.raw))

        def __sub__(self, other: "_Rung") -> "_Rung":
            return type(self)(getattr(_get_lib(), prefix + "_sub")(self.raw, other.raw))

        def __mul__(self, other: "_Rung") -> "_Rung":
            return type(self)(getattr(_get_lib(), prefix + "_mul")(self.raw, other.raw))

        def __truediv__(self, other: "_Rung") -> "_Rung":
            return type(self)(getattr(_get_lib(), prefix + "_div")(self.raw, other.raw))

        def __neg__(self) -> "_Rung":
            return type(self)(getattr(_get_lib(), prefix + "_neg")(self.raw))

        def __abs__(self) -> "_Rung":
            return type(self)(getattr(_get_lib(), prefix + "_abs")(self.raw))

        def is_finite(self) -> bool:
            return bool(getattr(_get_lib(), prefix + "_is_finite")(self.raw))

        def __repr__(self) -> str:
            return f"{clsname}({self.to_f32():.6g})"

        def __float__(self) -> float:
            return self.to_f32()

    _Rung.__name__ = clsname
    _Rung.__qualname__ = clsname
    return _Rung


Gf8 = _make_rung("Gf8", "gf8", 8)
Gf12 = _make_rung("Gf12", "gf12", 12)
Gf20 = _make_rung("Gf20", "gf20", 20)
Gf24 = _make_rung("Gf24", "gf24", 24)
Gf32 = _make_rung("Gf32", "gf32", 32)
