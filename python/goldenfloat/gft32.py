"""
Gft32 — Python wrapper for GF-T32 (ternary-exponent GoldenFloat, wide rung).

GF-T32 stores the exponent as a balanced-ternary number (6 trits, offset in [0,728],
e = offset - 364; top row reserved for Inf/NaN) with a 25-bit mantissa, giving ~219
decades of range — every finite IEEE float32 is finite in GF-T32. The raw 36-bit value
is carried in an int. Subset ABI: from/to float, add, mul, is_finite.

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
"""

from ._binding import (
    gft32_from_f32,
    gft32_to_f32,
    gft32_add,
    gft32_mul,
    gft32_is_finite,
)


class Gft32:
    """A GF-T32 value. Construct from float, operate with + and *, read back with .to_f32()."""

    __slots__ = ("raw",)

    def __init__(self, raw: int = 0):
        self.raw = raw & 0xFFFFFFFFF  # 36-bit payload

    @classmethod
    def from_f32(cls, x: float) -> "Gft32":
        return cls(gft32_from_f32(float(x)))

    def to_f32(self) -> float:
        return gft32_to_f32(self.raw)

    def __add__(self, other: "Gft32") -> "Gft32":
        return Gft32(gft32_add(self.raw, other.raw))

    def __mul__(self, other: "Gft32") -> "Gft32":
        return Gft32(gft32_mul(self.raw, other.raw))

    def is_finite(self) -> bool:
        return gft32_is_finite(self.raw)

    def __repr__(self) -> str:
        return f"Gft32({self.to_f32():.6g})"

    def __float__(self) -> float:
        return self.to_f32()
