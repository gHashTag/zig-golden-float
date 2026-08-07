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
    search_paths = [
        os.path.join(os.path.dirname(__file__), "..", "..", "zig-out", "lib"),
        os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "zig-out", "lib"),
        os.path.join(os.getcwd(), "zig-out", "lib"),
    ]

    env_dir = os.environ.get("GOLDENFLOAT_LIB_DIR")
    if env_dir:
        search_paths.insert(0, env_dir)

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

        _lib.goldenfloat_phi.restype = ctypes.c_double
        _lib.goldenfloat_phi.argtypes = []

        _lib.goldenfloat_trinity.restype = ctypes.c_double
        _lib.goldenfloat_trinity.argtypes = []

        _lib.goldenfloat_version.restype = ctypes.c_char_p
        _lib.goldenfloat_version.argtypes = []

        # GF-T16 (ternary-exponent) — raw 17-bit value carried in a uint32.
        _gft16_t = ctypes.c_uint32
        _lib.gft16_from_f32.restype = _gft16_t
        _lib.gft16_from_f32.argtypes = [ctypes.c_float]
        _lib.gft16_to_f32.restype = ctypes.c_float
        _lib.gft16_to_f32.argtypes = [_gft16_t]
        for _name in ("gft16_add", "gft16_sub", "gft16_mul", "gft16_div"):
            getattr(_lib, _name).restype = _gft16_t
            getattr(_lib, _name).argtypes = [_gft16_t, _gft16_t]
        for _name in ("gft16_neg", "gft16_abs"):
            getattr(_lib, _name).restype = _gft16_t
            getattr(_lib, _name).argtypes = [_gft16_t]
        _lib.gft16_is_finite.restype = ctypes.c_uint8
        _lib.gft16_is_finite.argtypes = [_gft16_t]

        # Other GF-T rungs (full ABI: from/to/add/sub/mul/div/neg/abs/is_finite).
        # The packed value rides in the low bits of the carrier: gft8 -> u16,
        # gft32 -> u64.
        for _pfx, _carrier in (("gft8", ctypes.c_uint16), ("gft32", ctypes.c_uint64)):
            getattr(_lib, f"{_pfx}_from_f32").restype = _carrier
            getattr(_lib, f"{_pfx}_from_f32").argtypes = [ctypes.c_float]
            getattr(_lib, f"{_pfx}_to_f32").restype = ctypes.c_float
            getattr(_lib, f"{_pfx}_to_f32").argtypes = [_carrier]
            for _op in (f"{_pfx}_add", f"{_pfx}_sub", f"{_pfx}_mul", f"{_pfx}_div"):
                getattr(_lib, _op).restype = _carrier
                getattr(_lib, _op).argtypes = [_carrier, _carrier]
            for _op in (f"{_pfx}_neg", f"{_pfx}_abs"):
                getattr(_lib, _op).restype = _carrier
                getattr(_lib, _op).argtypes = [_carrier]
            getattr(_lib, f"{_pfx}_is_finite").restype = ctypes.c_uint8
            getattr(_lib, f"{_pfx}_is_finite").argtypes = [_carrier]

        # Binary GF ladder (φ²-sized rungs from gf_binary.zig). Full ABI:
        # from/to/add/sub/mul/div/neg/abs/is_finite. GF16 is the rich gf16_* API;
        # GF4 is omitted (degenerate). Packed value rides in the low carrier bits.
        for _pfx, _carrier in (
            ("gf8", ctypes.c_uint8),
            ("gf12", ctypes.c_uint16),
            ("gf20", ctypes.c_uint32),
            ("gf24", ctypes.c_uint32),
            ("gf32", ctypes.c_uint32),
        ):
            getattr(_lib, f"{_pfx}_from_f32").restype = _carrier
            getattr(_lib, f"{_pfx}_from_f32").argtypes = [ctypes.c_float]
            getattr(_lib, f"{_pfx}_to_f32").restype = ctypes.c_float
            getattr(_lib, f"{_pfx}_to_f32").argtypes = [_carrier]
            for _op in (f"{_pfx}_add", f"{_pfx}_sub", f"{_pfx}_mul", f"{_pfx}_div"):
                getattr(_lib, _op).restype = _carrier
                getattr(_lib, _op).argtypes = [_carrier, _carrier]
            for _op in (f"{_pfx}_neg", f"{_pfx}_abs"):
                getattr(_lib, _op).restype = _carrier
                getattr(_lib, _op).argtypes = [_carrier]
            getattr(_lib, f"{_pfx}_is_finite").restype = ctypes.c_uint8
            getattr(_lib, f"{_pfx}_is_finite").argtypes = [_carrier]

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


# ---- GF-T16 (ternary-exponent) public wrappers ----
def gft16_from_f32(x: float) -> int:
    """Convert f32 to GF-T16 (raw 17-bit value in a uint32)."""
    return _get_lib().gft16_from_f32(x)


def gft16_to_f32(g: int) -> float:
    """Convert GF-T16 to f32."""
    return _get_lib().gft16_to_f32(g)


def gft16_add(a: int, b: int) -> int:
    return _get_lib().gft16_add(a, b)


def gft16_sub(a: int, b: int) -> int:
    return _get_lib().gft16_sub(a, b)


def gft16_mul(a: int, b: int) -> int:
    return _get_lib().gft16_mul(a, b)


def gft16_div(a: int, b: int) -> int:
    return _get_lib().gft16_div(a, b)


def gft16_neg(g: int) -> int:
    return _get_lib().gft16_neg(g)


def gft16_abs(g: int) -> int:
    return _get_lib().gft16_abs(g)


def gft16_is_finite(g: int) -> bool:
    return bool(_get_lib().gft16_is_finite(g))


# GF-T8 (E=3 trits, M=4 bits) — 10-bit value in a uint16.
def gft8_from_f32(x: float) -> int:
    return _get_lib().gft8_from_f32(x)


def gft8_to_f32(g: int) -> float:
    return _get_lib().gft8_to_f32(g)


def gft8_add(a: int, b: int) -> int:
    return _get_lib().gft8_add(a, b)


def gft8_sub(a: int, b: int) -> int:
    return _get_lib().gft8_sub(a, b)


def gft8_mul(a: int, b: int) -> int:
    return _get_lib().gft8_mul(a, b)


def gft8_div(a: int, b: int) -> int:
    return _get_lib().gft8_div(a, b)


def gft8_neg(g: int) -> int:
    return _get_lib().gft8_neg(g)


def gft8_abs(g: int) -> int:
    return _get_lib().gft8_abs(g)


def gft8_is_finite(g: int) -> bool:
    return bool(_get_lib().gft8_is_finite(g))


# GF-T32 (E=6 trits, M=25 bits) — 36-bit value in a uint64.
def gft32_from_f32(x: float) -> int:
    return _get_lib().gft32_from_f32(x)


def gft32_to_f32(g: int) -> float:
    return _get_lib().gft32_to_f32(g)


def gft32_add(a: int, b: int) -> int:
    return _get_lib().gft32_add(a, b)


def gft32_sub(a: int, b: int) -> int:
    return _get_lib().gft32_sub(a, b)


def gft32_mul(a: int, b: int) -> int:
    return _get_lib().gft32_mul(a, b)


def gft32_div(a: int, b: int) -> int:
    return _get_lib().gft32_div(a, b)


def gft32_neg(g: int) -> int:
    return _get_lib().gft32_neg(g)


def gft32_abs(g: int) -> int:
    return _get_lib().gft32_abs(g)


def gft32_is_finite(g: int) -> bool:
    return bool(_get_lib().gft32_is_finite(g))
