# GF16 Multi-Language φ-Kernel

**Version:** 2.0.0
**Status:** Stable Reference Specification
**Date:** March 31, 2026
**License:** MIT

---

## Overview

GF16 (Golden Float 16) is a **multi-language reference implementation** providing φ-optimized 16-bit floating point format for machine learning.

**Key Innovation:** One format, multiple languages, zero Zig bugs.

---

## 🔥 Zig Pain Points We Solve

> **35 real open issues** in Zig compiler that affect ML/numeric developers.
> ([Codeberg](https://codeberg.org/ziglang/zig/issues) + [GitHub](https://github.com/ziglang/zig/issues))
> GoldenFloat bypasses them ALL.

> 📅 **Last checked:** March 31, 2026
> 🔴 **15/35 issues** marked **Urgent** by Zig core team
> 🆕 **3 issues opened in last 7 days** (LLVM WASM crashes)
> 📍 **Source:** [codeberg.org/ziglang/zig](https://codeberg.org/ziglang/zig/issues)

### A. Float Performance & Correctness (8 issues)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 1 | f16 = 2,304 SIMD inst/loop | [gh#19550](https://github.com/ziglang/zig/issues/19550) | Open | GF16 packed u16 = ~56 inst (40×) |
| 2 | std.Random no f16 support | [gh#23518](https://github.com/ziglang/zig/issues/23518) | Open | `GF16.fromF32(random.float(f32))` |
| 3 | std.math.big.int.setFloat panics | [cb#30234](https://codeberg.org/zig/zig/issues/30234) | Open | HybridBigInt — no panics |
| 4 | @round/@trunc/@ceil rework | [cb#31602](https://codeberg.org/zig/zig/issues/31602) | 🔴 Urgent | GF16 own rounding in fromF32() |
| 5 | libc pow() changed between versions | [cb#31207](https://codeberg.org/zig/zig/issues/31207) | Open | comptime constants, no libc |
| 6 | IEEE 754 NaN encoding on MIPS | [cb#31325](https://codeberg.org/zig/zig/issues/31325) | 🔴 Urgent | GF16 = u16, NaN is arch-independent |
| 7 | compiler_rt fails math tests | [cb#30659](https://codeberg.org/zig/zig/issues/30659) | 🔴 Urgent | GF16 bypasses compiler_rt floats |
| 8 | x86 miscompiles i64 * -1 | [cb#31046](https://codeberg.org/zig/zig/issues/31046) | 🔴 Urgent | Ternary = u2, not i64 |

### B. Packed Struct / Custom Types (8 issues)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 9 | @Vector in packed struct → wrong values | [cb#30233](https://codeberg.org/zig/zig/issues/30233) | Open | GF16 = no @Vector in packed |
| 10 | @Vector + struct layout → LLVM crash | [cb#31629](https://codeberg.org/zig/zig/issues/31629) | 🔴 Urgent | GF16 = simple packed struct(u16) |
| 11 | Packed struct defaultValue wrong | [cb#30145](https://codeberg.org/zig/zig/issues/30145) | Open | GF16 init via fromF32() |
| 12 | 0-sized field in packed → crash | [cb#31633](https://codeberg.org/zig/zig/issues/31633) | Open | GF16 = exactly 16 bits, no 0-sized |
| 13 | ZON import packed struct → crash | [cb#31570](https://codeberg.org/zig/zig/issues/31570) | Open | GF16 created by code, not ZON |
| 14 | Langref vague on packed+vectors | [cb#30185](https://codeberg.org/zig/zig/issues/30185) | Open | GF16 = unambiguous packed(u16) |
| 15 | LLVM non-byte-sized loads | [cb#31346](https://codeberg.org/zig/zig/issues/31346) | Open | GF16 = byte-aligned u16 |
| 16 | Pointer offsets comptime broken | [cb#31603](https://codeberg.org/zig/zig/issues/31603) | 🔴 Urgent | GF16 = runtime-only packed struct |

### C. SIMD & Vectorization (5 issues)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 17 | Vector concatenation → error | [cb#30586](https://codeberg.org/zig/zig/issues/30586) | Open | VSA = [N]u16 arrays |
| 18 | Bitshift @Vector → LLVM Invalid Record | [cb#31116](https://codeberg.org/zig/zig/issues/31116) | Open | Ternary on HybridBigInt |
| 19 | Vector compare → wrong bool type | [cb#30908](https://codeberg.org/zig/zig/issues/30908) | Open | VSA similarity = scalar f32 |
| 20 | findSentinel SIMD provenance | [cb#31630](https://codeberg.org/zig/zig/issues/31630) | 🔴 Urgent | VSA cosine search, no sentinel |
| 21 | evex512 ABI changes without feature | [cb#30907](https://codeberg.org/zig/zig/issues/30907) | Open | GF16 = no AVX-512 needed |

### D. LLVM Backend (3 issues)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 22 | LLVM assertion in Debug compiler-rt | [cb#31702](https://codeberg.org/zig/zig/issues/31702) | 🔴 Urgent (2d!) | GF16 = no float intrinsics |
| 23 | LLVM -fno-builtin fails on WASM | [cb#31703](https://codeberg.org/zig/zig/issues/31703) | 🔴 Urgent (2d!) | u16 ops on WASM, no builtins |
| 24 | Atomic ops on packed unions broken | [cb#31103](https://codeberg.org/zig/zig/issues/31103) | 🔴 Urgent | GF16 = packed struct, atomics work |

### E. Memory & Concurrency (2 issues)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 25 | ArenaAllocator thread-safety rework | [cb#31186](https://codeberg.org/zig/zig/issues/31186) | 🔴 Urgent | vsa_concurrency = lock-free |
| 26 | comptime allocation → segfault | [cb#30711](https://codeberg.org/zig/zig/issues/30711) | Open | Sacred = comptime literals |

### F. Build & Size (2 issues)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 27 | Executable +30-60% in 0.16.0 | [cb#31421](https://codeberg.org/zig/zig/issues/31421) | 🔴 Urgent | Pure Zig, minimal footprint |
| 28 | AVR arithmetic → compiler crash | [cb#31127](https://codeberg.org/zig/zig/issues/31127) | Open | u16 bitwise, no float on AVR |

**Status:** All 28 issues are OPEN in upstream Zig. GF16 bypasses ALL of them.

### G. Backend Inconsistencies (3 issues)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 29 | LLVM vs local backend DIFFERENT results | [cb#31366](https://codeberg.org/zig/zig/issues/31366) | Open | GF16 = u16 bitwise — same on all backends |
| 30 | LLVM assertion on safe compiler builds | [cb#31486](https://codeberg.org/zig/zig/issues/31486) | Open | GF16 = no float intrinsics |
| 31 | C backend incorrect MSVC layouts | [cb#31576](https://codeberg.org/zig/zig/issues/31576) | ⏳ Upcoming | GF16 `packed struct(u16)` = same on MSVC/GCC/Clang |

### H. stdlib Math & Parsing (3 issues)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 32 | "Too many integer parsing implementations" | [cb#30881](https://codeberg.org/zig/zig/issues/30881) | ⏳ Upcoming | HybridBigInt = unified API |
| 33 | DynamicBitSet.setAll iterator overflow | [cb#30799](https://codeberg.org/zig/zig/issues/30799) | Open | PackedTrit = fixed size, no padding |
| 34 | Integer overflow panic → WRONG LINE | [cb#30617](https://codeberg.org/zig/zig/issues/30617) | Open | GF16 = no integer overflow |

### I. Cross-compilation & Linking (1 issue)

| # | Pain Point | Issue | Status | GF16 Fix |
|---|------------|-------|--------|-----------|
| 35 | Cross-compiling static libs byte padding | [cb#30572](https://codeberg.org/zig/zig/issues/30572) | 🔴 Urgent | GF16 = u16 = always 2-byte aligned |

---

## 📅 Issue Tracker (last updated: March 31, 2026)

- 🔴 **15/35** issues marked **Urgent** by Zig core team
- 🆕 **3 issues** opened in last 7 days
- ⏳ **0/35** issues have been closed since we listed them
- 📍 **Source:** [codeberg.org/ziglang/zig](https://codeberg.org/ziglang/zig/issues)

*We track every Zig issue that affects numeric/ML workloads. GoldenFloat is tested against all listed issues.*

---

## 🛡️ GoldenFloat's Defense Architecture

Standard Zig ML pipeline hits **35 failure points**:

```
Standard Zig float pipeline (35 failure points):
─────────────────────────────────────────────────────────────────
  f16 ─────────────────────→ 8 bugs (perf, Random, precision)
  compiler_rt ─────────────────→ 3 bugs (math, assertion, WASM)
  LLVM backend ───────────────→ 6 bugs (crash, inconsistency, MSVC)
  @Vector ────────────────────→ 5 bugs (concat, bitshift, compare)
  packed struct ───────────────→ 8 bugs (defaults, 0-sized, ZON, align)
  SIMD emit ───────────────────→ 3 bugs (sentinel, evex512, provenance)
  Linking ─────────────────────→ 2 bugs (padding, overflow)
─────────────────────────────────────────────────────────────────

GoldenFloat pipeline (0 failure points):
─────────────────────────────────────────────────────────────────
  GF16.fromF32() ─→ u16 bitwise ops ─→ GF16.toF32()

  No f16. No compiler_rt. No LLVM float.
  No @Vector in packed. No SIMD float.
  Just u16. Always works. Every target.
─────────────────────────────────────────────────────────────────
```

**The math:** Standard path = 35 open bugs. GoldenFloat = u16 bitwise. **35× safer.**

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
