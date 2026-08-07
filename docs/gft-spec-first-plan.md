# Spec-first GF-T: the real state of `tri_gen`, and what generation would take

Status: **investigation** (corrected 2026-08). An earlier version of this doc assumed
`tri_gen` generates code from parsed spec fields. **It does not.** This document records
the actual architecture and the real (larger) work that "generate GF-T from `.tri`"
would require, so nobody chases a facade.

## Correction: `tri_gen` is a template COPIER, not a generator

`tools/gen/tri_gen.zig` parses the `.tri` (for validation + `--verbose` display), but its
four code emitters **discard the spec entirely** and copy a fixed GF16 template:

```zig
fn genZig(alloc, io, spec, ...) !void {
    _ = spec;                                   // <-- spec ignored
    const output = try readFileAlloc(alloc, io, "tools/gen/templates/gf16.zig", ...);
    try writeFile("zig/src/formats/gf16.zig", output, ...);
}
```

All of `genC` / `genRust` / `genZig` / `genCpp` are `_ = spec;` + copy
`tools/gen/templates/gf16.{h,c,rs,zig,hpp}` verbatim. So today `tri_gen --input
specs/anything.tri --lang zig` always writes the **same** GF16 file. There is no
parameterization by `bits`, `exponent`, `mantissa`, `fields`, or format name.

Consequence: the repo's "spec-first, everything is generated" rule (CLAUDE.md §0–2) is
**aspirational** — the generator is a stub. The hand-written `gft.zig` / `gf_binary.zig`
codecs are therefore not a shameful stop-gap; they are the *only* real implementations,
tested and green across 5 language bindings.

## Deeper: the `.tri` parser (`tri_reader`) does not actually parse the specs

Verified 2026-08 by driving `tri_reader.parse` on `specs/gf8.tri` and `specs/gf16.tri`
(2947 bytes of valid content in): it returns an **all-zero** `Storage` and `Exponent`
(`storage.bits = 0`, `exponent.bits/bias/max = 0`). The parser has effectively never
worked; `tri_gen` masks it because it ignores the parsed `Spec` anyway (template copier,
above). Concrete defects found, all in `tools/gen/tri_reader.zig`:

1. **Duplicated dispatch block** in `parseSpec` — two `else if (eql(key,"storage"))`
   branches; the first calls `consumeValue()` (skips the block), shadowing the real
   `spec.storage = parseStorage()` in the second. Same for stray version/level/type dups.
2. **`readKey` never consumes the `:`** (it breaks *at* `:`). A section header like
   `storage:` therefore leaves the cursor on `:`, so the sub-parser's first `readKey`
   sees `:` and returns `null` immediately — the block loop body never runs. Only the
   `constants`/`types` branches work around this by manually advancing past `:`.
3. **No indentation / dedent tracking.** The sub-block `while (readKey())` loops have no
   notion of block scope, so once (2) is fixed they would over-consume straight into the
   next top-level section (`fields:`, `exponent:`, …) via the `else => consumeValue()` arm.
4. **`parseStorage` is positional** — it calls `parseInt` directly on the `bits` *key*
   text, and `catch 0` swallows the `InvalidCharacter`, returning zeros and desyncing the
   cursor for everything after it.
5. **`parseExponent` consumes-then-re-parses** — its loop `consumeValue()`s bits/bias/max/
   min, then the `return` re-`parseInt`s them from the now-advanced cursor (garbage →
   `InvalidCharacter`).

Net: making `.tri` drive codegen requires **an indentation-aware rewrite of `tri_reader`
first** — this is step 0, and it is a real parser project, not a patch. (Localised fixes
for 1/4/5 are correct but insufficient without 2+3, so they were not merged piecemeal.)

## What real spec-first generation would take (big, in order)

0. **Rewrite `tri_reader` into a real indentation-aware parser** (see the defect list
   above). Until `parse` returns the actual `storage.bits` / `exponent.{bits,bias,max}` /
   `phi.mantissa_bits`, nothing downstream can be spec-driven, and no spec↔code
   consistency check can be built.

1. ~~`tri_gen` leaked duped keys under the DebugAllocator~~ — **fixed** (parseSpec now
   frees the key each pass; `zig run tri_gen` exits 0). Done.

2. **Turn `tri_gen` into an actual generator.** This is the large task, not a small
   branch: replace each `_ = spec;` + template-copy with code that *emits* from the
   parsed `Spec` — storage width, `[sign|exp|mant]` field layout, bias, specials,
   `from_f32`/`to_f32`/arith bodies — for each of zig/c/rust/cpp. The current hand-
   written `gf16` template is the reference output for the binary path; `gf_binary.zig`'s
   comptime `GF(bits)` factory is effectively the algorithm to port into the emitter.

3. **Model the balanced-ternary exponent** in `tri_reader` (`Exponent` already has
   `trits`/`base`; add `offset_bias` + `offset_max` + `encoding`) and add the ternary
   branch to the (now real) emitter, with `from_f32` normalizing to `[1,2)`,
   `offset = e + offset_bias`, saturating at `offset_max`.

4. **Acceptance:** generated `gft16.zig` is byte-comparable to today's `gft.zig` and
   passes the existing GF-T tests unchanged; `check_tri_hashes --update` registers the
   new specs; CI `--verify` stays green.

## Recommendation

Steps 0 (a real `.tri` parser) and 2 (a genuine parameterized generator) are each
substantial rewrites, and step 0 blocks everything — including any spec↔code consistency
guard. They should be their own tracked effort, not squeezed into an autonomous
micro-increment. Until they exist, **the hand-written codecs are the correct engineering
state** — keep growing correctness/coverage/bindings there (exact-bit golden vectors,
cross-language conformance, the φ²-rule self-check all live in code, not the spec
pipeline), and treat "spec-first generation" as a separate, honestly-scoped project
rather than a per-loop task.
