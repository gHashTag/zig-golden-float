# zig-golden-float — Claude Code Instructions

**Repository:** https://github.com/gHashTag/zig-golden-float

## Project Overview

Pure Zig implementation of φ-optimized number formats for machine learning:
- **GF16**: Golden Float16 — [sign:1][exp:6][mant:9]
- **TF3**: Ternary Float3 — packed ternary format

**Mathematical Foundation:** φ² + 1/φ² = 3 (Trinity Identity)

## Architecture

### Source of Truth

```
.specs/*.tri → [tri_reader.zig] → tri_gen.zig → {c, rust, zig, cpp}/
     ↓
  .tri files are the DNA — all else is phenotype
```

### Specification Levels

| Level | Format | Capabilities |
|-------|--------|--------------|
| 0 — Format | GF16 | Basic: sign, exponent, mantissa, bias |
| 1 — Ops | GF16 | Arithmetic: add, mul, fma, div, sqrt |
| 2 — Composite | TF3 | Ternary: trit_mul, ternary_conv, dot_product |
| 3 — Hardware | GF16 | FPGA: pipeline stages, resource mapping |
| 4 — Training | GF16 | Training loop: forward/backward, optimizer |

### Key Files

| File | Purpose |
|------|---------|
| `specs/gf16.tri` | GF16 format specification |
| `specs/tf3.tri` | TF3 ternary format specification |
| `specs/ops.tri` | All arithmetic operations |
| `specs/TRI-HASHES.md` | SHA256 verification hashes |
| `src/formats/golden_float16.zig` | GF16/TF3 implementation |
| `tools/gen/tri_reader.zig` | .tri specification parser |
| `tools/gen/tri_gen.zig` | Multi-language code generator |
| `tools/gen/check_tri_hashes.zig` | Hash verification tool |

## Pipeline-First Development

**Golden Rule:** Every new format/operation starts with a .tri spec.

### Workflow

```
1. Create specs/your_format.tri
2. zig build test  (verify spec is valid)
3. zig run tri_gen --lang zig  (generate implementation)
4. Add tests to generated code
5. Commit: "feat(format): add your_format (#N)"
```

### When to Edit Direct Files

**Allowed direct edits (no .tri spec needed):**
- `src/sacred/` — Sacred constants (PHI, TRINITY)
- `src/vsa/` — VSA core operations
- `src/formats/golden_float16.zig` — Core GF16/TF3 implementation
- `tools/gen/` — Code generation infrastructure
- `build.zig` — Build system
- `CLAUDE.md` — This file

**Requires .tri spec first:**
- New number formats
- New arithmetic operations
- New composite operations (matmul, conv)
- Hardware mappings

## Pre-Commit Checklist

Before every commit:

1. **Verify hashes:** `zig run tools/gen/check_tri_hashes --verify`
2. **Format code:** `zig fmt src/ tools/ specs/`
3. **Run tests:** `zig build test`
4. **Build passes:** `zig build`

## Testing

```bash
# Run all tests
zig build test

# Run specific test
zig test src/formats/golden_float16.zig

# Test .tri spec parsing
zig run tools/gen/tri_reader --input specs/gf16.tri --verbose

# Generate code from spec
zig run tools/gen/tri_gen --lang all --dry-run
```

## Constants

| Symbol | Value | Description |
|--------|-------|-------------|
| PHI | 1.6180339887498948 | Golden ratio φ = (1 + √5) / 2 |
| PHI_SQ | 2.6180339887498948 | φ² |
| PHI_INV_SQ | 0.3819660112501051 | 1/φ² |
| TRINITY | 3.0 | φ² + 1/φ² = 3 (exact) |

## Phi-Distance

`|ratio - 1/φ|` — measures how close a format is to golden ratio optimum.

| Format | φ-distance | Rank |
|--------|------------|------|
| TF3-9 | 0.018 | 🥇 |
| **GF16** | **0.049** | 🥈 |
| IEEE f16 | 0.118 | 3rd |

## Commit Conventions

```
feat(scope): description (#N)
fix(scope): description (#N)
docs(scope): description
refactor(scope): description
test(scope): description
```

Examples:
- `feat(specs): Add ops.tri specification (#123)`
- `fix(build): Zig 0.15 compatibility (#124)`
- `docs(readme): Update installation instructions`

## External Links

- **Trinity Framework:** https://github.com/gHashTag/trinity
- **IBM DLFloat Paper:** https://research.ibm.com/publications/dlfloat-a-16-floating-point-format-designed-for-deep-learning-training-and-inference
- **Zig 0.15 Docs:** https://ziglang.org/documentation/0.15.2/

