# GoldenFloat16 — φ-Optimized ML Number Formats for Zig

[![Zig](https://img.shields.io/badge/Zig-0.15+-000000.svg?logo=zig)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)

**GoldenFloat16** — φ-optimized number formats for Machine Learning in Zig.

## Features

- **GF16**: Golden Float16 — φ-optimized 16-bit format [sign:1][exp:6][mant:9]
  - Same 6:9 split as IBM DLFloat
  - phi-distance: 0.049 (vs 0.082 for IEEE f16)
  - 2x memory savings vs f32, similar precision for ML weights

- **TF3**: Ternary Float3 — packed ternary [sign:1][exp:6][mant:11]
  - 18-bit format for VSA and ternary computing
  - Direct {-1, 0, +1} encoding

## Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .golden_float = .{
        .url = "https://github.com/gHashTag/zig-golden-float/archive/refs/tags/main.tar.gz",
    },
},
```

## Quick Start

```zig
const std = @import("std");
const golden = @import("golden_float");

// GF16: φ-optimized 16-bit
const gf = golden.GF16.fromF32(3.14159);
const back = gf.toF32();

// φ-weighted quantization for ML weights
const weight: f32 = 0.753;
const quantized = golden.GF16.phiQuantize(weight);
const dequantized = golden.GF16.phiDequantize(quantized);

// TF3: ternary format
const tf3 = golden.TF3.fromF32(2.71828);
```

## Mathematical Foundation

**Trinity Identity:**
```
φ² + 1/φ² = 3
```

Where:
- φ (PHI) = (1 + √5) / 2 ≈ 1.6180339887498949
- φ² (PHI_SQ) ≈ 2.618033988749895
- 1/φ² ≈ 0.3819660112501052

The GF16 format uses a 6:9 bit split (exp:mant), achieving a phi-distance of 0.049 — closer to the golden ratio than IEEE f16's 5:10 split (phi-distance: 0.082).

## Format Comparison

| Format | Bits | Sign | Exp | Mant | Range | Precision |
|--------|-------|------|-----|------|-------|-----------|
| IEEE f16 | 16 | 1 | 5 | 10 | ±65,504 | ~3 decimal digits |
| **GF16** | 16 | 1 | 6 | 9 | ~4.3e9 | ~2 decimal digits |
| TF3 | 18 | 1 | 6 | 11 | ~2^31 | Ternary {-1,0,+1} |

## Benchmarks

Run benchmarks:

```bash
zig build benchmark
./zig-out/bin/benchmark
```

Output (preliminary, M1 Max):
```
GF16 encode/decode:  ~12ns/op
IEEE f16 cast:        ~8ns/op
Precision (GF16 vs f32): 0.5% avg error
```

## References

- [IBM DLFloat: A 16-bit Floating Point Format for Deep Learning](https://research.ibm.com/publications/dlfloat-a-16-floating-point-format-designed-for-deep-learning-training-and-inference)
- [Trinity Framework](https://github.com/gHashTag/trinity)
- [Zig 0.15 Documentation](https://ziglang.org/documentation/0.15.2/)

## License

MIT License — See LICENSE file for details.
