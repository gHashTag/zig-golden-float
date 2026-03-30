# TRI Format Code Generator

Generates language implementations from `.tri` specification files.

## Usage

```bash
# Generate all languages
python3 tools/gen/tri_gen.py --lang all

# Generate specific language
python3 tools/gen/tri_gen.py --lang rust
python3 tools/gen/tri_gen.py --lang c
python3 tools/gen/tri_gen.py --lang zig
python3 tools/gen/tri_gen.py --lang cpp

# Custom input/output
python3 tools/gen/tri_gen.py --lang rust --input specs/gf16.tri --output custom/path.rs
```

## Specification Format (.tri)

See `specs/gf16.tri` for reference format.

### Key Sections

- `storage`: Bit layout, alignment, endianness
- `fields`: Field definitions (sign, exponent, mantissa)
- `exponent`: Bias, range, special value encoding
- `rounding`: Rounding mode, overflow/underflow policies
- `phi`: Golden-ratio distance metrics
- `abi`: Language-specific type mappings
- `conversion`: f32 ↔ GF16 conversion steps
- `test_vectors`: Reference test cases

## Generated Outputs

| Language | Files |
|----------|-------|
| C | `c/gf16.h`, `c/gf16.c` |
| Rust | `rust/src/lib.rs` |
| Zig | `zig/src/formats/gf16.zig` |
| C++ | `cpp/gf16.hpp` |

## Dependencies

```bash
pip install pyyaml
```

## Integration with Build

Add to `build.zig` or Makefile for automatic regeneration when `.tri` changes.
