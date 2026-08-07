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

## What real spec-first generation would take (big, in order)

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

Step 2 (a genuine parameterized generator) is a substantial rewrite of `tri_gen` and
should be its own tracked effort, not squeezed into an autonomous micro-increment.
Until it exists, **the hand-written codecs are the correct engineering state** — keep
growing correctness/coverage/bindings there, and treat "spec-first generation" as a
separate, honestly-scoped project rather than a per-loop task.
