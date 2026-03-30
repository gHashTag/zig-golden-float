# TRI Format Code Generator

Zig-based generator for Trinity/GoldenFloat `.tri` specification format.

**`.tri` is our internal DSL for numeric format specifications** — not JSON/YAML.

## Quick Start

```bash
# Generate all languages (reads .tri extension)
zig run tri_gen --lang all

# Generate specific language
zig run tri_gen --lang rust
zig run tri_gen --lang c
zig run tri_gen --lang zig
zig run tri_gen --lang cpp

# Dry-run (show what would be generated)
zig run tri_gen --dry-run --verbose

# Custom input file
zig run tri_gen --input specs/custom.tri --lang rust
```

## Architecture

```
specs/*.tri (DSL specifications)
       │
       └──> tools/gen/tri_reader.zig (parser + AST)
              │
              └──> tools/gen/tri_gen.zig (code generator)
                     │
                     ├──> c/gf16.{h,c}
                     ├──> rust/src/lib.rs
                     ├──> zig/src/formats/gf16.zig
                     └──> cpp/gf16.hpp
```

## Specification Levels

| Level | Formats | Capabilities |
|-------|----------|--------------|
| **0 — Format** | GF16 | Basic: sign, exponent, mantissa, bias |
| **1 — Ops** | GF16 | Arithmetic: add, mul, fma, div, sqrt |
| **2 — Composite** | TF3 | Ternary: trit_mul, ternary_conv, dot_product |
| **3 — Hardware** | GF16 | FPGA: pipeline stages, resource mapping |
| **4 — Training** | GF16 | Training loop: forward/backward, optimizer |

## Current Implementations

### Level 0 — Format (GF16)

- **specs/gf16.tri**: Binary floating-point format
  - 1 sign bit, 6 exponent bits, 9 mantissa bits
  - Rounding: ties-to-even
  - Target: C, Rust, Zig, C++

### Level 2 — Operations (planned)

```yaml
# Future: ops.tri (Level 2)
ops:
  add:
    inputs: [GF16, GF16]
    output: GF16
    algorithm: add
  mul:
    inputs: [GF16, GF16]
    output: GF16
    algorithm: mul
```

### Level 2 — Composite (TF3-9) — ✅ DONE

- **specs/tf3.tri**: Ternary float format
  - 13 trits (3 exp, 9 mant)
  - Balanced ternary encoding (-1=10, 0=00, +1=01)
  - Trit multiplication LUT (9×9)

```yaml
# TF3 composite operations supported
composite:
  ternary_conv:
    inputs: [TF3[H,W], TF3[K,C]]
    weights: TF3[K,K]
    output: TF3[H,W]
    algorithm: im2col + matmul

  trit_mul:
    inputs: [trit, trit]
    output: trit
    algorithm: lookup  (9×9 LUT)

  dot:
    inputs: [TF3[N], TF3[N]]
    output: i32
    algorithm: sum-of-trit-muls
```

### Level 4 — Hardware (planned)

```yaml
# Future: hardware.tri (Level 4)
hardware:
  target: xc7a100t
  pipeline_stages: 3
  resources:
    dsp: 0
    lut: 9×9 = 27 entries
    bram: minimal
```

## For Agents

To regenerate all implementations after modifying any `specs/*.tri`:

```bash
cd zig-golden-float
zig run tri_gen --lang all
```

All supported formats are discovered automatically by `specs/*.tri` files.

## For Contributors

### Adding a New Format

1. Create `specs/format_name.tri` with level and format sections
2. Extend `tri_reader.zig` to parse new fields
3. Add generator functions to `tri_gen.zig`
4. Update documentation

### Level Reference

- **Level 0 (Format)**: Basic numeric format (GF16, BF16, FP8, INT8...)
- **Level 1 (Ops)**: Arithmetic operations (add, mul, sqrt, div...)
- **Level 2 (Composite)**: Tensor operations (matmul, conv, attention...)
- **Level 3 (Hardware)**: Pipeline and resource mapping (FPGA, ASIC...)
- **Level 4 (Training)**: Training operations (SGD, Adam, quantization...)

### Parser Notes

- Line-based parser (not YAML/JSON) — our own DSL
- Comments start with `#`
- Key-value pairs: `key: value`
- Lists: `- name: value` for arrays
- Supports both float (GF16) and ternary (TF3) formats

## Dependencies

**Zero** — pure Zig standard library only (no YAML/JSON/C libraries).
