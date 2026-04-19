# zig-golden-float

[![Zig](https://img.shields.io/badge/Zig-0.15+-F7A41D?logo=zig&logoColor=white)](https://ziglang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Golden Ratio](https://img.shields.io/badge/φ-1.618033988-gold)](https://en.wikipedia.org/wiki/Golden_ratio)
[![Ecosystem](https://img.shields.io/badge/Trinity-Core-purple)](https://github.com/gHashTag/trinity)

> **Numerical core of Trinity ecosystem** — GoldenFloat16, ternary arithmetic, VSA, unified JIT & VM built on golden ratio φ.

## ✨ Features

- 🔢 **GoldenFloat16 (GF16)** — 16-bit floating point in base-φ
- ⚖️ **Ternary Arithmetic** — balanced trits, bigint, packed trit storage
- 🧠 **VSA (Vector Symbolic Architecture)** — HRR, 10k-dim, 10k-dim binding
- ⚡ **Unified JIT** — ARM64 & x86_64 native codegen
- 🖥️ **VM** — stack-based interpreter with opcode dispatch
- 📐 **Transcendentals** — sin, cos, exp, log generated from .tri specs

## 📦 Installation

```zig
// build.zig.zon
.dependencies = .{
    .golden_float = .{
        .url = "https://github.com/gHashTag/zig-golden-float/archive/refs/heads/main.tar.gz",
        .hash = "...", // run \`zig fetch --save\` to get hash
    },
},
```

```bash
zig fetch --save https://github.com/gHashTag/zig-golden-float/archive/refs/heads/main.tar.gz
```

## 🏗️ Architecture

```
src/
├── formats/       GF16, GoldenFloat variants
├── math/          constants, transcendental, gen_*
├── ternary/       bigint, hybrid, packed_trit
├── vsa/           core, hrr, packed_vsa, 10k_vsa
└── vm/            vm, jit_unified, jit_arm64, jit_x86_64
```

## 🌌 Ecosystem

Core dep for:
- [zig-sacred-geometry](https://github.com/gHashTag/zig-sacred-geometry) → depends on this
- [zig-physics](https://github.com/gHashTag/zig-physics) → depends on this
- [zig-hdc](https://github.com/gHashTag/zig-hdc) → depends on this
- [trinity-training](https://github.com/gHashTag/trinity-training) → depends on this
- [trinity](https://github.com/gHashTag/trinity) → depends on this

## 📜 License

MIT © gHashTag
```
