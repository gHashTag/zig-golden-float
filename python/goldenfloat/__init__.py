"""
GoldenFloat — φ-optimized 16-bit floating point format for Python

This package provides Python bindings for GoldenFloat via ctypes.
Build the shared library first: zig build shared

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
"""

from .gf16 import Gf16

__version__ = "1.0.0"
__all__ = ["Gf16"]
