"""
Gft8 — Python wrapper for GF-T8 (ternary-exponent GoldenFloat, small rung).

GF-T8 stores the exponent as a balanced-ternary number (3 trits, offset in [0,26],
e = offset - 13; top row reserved for Inf/NaN) with a 4-bit mantissa. The raw 10-bit
value is carried in an int. Subset ABI: from/to float, add, mul, is_finite.

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
"""

from ._binding import (
    gft8_from_f32,
    gft8_to_f32,
    gft8_add,
    gft8_sub,
    gft8_mul,
    gft8_div,
    gft8_neg,
    gft8_abs,
    gft8_is_finite,
)


class Gft8:
    """A GF-T8 value. Construct from float, operate with + and *, read back with .to_f32()."""

    __slots__ = ("raw",)

    def __init__(self, raw: int = 0):
        self.raw = raw & 0x3FF  # 10-bit payload

    @classmethod
    def from_f32(cls, x: float) -> "Gft8":
        return cls(gft8_from_f32(float(x)))

    def to_f32(self) -> float:
        return gft8_to_f32(self.raw)

    def __add__(self, other: "Gft8") -> "Gft8":
        return Gft8(gft8_add(self.raw, other.raw))

    def __sub__(self, other: "Gft8") -> "Gft8":
        return Gft8(gft8_sub(self.raw, other.raw))

    def __mul__(self, other: "Gft8") -> "Gft8":
        return Gft8(gft8_mul(self.raw, other.raw))

    def __truediv__(self, other: "Gft8") -> "Gft8":
        return Gft8(gft8_div(self.raw, other.raw))

    def __neg__(self) -> "Gft8":
        return Gft8(gft8_neg(self.raw))

    def __abs__(self) -> "Gft8":
        return Gft8(gft8_abs(self.raw))

    def is_finite(self) -> bool:
        return gft8_is_finite(self.raw)

    def __repr__(self) -> str:
        return f"Gft8({self.to_f32():.4g})"

    def __float__(self) -> float:
        return self.to_f32()
