#!/usr/bin/env python3
"""
GoldenFloat Python Example — Using GoldenFloat from Python via ctypes

Build the shared library first:
    zig build shared

Run:
    python3 python_example.py
"""

import ctypes
import os
import sys

# Find the library
lib_path = os.path.join("zig-out", "lib")
if sys.platform == "darwin":
    lib_name = "libgoldenfloat.dylib"
elif sys.platform == "linux":
    lib_name = "libgoldenfloat.so"
elif sys.platform == "win32":
    lib_name = "goldenfloat.dll"
else:
    raise RuntimeError(f"Unsupported platform: {sys.platform}")

lib_file = os.path.join(lib_path, lib_name)
if not os.path.exists(lib_file):
    print(f"Error: Library not found at {lib_file}")
    print("Run: zig build shared")
    sys.exit(1)

# Load the library
lib = ctypes.CDLL(lib_file)

# Configure function signatures
gf16_t = ctypes.c_uint16

# Conversion functions
lib.gf16_from_f32.restype = gf16_t
lib.gf16_from_f32.argtypes = [ctypes.c_float]

lib.gf16_to_f32.restype = ctypes.c_float
lib.gf16_to_f32.argtypes = [gf16_t]

# Arithmetic functions
lib.gf16_add.restype = gf16_t
lib.gf16_add.argtypes = [gf16_t, gf16_t]

lib.gf16_sub.restype = gf16_t
lib.gf16_sub.argtypes = [gf16_t, gf16_t]

lib.gf16_mul.restype = gf16_t
lib.gf16_mul.argtypes = [gf16_t, gf16_t]

lib.gf16_div.restype = gf16_t
lib.gf16_div.argtypes = [gf16_t, gf16_t]

# Unary functions
lib.gf16_neg.restype = gf16_t
lib.gf16_neg.argtypes = [gf16_t]

lib.gf16_abs.restype = gf16_t
lib.gf16_abs.argtypes = [gf16_t]

# Comparison functions
lib.gf16_eq.restype = ctypes.c_bool
lib.gf16_eq.argtypes = [gf16_t, gf16_t]

lib.gf16_lt.restype = ctypes.c_bool
lib.gf16_lt.argtypes = [gf16_t, gf16_t]

lib.gf16_cmp.restype = ctypes.c_int
lib.gf16_cmp.argtypes = [gf16_t, gf16_t]

# Predicate functions
lib.gf16_is_nan.restype = ctypes.c_bool
lib.gf16_is_nan.argtypes = [gf16_t]

lib.gf16_is_inf.restype = ctypes.c_bool
lib.gf16_is_inf.argtypes = [gf16_t]

lib.gf16_is_zero.restype = ctypes.c_bool
lib.gf16_is_zero.argtypes = [gf16_t]

lib.gf16_is_negative.restype = ctypes.c_bool
lib.gf16_is_negative.argtypes = [gf16_t]

# φ-Math functions
lib.gf16_phi_quantize.restype = gf16_t
lib.gf16_phi_quantize.argtypes = [ctypes.c_float]

lib.gf16_phi_dequantize.restype = ctypes.c_float
lib.gf16_phi_dequantize.argtypes = [gf16_t]

# Utility functions
lib.gf16_fma.restype = gf16_t
lib.gf16_fma.argtypes = [gf16_t, gf16_t, gf16_t]

# Library info
lib.goldenfloat_version.restype = ctypes.c_char_p
lib.goldenfloat_version.argtypes = []

lib.goldenfloat_phi.restype = ctypes.c_double
lib.goldenfloat_phi.argtypes = []

lib.goldenfloat_trinity.restype = ctypes.c_double
lib.goldenfloat_trinity.argtypes = []


def main():
    print("GoldenFloat Python Example v1.1.0")
    print("=" * 40)
    print()

    # Test basic conversion
    pi = 3.14159
    gf_pi = lib.gf16_from_f32(pi)
    back = lib.gf16_to_f32(gf_pi)
    print(f"Original: {pi:.5f}")
    print(f"GF16:     0x{gf_pi:04X}")
    print(f"Back:     {back:.5f}")
    print(f"Error:    {abs(pi - back) / pi * 100:.2f}%")
    print()

    # Test arithmetic
    a = lib.gf16_from_f32(1.5)
    b = lib.gf16_from_f32(2.5)
    sum_ab = lib.gf16_add(a, b)
    prod_ab = lib.gf16_mul(a, b)
    diff_ab = lib.gf16_sub(b, a)
    quot_ab = lib.gf16_div(a, b)

    print("Arithmetic:")
    print(f"  1.5 + 2.5 = {lib.gf16_to_f32(sum_ab):.2f} (expected 4.0)")
    print(f"  1.5 * 2.5 = {lib.gf16_to_f32(prod_ab):.2f} (expected 3.75)")
    print(f"  2.5 - 1.5 = {lib.gf16_to_f32(diff_ab):.2f} (expected 1.0)")
    print(f"  1.5 / 2.5 = {lib.gf16_to_f32(quot_ab):.2f} (expected 0.6)")
    print()

    # Test φ-quantization
    weight = 2.71828
    quantized = lib.gf16_phi_quantize(weight)
    dequantized = lib.gf16_phi_dequantize(quantized)
    print("φ-Quantization:")
    print(f"  Original:     {weight:.5f}")
    print(f"  Quantized:    0x{quantized:04X}")
    print(f"  Dequantized:  {dequantized:.5f}")
    print()

    # Test predicates
    zero = lib.gf16_from_f32(0.0)
    inf_val = lib.gf16_from_f32(float('inf'))
    neg_val = lib.gf16_from_f32(-5.0)

    print("Predicates:")
    print(f"  gf16_is_zero(zero):     {lib.gf16_is_zero(zero)}")
    print(f"  gf16_is_inf(inf):      {lib.gf16_is_inf(inf_val)}")
    print(f"  gf16_is_negative(neg): {lib.gf16_is_negative(neg_val)}")
    print()

    # Test comparison
    x = lib.gf16_from_f32(1.0)
    y = lib.gf16_from_f32(2.0)
    z = lib.gf16_from_f32(1.0)

    print("Comparison:")
    print(f"  gf16_eq(1.0, 1.0): {lib.gf16_eq(x, z)}")
    print(f"  gf16_lt(1.0, 2.0): {lib.gf16_lt(x, y)}")
    print(f"  gf16_cmp(1.0, 2.0): {lib.gf16_cmp(x, y)}")
    print(f"  gf16_cmp(2.0, 1.0): {lib.gf16_cmp(y, x)}")
    print()

    # Test FMA (fused multiply-add)
    fma_result = lib.gf16_fma(a, b, lib.gf16_from_f32(4.0))
    print("FMA:")
    print(f"  1.5 * 2.5 + 4.0 = {lib.gf16_to_f32(fma_result):.2f} (expected 7.75)")
    print()

    # Library info
    version = lib.goldenfloat_version().decode('utf-8')
    phi = lib.goldenfloat_phi()
    trinity = lib.goldenfloat_trinity()

    print("Library Info:")
    print(f"  Version: {version}")
    print(f"  PHI: {phi:.10f}")
    print(f"  Trinity (PHI^2 + 1/PHI^2): {trinity:.1f}")


if __name__ == "__main__":
    main()
