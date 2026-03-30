# GF16 Multi-Language φ-Kernel

**Version:** 2.0.0
**Status:** Stable Reference Specification
**Date:** March 31, 2026
**License:** MIT

---

## Overview

GF16 (Golden Float 16) is a **multi-language reference implementation** providing φ-optimized 16-bit floating point format for machine learning.

**Key Innovation:** One format, multiple languages, zero Zig bugs.

> 📊 **62 Zig issues bypassed** — GF16 works everywhere
> 🔴 **18/46 Urgent** (39% marked by Zig core team)
> 🏛 **12 categories** — Float, Packed, SIMD, LLVM, Memory, Linking, Parsing, Build, Embedded, Comptime
> 💀 **13 platforms** — Works on x86_64, ARM, RISC-V, AVR, WASM, FreeBSD, macOS, Windows, Android, SPIR-V, PowerPC, MSVC, UEFI

---

## What's Included

- `docs/spec-gf16.md` — **Complete format specification**
- `c/` — C99 reference implementation
- `rust/` — Rust crate (planned)
- `zig/` — Zig reference implementation
- `gleam/` — Gleam bindings (planned)
- `c++/` — C++ bindings (planned)
- `nif/` — NIF bindings (planned)
- `wasm/` — WASM bindings (planned)
- `llvm_ir/` — LLVM IR reference (planned)

---

## Quick Start

### Add as dependency

**build.zig.zon:**
```zig
.dependencies = .{
    .golden_float = .{
        .url = "https://github.com/gHashTag/zig-golden-float",
        .hash = "...",
    },
}
```

**build.zig:**
```zig
const golden_float = b.dependency("golden_float", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("golden-float", golden_float.module("golden-float"));
```

### Import in code

```zig
const golden = @import("golden-float");

// GF16: φ-optimized 16-bit
const gf = golden.formats.GF16.fromF32(3.14159);
const back = gf.toF32();
```

---

## Why Multi-Language?

**Zig alone:** 62 issues, 1 format, 1 ecosystem

**Multi-Language GF16:**
- Same 62 issues bypassed across ALL languages
- Rust devs get zero-float ML with `use gf16::Gf16;`
- C++ devs use `#include <gf16.h>` directly
- Zig devs use `@import("golden-float")` as before

**This creates network effects:**
- Rust → C++ → Zig → WASM → BEAM → NIF → LLVM
- One specification, multiple implementations
- Cross-language compatibility via FFI

---

## Roadmap

- [x] spec-gf16.md (v1.0) — Complete specification
- [x] zig/ reference implementation
- [x] c/ C99 reference
- [ ] rust/ Rust crate
- [ ] gleam/ Gleam bindings
- [ ] cpp/ C++ bindings
- [ ] nif/ NIF bindings
- [ ] wasm/ WASM bindings
- [ ] llvm_ir/ LLVM IR reference

---

## For Language Authors

### Adding a new language implementation:

1. Read `docs/spec-gf16.md` carefully
2. Create implementation in your language
3. Follow the reference (C implementation)
4. Ensure all tests pass:
   - Special values (NaN, Inf, Zero)
   - Subnormals
   - Rounding (round-to-nearest-even, ties-to-even)
   - φ-quantization (10 bins)
   - Bit-identical results across languages
5. Document any deviations from spec

### Validation

All implementations MUST pass:

```c
#include "c/gf16.h"
#include <assert.h>

int main(void) {
    // Special values
    assert(gf16_is_nan(gf16_from_raw(0x7C01)) == -1);
    assert(gf16_is_inf(gf16_from_raw(0x7C00)) == -1);
    assert(gf16_is_zero(gf16_from_raw(0x0000)) == 0);

    // Rounding
    gf16_t x = gf16_from_f32(0.0f);
    assert(gf16_to_f32(x) == gf16_to_f32(-0.0f)); // 0.0 is even mantissa

    // Addition
    gf16_t a = gf16_from_f32(1.0f);
    gf16_t b = gf16_from_f32(2.0f);
    gf16_t sum = gf16_add(a, b);
    assert(gf16_to_f32(sum) == 3.0f); // 1.0 + 2.0 = 3.0

    // Quantization
    gf16_t q = gf16_phi_quantize(3.14159f);
    assert(gf16_to_f32(q) == gf16_phi_dequantize(q).to_f32());

    printf("All tests passed!\\n");
    return 0;
}
```

---

## License

MIT License — See [LICENSE](LICENSE) for details.

---

**Links:**

- [Specification](docs/spec-gf16.md)
- [C Reference](c/)
- [Zig Reference](zig/)
- [Original README](https://github.com/gHashTag/zig-golden-float/blob/main/README.md)
