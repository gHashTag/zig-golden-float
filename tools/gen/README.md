# TRI Format Code Generator

Zig-based generator for Trinity/GoldenFloat `.tri` specification format.

**`.tri` is the internal Trinity/GoldenFloat spec format — not JSON/YAML.**

## Usage

```bash
# Generate all languages
zig run tri_gen --lang all

# Generate specific language
zig run tri_gen --lang rust
zig run tri_gen --lang c
zig run tri_gen --lang zig
zig run tri_gen --lang cpp

# Dry-run (show what would be generated)
zig run tri_gen --dry-run --verbose

# Custom output directory
zig run tri_gen --output-root ./generated --lang rust
```

## CLI Arguments

| Argument | Short | Default | Description |
|----------|--------|---------|-------------|
| `--lang` | `-l` | `all` | Language: `all`, `c`, `rust`, `zig`, `cpp` |
| `--input` | `-i` | `specs/gf16.tri` | Input spec file |
| `--output-root` | `-o` | `.` | Output directory |
| `--dry-run` | `-n` | `false` | Show what would be generated without writing |
| `--verbose` | `-v` | `false` | Show detailed progress |
| `--help` | `-h` | — | Show help message |

## Generated Files

| Language | Files |
|----------|--------|
| C | `c/gf16.h`, `c/gf16.c` |
| Rust | `rust/src/lib.rs` |
| Zig | `zig/src/formats/gf16.zig` |
| C++ | `cpp/gf16.hpp` |

## For Agents

To regenerate all implementations after modifying `specs/gf16.tri`:

```bash
cd zig-golden-float
zig run tri_gen --lang all
```

## Architecture

```
specs/gf16.tri (.tri = Trinity spec format)
       │
       └──> tri_reader.zig (custom .tri parser)
              │
              └──> tri_gen.zig (CLI + generate)
                     │
                     ├──> c/gf16.{h,c}
                     ├──> rust/src/lib.rs
                     ├──> zig/src/formats/gf16.zig
                     └──> cpp/gf16.hpp
```

## Dependencies

**Zero** — pure Zig standard library only (custom .tri parser).
