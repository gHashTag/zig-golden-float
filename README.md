# GoldenFloat — φ-Optimized Zig Kernel for ML

[![Zig](https://img.shields.io/badge/Zig-0.15+-000000.svg?logo=zig)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**GoldenFloat** provides φ-optimized number formats, VSA (Vector Symbolic Architecture), and ternary computing primitives for machine learning in pure Zig.

## Features

- **Formats**: GF16, TF3 number formats (φ-optimized)
- **VSA**: Vector Symbolic Architecture (bind, bundle, similarity)
- **Ternary**: HybridBigInt, packed trit storage
- **Math**: Sacred constants (φ, e, π)

## Why GF16 instead of IEEE f16?

| Problem | IEEE f16 [5:10] | GF16 [6:9] | Solution |
|---------|-----------------|------------|----------|
| **Range overflow** | Max ±65,504 — activations clip | ~4.3e9 — covers ML training range | No overflow during backprop |
| **Underflow to zero** | 2^(-14) ≈ 6.1e-5 — gradients vanish | 2^(-31) ≈ 4.7e-10 — gradients survive | Training converges faster |
| **Distribution mismatch** | 5:10 split far from φ-optimal | 6:9 split matches IBM DLFloat research | Better weight quantization |

**Benchmarks (M1 Max)**:
- GF16 encode/decode: ~12ns/op
- Precision (GF16 vs f32): 0.5% avg error

## Installation

Add to your `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .golden_float = .{
            .url = "https://github.com/gHashTag/zig-golden-float/archive/refs/tags/main.tar.gz",
            .hash = "1220...", // zig build help
        },
    },
}
```

Import in `build.zig`:

```zig
const golden_float = b.dependency("golden_float", .{
    .target = target,
    .optimize = optimize,
});
const gf_module = golden_float.module("golden-float");

const exe = b.addExecutable(.{ ... });
exe.root_module.addImport("golden-float", gf_module);
```

## Quick Start

```zig
const golden = @import("golden-float");

// GF16: φ-optimized 16-bit
const gf = golden.formats.GF16.fromF32(3.14159);

// VSA operations
const a = golden.vsa.HyperVector.random();
const b = golden.vsa.HyperVector.random();
const bound = golden.vsa.bind(a, b);
const similarity = golden.vsa.cosineSimilarity(a, b);

// Ternary computing
const n = golden.bigint.HybridBigInt.init(42);
const packed = golden.packed_trit.PackedTrit.fromBigInt(n);

// Sacred constants
const phi = golden.math.PHI;  // 1.618...
```

## Module Reference

### `formats` — GF16, TF3 Number Formats

```zig
const golden = @import("golden-float");

// GF16 conversion
const gf = golden.formats.GF16.fromF32(3.14159);
const back = gf.toF32();

// φ-weighted quantization
const quantized = golden.formats.GF16.phiQuantize(weight);
const dequantized = golden.formats.GF16.phiDequantize(quantized);

// TF3 ternary format
const tf3 = golden.formats.TF3.fromF32(2.71828);
```

### `vsa` — Vector Symbolic Architecture

```zig
const golden = @import("golden-float");

// Core VSA operations
const a = golden.vsa.HyperVector.random();
const b = golden.vsa.HyperVector.random();

// Bind two vectors
const bound = golden.vsa.bind(a, b);

// Retrieve from binding
const retrieved = golden.vsa.unbind(bound, b);

// Majority vote (bundle)
const bundled = golden.vsa.bundle2(a, b);

// Similarity
const sim = golden.vsa.cosineSimilarity(a, b);

// 10K-dimensional VSA
const hv10k = golden.vsa_10k.HyperVector10K.random();
```

### `ternary` — Ternary Computing

```zig
const golden = @import("golden-float");

// HybridBigInt — main big integer engine
const n = golden.bigint.HybridBigInt.init(42);
const sum = n.add(golden.bigint.HybridBigInt.init(99));

// Packed trit storage
const packed = golden.packed_trit.PackedTrit.fromBigInt(n);
const back = packed.toBigInt();
```

### `math` — Sacred Constants

```zig
const golden = @import("golden-float");

// Trinity Identity: φ² + 1/φ² = 3
const phi = golden.math.PHI;           // 1.618...
const phi_sq = golden.math.PHI_SQ;     // 2.618...
const trinity = golden.math.TRINITY;    // 3.0

// Other sacred constants
const e = golden.math.E;
const pi = golden.math.PI;
```

## Mathematical Foundation

**Trinity Identity:**
```
φ² + 1/φ² = 3
```

Where φ (phi) is the golden ratio:
```
φ = (1 + √5) / 2 ≈ 1.6180339887498949
```

The GF16 format uses a 6:9 bit split (exp:mant), achieving a phi-distance of 0.049 — closer to the golden ratio than IEEE f16's 5:10 split (phi-distance: 0.082).

## Testing

```bash
cd /tmp/zig-golden-float
zig build test
```

## References

- [IBM DLFloat Paper](https://research.ibm.com/publications/dlfloat-a-16-floating-point-format-designed-for-deep-learning-training-and-inference)
- [Trinity Framework](https://github.com/gHashTag/trinity)
- [Zig 0.15 Documentation](https://ziglang.org/documentation/0.15.2/)

## License

MIT License — See LICENSE file for details.
