# GoldenFloat C++ Bindings

Header-only C++ wrapper for GoldenFloat GF16 format.

## Installation

First build the shared library from zig-golden-float root:

```bash
cd /path/to/zig-golden-float
zig build shared
```

Then build and test the C++ bindings:

```bash
mkdir build && cd build
cmake ..
cmake --build . --target test_gf16
./test_gf16
```

## Usage

```cpp
#include <goldenfloat/gf16.hpp>
#include <iostream>

using namespace goldenfloat;

int main() {
    // Create values
    Gf16 a = Gf16::from_f32(3.14f);
    Gf16 b = Gf16::from_f32(2.71f);

    // Arithmetic
    Gf16 sum = a + b;
    std::cout << "Sum: " << sum.to_f32() << std::endl;

    // Predicates
    if (a < b) {
        std::cout << "a is less than b" << std::endl;
    }

    // Constants
    Gf16 zero = Gf16::zero();
    std::cout << "Is zero: " << zero.is_zero() << std::endl;

    // phi-Math
    Gf16 quantized = Gf16::phi_quantize(2.71828f);
    float dequantized = quantized.phi_dequantize();
    std::cout << "Dequantized: " << dequantized << std::endl;

    // Static phi constants
    std::cout << "phi: " << Gf16::phi() << std::endl;
    std::cout << "phi_sq: " << Gf16::phi_sq() << std::endl;
    std::cout << "trinity: " << Gf16::trinity() << std::endl;
}
```

## License

MIT License — Copyright (c) 2026 Trinity Project
