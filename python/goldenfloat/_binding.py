"""
C-ABI binding loader for GoldenFloat.

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
"""

import ctypes
import os
import sys

# Library and function references
_lib = None
_gf16_t = None


def _find_library():
    """Find libgoldenfloat.{so,dylib,dll}"""
    # Check zig-out/lib first
    search_paths = [
        os.path.join(os.path.dirname(__file__), "..", "..", "zig-out", "lib"),
        os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "zig-out", "lib"),
    ]

    # Add current directory for development
    search_paths.append(os.getcwd())

    lib_name = None
    for lib in ["libgoldenfloat.dylib", "libgoldenfloat.so", "goldenfloat.dll"]:
        for path in search_paths:
            full_path = os.path.join(path, lib)
            if os.path.exists(full_path):
                lib_name = full_path
                break
        if lib_name:
            break

    if not lib_name:
        raise RuntimeError(
            "GoldenFloat library not found. Run 'zig build shared' in zig-golden-float root."
        )

    return lib_name


def _get_lib():
    """Lazy load library and configure function signatures."""
    global _lib, _gf16_t

    if _lib is None:
        lib_path = _find_library()
        _lib = ctypes.CDLL(lib_path)
        _gf16_t = ctypes.c_uint16

        # Conversion functions
        _lib.gf16_from_f32.restype = _gf16_t
        _lib.gf16_from_f32.argtypes = [ctypes.c_float]

        _lib.gf16_to_f32.restype = ctypes.c_float
        _lib.gf16_to_f32.argtypes = [_gf16_t]

        # Arithmetic functions
        _lib.gf16_add.restype = _gf16_t
        _lib.gf16_add.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_sub.restype = _gf16_t
        _lib.gf16_sub.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_mul.restype = _gf16_t
        _lib.gf16_mul.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_div.restype = _gf16_t
        _lib.gf16_div.argtypes = [_gf16_t, _gf16_t]

        # Unary functions
        _lib.gf16_neg.restype = _gf16_t
        _lib.gf16_neg.argtypes = [_gf16_t]

        _lib.gf16_abs.restype = _gf16_t
        _lib.gf16_abs.argtypes = [_gf16_t]

        # Comparison functions
        _lib.gf16_eq.restype = ctypes.c_bool
        _lib.gf16_eq.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_lt.restype = ctypes.c_bool
        _lib.gf16_lt.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_le.restype = ctypes.c_bool
        _lib.gf16_le.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_cmp.restype = ctypes.c_int
        _lib.gf16_cmp.argtypes = [_gf16_t, _gf16_t]

        # Predicate functions
        _lib.gf16_is_nan.restype = ctypes.c_bool
        _lib.gf16_is_nan.argtypes = [_gf16_t]

        _lib.gf16_is_inf.restype = ctypes.c_bool
        _lib.gf16_is_inf.argtypes = [_gf16_t]

        _lib.gf16_is_zero.restype = ctypes.c_bool
        _lib.gf16_is_zero.argtypes = [_gf16_t]

        _lib.gf16_is_negative.restype = ctypes.c_bool
        _lib.gf16_is_negative.argtypes = [_gf16_t]

        # phi-Math functions
        _lib.gf16_phi_quantize.restype = _gf16_t
        _lib.gf16_phi_quantize.argtypes = [ctypes.c_float]

        _lib.gf16_phi_dequantize.restype = ctypes.c_float
        _lib.gf16_phi_dequantize.argtypes = [_gf16_t]


        # Utility functions
        _lib.gf16_copysign.restype = _gf16_t
        _lib.gf16_copysign.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_min.restype = _gf16_t
        _lib.gf16_min.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_max.restype = _gf16_t
        _lib.gf16_max.argtypes = [_gf16_t, _gf16_t]

        _lib.gf16_fma.restype = _gf16_t
        _lib.gf16_fma.argtypes = [_gf16_t, _gf16_t, _gf16_t]

    return _lib


# Public wrappers for clean API
def gf16_from_f32(x: float) -> int:
    """Convert f32 to GF16."""
    return _get_lib().gf16_from_f32(x)


def gf16_to_f32(g: int) -> float:
    """Convert GF16 to f32."""
    return _get_lib().gf16_to_f32(g)


def gf16_add(a: int, b: int) -> int:
    """Add two GF16 values."""
    return _get_lib().gf16_add(a, b)


def gf16_sub(a: int, b: int) -> int:
    """Subtract two GF16 values."""
    return _get_lib().gf16_sub(a, b)


def gf16_mul(a: int, b: int) -> int:
    """Multiply two GF16 values."""
    return _get_lib().gf16_mul(a, b)


def gf16_div(a: int, b: int) -> int:
    """Divide two GF16 values."""
    return _get_lib().gf16_div(a, b)


def gf16_neg(g: int) -> int:
    """Negate GF16 value."""
    return _get_lib().gf16_neg(g)


def gf16_abs(g: int) -> int:
    """Absolute value of GF16."""
    return _get_lib().gf16_abs(g)


def gf16_eq(a: int, b: int) -> bool:
    """Equality test."""
    return _get_lib().gf16_eq(a, b)


def gf16_lt(a: int, b: int) -> bool:
    """Less-than test."""
    return _get_lib().gf16_lt(a, b)


def gf16_le(a: int, b: int) -> bool:
    """Less-than-or-equal test."""
    return _get_lib().gf16_le(a, b)


def gf16_cmp(a: int, b: int) -> int:
    """Three-way comparison: -1 if a < b, 0 if a == b, 1 if a > b."""
    return _get_lib().gf16_cmp(a, b)


def gf16_is_nan(g: int) -> bool:
    """Check if value is NaN."""
    return _get_lib().gf16_is_nan(g)


def gf16_is_inf(g: int) -> bool:
    """Check if value is infinity."""
    return _get_lib().gf16_is_inf(g)


def gf16_is_zero(g: int) -> bool:
    """Check if value is zero."""
    return _get_lib().gf16_is_zero(g)


def gf16_is_negative(g: int) -> bool:
    """Check if value is negative."""
    return _get_lib().gf16_is_negative(g)


def gf16_phi_quantize(x: float) -> int:
    """φ-optimized quantization."""
    return _get_lib().gf16_phi_quantize(x)


def gf16_phi_dequantize(g: int) -> float:
    """φ-optimized dequantization."""
    return _get_lib().gf16_phi_dequantize(g)


def gf16_copysign(target: int, source: int) -> int:
    """Copy sign from source to target."""
    return _get_lib().gf16_copysign(target, source)


def gf16_min(a: int, b: int) -> int:
    """Minimum of two values."""
    return _get_lib().gf16_min(a, b)


def gf16_max(a: int, b: int) -> int:
    """Maximum of two values."""
    return _get_lib().gf16_max(a, b)


def gf16_fma(a: int, b: int, c: int) -> int:
    """Fused multiply-add: a * b + c."""
    return _get_lib().gf16_fma(a, b, c)


def goldenfloat_version() -> str:
    """Get GoldenFloat version string."""
    return _get_lib().goldenfloat_version().decode("utf-8")


def goldenfloat_phi() -> float:
    """Get golden ratio φ constant."""
    return _get_lib().goldenfloat_phi()


def goldenfloat_phi_inv_sq() -> float:
    """Get 1/phi² constant."""
    return 1.0 / (goldenfloat_phi() ** 2)


def goldenfloat_trinity() -> float:
    """Get Trinity constant (3.0)."""
    return _get_lib().goldenfloat_trinity()
