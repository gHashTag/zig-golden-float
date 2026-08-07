"""
Gft16 — Python wrapper for GF-T16 (ternary-exponent GoldenFloat).

GF-T16 stores the exponent as a balanced-ternary number (4 trits, offset in [0,80],
e = offset - 40; top row reserved for Inf/NaN) and keeps GF16's 9-bit mantissa, giving
~24 decades of range with no regime decode. The raw 17-bit value is carried in an int.

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
"""

from ._binding import (
    gft16_from_f32,
    gft16_to_f32,
    gft16_add,
    gft16_sub,
    gft16_mul,
    gft16_div,
    gft16_neg,
    gft16_abs,
    gft16_is_finite,
)


class Gft16:
    """A GF-T16 value. Construct from float, operate with +-*/, read back with .to_f32()."""

    __slots__ = ("raw",)

    def __init__(self, raw: int = 0):
        self.raw = raw & 0x1FFFF  # 17-bit payload

    @classmethod
    def from_f32(cls, x: float) -> "Gft16":
        return cls(gft16_from_f32(float(x)))

    def to_f32(self) -> float:
        return gft16_to_f32(self.raw)

    def __add__(self, other: "Gft16") -> "Gft16":
        return Gft16(gft16_add(self.raw, other.raw))

    def __sub__(self, other: "Gft16") -> "Gft16":
        return Gft16(gft16_sub(self.raw, other.raw))

    def __mul__(self, other: "Gft16") -> "Gft16":
        return Gft16(gft16_mul(self.raw, other.raw))

    def __truediv__(self, other: "Gft16") -> "Gft16":
        return Gft16(gft16_div(self.raw, other.raw))

    def __neg__(self) -> "Gft16":
        return Gft16(gft16_neg(self.raw))

    def __abs__(self) -> "Gft16":
        return Gft16(gft16_abs(self.raw))

    def is_finite(self) -> bool:
        return gft16_is_finite(self.raw)

    def __repr__(self) -> str:
        return f"Gft16({self.to_f32():.6g})"

    def __float__(self) -> float:
        return self.to_f32()
