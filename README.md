# zig-golden-float

Numerical kernel for Trinity — GF16 format, VSA operations, and ternary computing primitives.

## Overview

This library provides the core numerical operations used by the Trinity framework:

- **GF16** — Integer-backed implementation of IBM's DLFloat format (1/6/9, bias=31)
- **VSA** — Vector Symbolic Architecture operations (bind, unbind, bundle, similarity)
- **Ternary VM** — Stack-based bytecode interpreter for {-1, 0, +1} computing

## Attribution

**GF16 adopts IBM's DLFloat format** (Agrawal et al., 2019; Mellempudi et al., 2021). The 1/6/9 allocation (6-bit exponent, 9-bit mantissa, bias=31) was first proposed by IBM researchers. This library's novelty is in its **integer-backed implementation** using `u16` storage, which bypasses compiler bugs in half-precision floating-point.

## Usage

```zig
const gf16 = @import("gf16.zig");

// Encode/decode
const encoded = gf16.encode(3.14159);
const decoded = gf16.decode(encoded);

// Arithmetic
const sum = gf16.add(a, b);
const product = gf16.mul(a, b);
```

## Building

```bash
zig build test
```

## References

- Agrawal, A. et al. "DLFloat: A 16-b Floating Point Format Designed for Deep Learning Training and Inference." IEEE VLSI Circuits, 2019.
- Mellempudi, N. et al. "Representation range needs for 16-bit neural network training." arXiv:2103.15940, 2021.

## License

MIT
