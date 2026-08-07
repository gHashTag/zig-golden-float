# Spec-first GF-T: making the ternary ladder generated, not hand-written

Status: **plan** (investigation done; codegen work scoped). The GF-T codec
(`src/formats/gft.zig`) and its C-ABI + Python binding are working **stop-gaps** —
the repo's rule (CLAUDE.md §0–2) is that number formats live in `specs/*.tri` and every
language artifact is emitted by `tools/gen/tri_gen`. This document is the path to bring
GF-T under that rule.

## What already exists

- `specs/gft.tri` — the authoritative GF-T ladder parameters (ladder form: E-trits,
  mantissa bits, `EXP_OFFSET`, `OFFSET_MAX` per rung). Source of truth for the numbers.
- `tools/gen/tri_reader.zig` — the `.tri` parser. It **already models ternary**:
  `Exponent{ bias: u8, trits: u8 = 0, special }` and `Field{ trit_value, trit_count }`,
  plus a `ternary: ?Ternary` block (used by TF3). So a GF-T rung is expressible as a
  single-format `.tri` (like `specs/gf16.tri`) with `exponent.trits = 4`, `bias = 0`,
  and the offset semantics captured in `exponent.special`.
- `tools/gen/tri_gen.zig` — emits `c / rust / zig / cpp` from a parsed `Spec`.

## The three gaps (in order)

1. **`tri_gen` leaks on zig 0.16.0.** Running `zig run tools/gen/tri_gen -- --lang zig
   --input specs/gf16.tri` aborts under the DebugAllocator: `tri_reader.readKey`
   (`self.allocator.dupe(u8, slice)`, tri_reader.zig:346) is never freed; `Spec.deinit`
   frees `fields`/typedefs but not every duped key/scalar. **Fix first** — either free
   the duped keys in `parseSpec`/`deinit`, or use an arena for the parse. This is a
   prerequisite: codegen can't be trusted while the generator aborts.

2. **The `.tri` GF-T model.** Add canonical single-format specs `specs/gft4.tri /
   gft8.tri / gft16.tri / gft32.tri` mirroring `specs/gf16.tri`'s shape:
   ```
   format: GFT16
   storage: { bits: 32, underlying: u32 }   # 17-bit payload carried in u32
   fields:  [ sign(1), exponent(trits:4), mantissa(9) ]
   exponent:
     trits: 4
     offset_bias: 40         # e = offset - 40  (NEW key: ternary offset bias)
     offset_max: 80          # reserved Inf/NaN row (3^4 - 1)
     encoding: balanced-ternary
   ```
   This needs one new `Exponent` field in `tri_reader` (`offset_bias: ?u8`,
   `encoding: enum{binary, balanced_ternary}`) — additive, does not touch binary specs.

3. **The `tri_gen` ternary-exponent emitter.** When `exponent.encoding ==
   balanced_ternary`, emit the codec from `src/formats/gft.zig` (already the reference):
   `from_f32` normalizes to `[1,2)`, `offset = e + offset_bias`, saturate at
   `offset_max`; `to_f32` inverts. The binary emitter stays as-is; a `switch` on the
   encoding picks the body. The generated Zig should be **byte-comparable** to the
   current hand-written `gft.zig` (that is the acceptance test).

## Acceptance / migration

- `zig run tools/gen/tri_gen --lang all --input specs/gft16.tri` produces
  `gen/.../gft16.{zig,c,rs,hpp}` that pass the existing GF-T tests unchanged.
- `zig run tools/gen/check_tri_hashes --update` registers the new specs
  (`.trinity/tri_hashes.json`); CI `--verify` stays green.
- Retire the hand-written `gft.zig` in favour of the generated module (keep the thin
  C-ABI glue in `c_abi.zig`, which is FFI, not format logic).

Until step 1 lands, GF-T stays the hand-written stop-gap — correct and tested (CI green,
114+ tests), just not yet generated. This ordering keeps every increment shippable.
