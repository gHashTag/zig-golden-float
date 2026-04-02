"""
Gf16 class — Python wrapper for GoldenFloat values.

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
"""

from ._binding import (
    gf16_from_f32,
    gf16_to_f32,
    gf16_add,
    gf16_sub,
    gf16_mul,
    gf16_div,
    gf16_neg,
    gf16_abs,
    gf16_eq,
    gf16_lt,
    gf16_le,
    gf16_cmp,
    gf16_is_nan,
    gf16_is_inf,
    gf16_is_zero,
    gf16_is_negative,
    gf16_phi_quantize,
    gf16_phi_dequantize,
    gf16_min,
    gf16_max,
    gf16_fma,
    goldenfloat_phi,
    goldenfloat_phi_inv_sq,
    goldenfloat_trinity,
)

# Try to load conformance vectors from shared dataset
_VECTORS = None
try:
    import json
    import os
    vectors_path = os.path.join(
        os.path.dirname(__file__), "..", "..", "..", "conformance", "vectors.json"
    )
    if os.path.exists(vectors_path):
        with open(vectors_path) as f:
            _VECTORS = json.load(f)
except Exception:
    pass


class Gf16:
    """
    GoldenFloat GF16 value wrapper.

    GF16 format: [sign:1][exp:6][mant:9] — φ-optimized 16-bit floating point.
    """

    __slots__ = ("_value",)

    # Constants
    GF16_ZERO = 0x0000
    GF16_ONE = 0x3C00
    GF16_PINF = 0x7E00
    GF16_NINF = 0xFE00
    GF16_NAN = 0x7E01

    def __init__(self, value: int):
        """Create Gf16 from raw 16-bit value."""
        if not isinstance(value, int) or not (0 <= value <= 0xFFFF):
            raise ValueError("Gf16 value must be a 16-bit unsigned integer")
        self._value = value

    @classmethod
    def from_f32(cls, x: float) -> "Gf16":
        """Convert f32 to GF16."""
        return cls(gf16_from_f32(x))

    def to_f32(self) -> float:
        """Convert GF16 to f32."""
        return gf16_to_f32(self._value)

    # Unary operators
    def __neg__(self) -> "Gf16":
        """Negate GF16 value."""
        return Gf16(gf16_neg(self._value))

    def __pos__(self) -> "Gf16":
        """Positive GF16 value."""
        return self

    def __abs__(self) -> "Gf16":
        """Absolute value of GF16."""
        return Gf16(gf16_abs(self._value))

    # Binary operators
    def __add__(self, other: "Gf16") -> "Gf16":
        """Add two GF16 values."""
        if isinstance(other, Gf16):
            return Gf16(gf16_add(self._value, other._value))
        return NotImplemented

    def __radd__(self, other: "Gf16") -> "Gf16":
        """Reverse add."""
        return self.__add__(other)

    def __sub__(self, other: "Gf16") -> "Gf16":
        """Subtract two GF16 values."""
        if isinstance(other, Gf16):
            return Gf16(gf16_sub(self._value, other._value))
        return NotImplemented

    def __rsub__(self, other: "Gf16") -> "Gf16":
        """Reverse subtract."""
        if isinstance(other, Gf16):
            return Gf16(gf16_sub(other._value, self._value))
        return NotImplemented

    def __mul__(self, other: "Gf16") -> "Gf16":
        """Multiply two GF16 values."""
        if isinstance(other, Gf16):
            return Gf16(gf16_mul(self._value, other._value))
        return NotImplemented

    def __rmul__(self, other: "Gf16") -> "Gf16":
        """Reverse multiply."""
        return self.__mul__(other)

    def __truediv__(self, other: "Gf16") -> "Gf16":
        """Divide two GF16 values."""
        if isinstance(other, Gf16):
            return Gf16(gf16_div(self._value, other._value))
        return NotImplemented

    def __rtruediv__(self, other: "Gf16") -> "Gf16":
        """Reverse divide."""
        if isinstance(other, Gf16):
            return Gf16(gf16_div(other._value, self._value))
        return NotImplemented

    # Comparison operators
    def __eq__(self, other: object) -> bool:
        """Equality test."""
        if isinstance(other, Gf16):
            return gf16_eq(self._value, other._value)
        return False

    def __lt__(self, other: "Gf16") -> bool:
        """Less-than test."""
        if isinstance(other, Gf16):
            return gf16_lt(self._value, other._value)
        return NotImplemented

    def __le__(self, other: "Gf16") -> bool:
        """Less-than-or-equal test."""
        if isinstance(other, Gf16):
            return gf16_le(self._value, other._value)
        return NotImplemented

    def __gt__(self, other: "Gf16") -> bool:
        """Greater-than test."""
        if isinstance(other, Gf16):
            return gf16_lt(other._value, self._value)
        return NotImplemented

    def __ge__(self, other: "Gf16") -> bool:
        """Greater-than-or-equal test."""
        if isinstance(other, Gf16):
            return gf16_le(other._value, self._value)
        return NotImplemented

    def __ne__(self, other: object) -> bool:
        """Not-equal test."""
        if isinstance(other, Gf16):
            return not gf16_eq(self._value, other._value)
        return True

    def __cmp__(self, other: "Gf16") -> int:
        """Three-way comparison."""
        if isinstance(other, Gf16):
            return gf16_cmp(self._value, other._value)
        return NotImplemented

    # Predicates
    def is_nan(self) -> bool:
        """Check if value is NaN."""
        return gf16_is_nan(self._value)

    def is_inf(self) -> bool:
        """Check if value is infinity."""
        return gf16_is_inf(self._value)

    def is_zero(self) -> bool:
        """Check if value is zero."""
        return gf16_is_zero(self._value)

    def is_negative(self) -> bool:
        """Check if value is negative."""
        return gf16_is_negative(self._value)

    # Constants
    @classmethod
    def zero(cls) -> "Gf16":
        """Zero constant."""
        return cls(cls.GF16_ZERO)

    @classmethod
    def one(cls) -> "Gf16":
        """One constant."""
        return cls(cls.GF16_ONE)

    @classmethod
    def p_inf(cls) -> "Gf16":
        """Positive infinity constant."""
        return cls(cls.GF16_PINF)

    @classmethod
    def n_inf(cls) -> "Gf16":
        """Negative infinity constant."""
        return cls(cls.GF16_NINF)

    @classmethod
    def nan(cls) -> "Gf16":
        """NaN constant."""
        return cls(cls.GF16_NAN)

    # phi-Math
    @classmethod
    def phi_quantize(cls, x: float) -> "Gf16":
        """φ-optimized quantization."""
        return cls(gf16_phi_quantize(x))

    def phi_dequantize(self) -> float:
        """φ-optimized dequantization."""
        return gf16_phi_dequantize(self._value)

    @staticmethod
    def phi() -> float:
        """Golden ratio φ constant."""
        return goldenfloat_phi()

    @staticmethod
    def phi_sq() -> float:
        """φ² constant."""
        return goldenfloat_phi() ** 2

    @staticmethod
    def phi_inv_sq() -> float:
        """1/φ² constant."""
        return 1.0 / (goldenfloat_phi() ** 2)

    @staticmethod
    def trinity() -> float:
        """Trinity constant (3.0)."""
        return goldenfloat_trinity()

    # Utility methods
    def min(self, other: "Gf16") -> "Gf16":
        """Minimum of two values."""
        return Gf16(gf16_min(self._value, other._value))

    def max(self, other: "Gf16") -> "Gf16":
        """Maximum of two values."""
        return Gf16(gf16_max(self._value, other._value))

    @staticmethod
    def fma(a: "Gf16", b: "Gf16", c: "Gf16") -> "Gf16":
        """Fused multiply-add: a * b + c."""
        return Gf16(gf16_fma(a._value, b._value, c._value))

    # Representation
    def __repr__(self) -> str:
        """String representation."""
        return f"Gf16({self.to_f32():.6g})"

    def __str__(self) -> str:
        """String representation."""
        return f"Gf16({self.to_f32():.6g})"

    def __int__(self) -> int:
        """Integer value (raw bits)."""
        return self._value

    def __float__(self) -> float:
        """Float value."""
        return self.to_f32()

    def __hash__(self) -> int:
        """Hash value."""
        return hash(self._value)
