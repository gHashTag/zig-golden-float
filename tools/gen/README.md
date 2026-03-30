# TRI Format Code Generator

Zig-based generator that reads `.tri` specification files and generates language implementations.

## Usage

```bash
# Generate all languages
zig run tri_gen --lang all

# Generate specific language
zig run tri_gen --lang rust
zig run tri_gen --lang c
zig run tri_gen --lang zig
zig run tri_gen --lang cpp

# Custom input file
zig run tri_gen --lang rust --input specs/custom.tri

# Show help
zig run tri_gen --help
```

## CLI Arguments

| Argument | Short | Description |
|----------|--------|-------------|
| `--lang` | `-l` | Language to generate: `all`, `c`, `rust`, `zig`, `cpp` (default: `all`) |
| `--input` | `-i` | Input spec file (default: `specs/gf16.tri`) |
| `--help` | `-h` | Show help message |

## Generated Files

| Language | Files |
|----------|--------|
| C | `c/gf16.h`, `c/gf16.c` |
| Rust | `rust/src/lib.rs` |
| Zig | `zig/src/formats/gf16.zig` |
| C++ | `cpp/gf16.hpp` |

## Specification Format (.tri)

The `.tri` file format defines the binary format, ABI mappings, and conversion rules.

See `specs/gf16.tri` for the complete GF16 specification.

### Key Sections

- `format`: Format name and version
- `storage`: Bit layout, alignment, endianness, underlying type
- `fields`: Field definitions (sign, exponent, mantissa)
- `exponent`: Bias, range, special value encoding
- `rounding`: Rounding mode, overflow/underflow policies
- `phi`: Golden-ratio distance metrics
- `abi`: Language-specific type mappings
- `conversion`: f32 ↔ GF16 conversion steps
- `test_vectors`: Reference test cases

## For Agents

To regenerate all implementations after modifying `specs/gf16.tri`:

```bash
cd zig-golden-float
zig run tri_gen --lang all
```

## Architecture

```
specs/gf16.tri
    │
    ├──> tri_reader.zig (load Spec)
    │
    └──> tri_gen.zig (generate code)
           │
           ├──> c/gf16.{h,c}
           ├──> rust/src/lib.rs
           ├──> zig/src/formats/gf16.zig
           └──> cpp/gf16.hpp
```

## Dependencies

None — pure Zig standard library only.
