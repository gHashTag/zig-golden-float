# GoldenFloat Python Bindings

Python ctypes wrapper for GF16 (Golden Float16) format.

## Installation

```bash
pip install -e .
```

## Quick Start

```python
from goldenfloat import Gf16

# Create from float32
a = Gf16.from_f32(3.14)
b = Gf16.from_f32(2.71)
c = a + b  # Uses operator overloading

print(f"a + b = {c.to_f32()}")
```

## API Reference

### Conversions
- `Gf16.from_f32(x: float) -> Gf16`
- `gf.to_f32() -> float`

### Arithmetic
- `gf16.__add__(other)` / `a + b`
- `gf16.__sub__(other)` / `a - b`
- `gf16.__mul__(other)` / `a * b`
- `gf16.__truediv__(other)` / `a / b`

### Predicates
- `gf.is_nan()` -> bool`
- `gf.is_inf()` -> bool`
- `gf.is_zero()` -> bool`
- `gf.is_negative()` -> bool

### φ-Math
- `Gf16.phi_quantize(x)` -> Gf16`
- `gf.phi_dequantize()` -> float`
- `Gf16.phi()` / `Gf16.phi_sq()` / `Gf16.phi_inv_sq()`
- `Gf16.trinity()` -> float (always 3.0)

### Constants
- `Gf16.zero()` -> Gf16 (0x0000)
- `Gf16.one()` -> Gf16 (0x3C00)
- `Gf16.p_inf()` -> Gf16 (0x7E00)
- `Gf16.n_inf()` -> Gf16 (0xFE00)
- `Gf16.nan()` -> Gf16 (0x7E01)

## Running Conformance Tests

Tests load `../conformance/vectors.json` and verify behavior against the canonical GoldenFloat C-ABI.

```bash
pytest goldenfloat/tests/
```

## License

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