---

## AI Coding Rules (Legacy Russian Rules Below)

## 0. Главная идея

В этом репозитории **источником правды** являются `.tri`‑спеки, а не Zig‑код.

- Все числовые форматы (GF16, TF3 и т.п.) и операции над ними описываются в `specs/*.tri`.
- Файлы на Zig, C, Rust, C++ считаются _производными артефактами_, которые должны генерироваться из `.tri` с помощью `tools/gen/tri_gen.zig`.
- Ручное редактирование Zig‑кода допустимо **только** внутри строго ограниченного ядра (TTT), см. ниже.

Если вы — AI‑агент (Claude Code или другой), **не пишите новый Zig‑код напрямую**, кроме явно разрешённых мест.

---

## 1. Где Zig разрешён

Разрешено писать и редактировать Zig‑код **только** в следующих областях:

- ядро числовых форматов и TTT:
  - `tools/gen/tri_reader.zig` — парсер формата `.tri`;
  - `tools/gen/tri_gen.zig` — генератор кода из `.tri`;
  - `src/formats/golden_float16.zig` — минимальные runtime‑обёртки вокруг сгенерированных форматов (GF16, TF3);
  - специализированное ядро TTT/TF3/GF16, если оно прямо помечено в комментариях как "core TTT kernel".

Во всех этих файлах Zig‑код рассматривается как **часть компилятора/ядра** и может развиваться вручную.

---

## 2. Где Zig ЗАПРЕЩЁН

Во всех остальных частях репозитория:

- нельзя добавлять новые `.zig`‑файлы;
- нельзя писать "ручную" арифметику GF16/TF3, конвертеры, VSA‑операции и т.п.;
- нельзя править сгенерированные Zig‑файлы вместо правки `.tri`.

Если нужно:

- новый формат,
- новая операция (add/mul/fma/sqrt/cmp/min/max),
- VSA‑операция (dot/bind/bundle),
- пример использования,

**сначала измените/добавьте `.tri`‑спеку**, затем вызовите генератор:

```bash
zig run tools/gen/tri_gen --lang all --input specs/gf16.tri
zig run tools/gen/tri_gen --lang all --input specs/tf3.tri
```

AI‑агентам: любые изменения в API чисел делайте через `.tri` + `tri_gen`, а не напрямую в `.zig`.

---

## 3. TRI seals: обязательная проверка

Перед любым коммитом, который меняет `.tri`:

1. Запусти:
   ```bash
   zig run tools/gen/check_tri_hashes --verify
   ```
2. Если скрипт показывает mismatch, сначала запусти режим обновления:
   ```bash
   zig run tools/gen/check_tri_hashes --update
   ```
   который пересчитает SHA256 для всех известных .tri и перезаписывает `specs/TRI-HASHES.md`.
3. Повтори проверку — она должна завершиться без ошибок.
4. Только после этого коммить изменения.

AI-агентам:
- Нельзя коммитить изменения в `specs/*.tri`, если `check_tri_hashes` сообщает рассинхрон.
- Нельзя править `specs/TRI-HASHES.md` вручную — только через `--update`.

---

## 4. Правильно/Неправильно

| Неправильно ❌ | Правильно ✓ |
|----------------|-------------|
| Добавить `fn gf16_add` в `src/gf16.zig` | Добавить `ops.add` в `specs/gf16.tri`, запустить `tri_gen` |
| Написать VSA bind вручную в Zig | Добавить `vsa_bind` в `specs/tf3.tri`, регенерировать |
| Править сгенерированный `.zig` | Править `.tri`, заново сгенерировать |
| Забыть обновить TRI-HASHES.md | `zig run tools/gen/check_tri_hashes --update` перед коммитом |

---

## 5. Цель таких правил

- Гарантировать, что вся арифметика GF16/TF3 и VSA‑операции описаны **одним стандартом** (`.tri`) и консистентно реализованы во всех языках.
- Избежать "дрейфа реализаций", когда C, Rust, Zig и C++ начинают вести себя по‑разному.
- Постепенно **переписать существующий ручной Zig‑код на `.tri` → tri_gen**, чтобы репозиторий стал максимально декларативным и генеративным.

Если вы не уверены, можно ли править конкретный `.zig`‑файл, считайте, что **нельзя**, и сначала ищите соответствующую `.tri`‑спеку или создайте новую.
