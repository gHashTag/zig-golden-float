# GoldenFloat Go Bindings

cgo wrapper for GF16 (Golden Float16) format.

## Installation

```bash
go install ./...
```

## Quick Start

```go
package main

import "github.com/gHashTag/zig-golden-float/go/goldenfloat"

func main() {
    a := FromF32(3.14)
    b := FromF32(2.71)
    c := a.Add(b)

    fmt.Printf("a + b = %v\\n", c.ToF32())
}
```

## API Reference

### Conversions
- `FromF32(x float32) Gf16`
- `(g Gf16).ToF32() float32`

### Arithmetic Operators
- `Add(b Gf16) Gf16`
- `Sub(b Gf16) Gf16`
- `Mul(b Gf16) Gf16`
- `Div(b Gf16) Gf16`
- `Neg() Gf16`

### Predicates
- `IsNaN(g) bool`
- `IsInf(g) bool`
- `IsZero(g) bool`
- `IsNegative(g) bool`

### φ-Math Functions
- `PhiQuantize(x float32) Gf16`
- `PhiDequantize() float32`
- `Phi() float64`
- `PhiSq() float64`
- `PhiInvSq() float64`
- `Trinity() float64`

### Constants
- `Zero() Gf16`
- `One() Gf16`
- `PInf() Gf16`
- `NInf() Gf16`
- `Nan() Gf16`

### Utility Functions
- `Min(a, b Gf16) Gf16`
- `Max(a, b Gf16) Gf16`
- `Fma(a, b, c Gf16) Gf16`

## Conformance

Go tests use `../conformance/vectors.json` to verify correct behavior.

```bash
go test ./...
```

## Format

GF16: [sign:1][exp:6][mant:9] (16 bits total)

- **Exponent Bias:** 31
- **Special Values:** exp=0x3F (63) = infinity/NaN

**Note:** cgo directives (`#cgo LDFLAGS`, `#cgo CFLAGS`) handle library path automatically. Include paths in `go.mod` are set to find the library.

## License

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
