# GoldenFloat Python Bindings

Python bindings for GoldenFloat GF16 format via ctypes.

## Installation

First build the shared library from the zig-golden-float root:

```bash
cd /path/to/zig-golden-float
zig build shared
```

Then install the Python package:

```bash
cd python
pip install -e .
```

## Usage

```python
from goldenfloat import Gf16

# Create values
a = Gf16.from_f32(3.14)
b = Gf16.from_f32(2.71)

# Arithmetic
sum_gf = a + b
print(f"Sum: {sum_gf.to_f32()}")  # ~5.85

# Comparison
if a < b:
    print("a is less than b")

# Predicates
zero = Gf16.zero()
print(f"Is zero: {zero.is_zero()}")  # True

# φ-optimized quantization
quantized = Gf16.phi_quantize(2.71828)
dequantized = quantized.phi_dequantize()

# Constants
print(f"phi: {Gf16.phi()}")           # 1.618...
print(f"phi_sq: {Gf16.phi_sq()}")     # 2.618...
print(f"trinity: {Gf16.trinity()}")   # 3.0
```

## Running Tests

```bash
cd python
python -m goldenfloat.tests.test_gf16
```

## License

MIT License — Copyright (c) 2026 Trinity Project
