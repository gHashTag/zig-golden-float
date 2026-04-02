# GoldenFloat Go Bindings

Go bindings for GoldenFloat GF16 format via cgo.

## Installation

First build the shared library from zig-golden-float root:

```bash
cd /path/to/zig-golden-float
zig build shared
```

The go package has cgo directives linking to the built library. No additional installation needed.

## Usage

```go
package main

import (
    "fmt"
    "github.com/gashTag/zig-golden-float/go/goldenfloat"
)

func main() {
    // Create values
    a := goldenfloat.FromF32(3.14)
    b := goldenfloat.FromF32(2.71)

    // Arithmetic
    sum := a.Add(b)
    fmt.Printf("Sum: %.6g\n", sum.ToF32())

    // Comparison
    if a.Lt(b) {
        fmt.Println("a is less than b")
    }

    // Predicates
    zero := goldenfloat.Zero
    fmt.Printf("Is zero: %t\n", zero.IsZero())

    // phi-Math
    quantized := goldenfloat.PhiQuantize(2.71828)
    dequantized := quantized.PhiDequantize()
    fmt.Printf("Dequantized: %.6g\n", dequantized)

    // Static phi constants
    fmt.Printf("phi: %.10f\n", goldenfloat.Phi())
    fmt.Printf("phi_sq: %.10f\n", goldenfloat.PhiSq())
    fmt.Printf("trinity: %.1f\n", goldenfloat.Trinity())
}
```

## Running Tests

```bash
cd go/goldenfloat
go test -v
```

## Benchmarks

```bash
cd go/goldenfloat
go test -bench=. -benchmem
```

## License

MIT License — Copyright (c) 2026 Trinity Project
