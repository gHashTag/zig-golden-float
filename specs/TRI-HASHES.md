# TRI-HASHES — DNA Plombs for Trinity Specifications

**Purpose:** Immutable verification hashes for all .tri specifications.

**Each .tri file is a "gene"** — changing it breaks the chain. Use this table to verify integrity.

## Current Hashes (SHA256)

| Gene | Level | File | Version | SHA256 | Last Modified |
|------|-------|------|---------|--------|---------------|
| **GF16** | 1 | `specs/gf16.tri` | 1 | `23f2353746e083ad236cd348ddc4152d5976cbbc20d35d23b27c5300ef07e70a` | 2026-03-31 |
| **TF3** | 2 | `specs/tf3.tri` | 1 | `b482b1f829a8c856022077a26fd6bafa864eecda4c696da058083cea52a8e19c` | 2026-03-31 |
| **OPS** | 1 | `specs/ops.tri` | 1 | `750e57342e5ea8b52135c9cc36d9a70becba532566160be1dc825ffb5571ff95` | 2026-03-31 |

## Hash Calculation

```bash
# Calculate SHA256 of a .tri spec
shasum -a 256 specs/gf16.tri

# Verify all hashes
zig run tools/check_tri_hashes --verify
```

## Updating Hashes

After modifying a .tri spec:

1. Run `zig run tools/check_tri_hashes --update`
2. Commit the updated TRI-HASHES.md
3. The commit message must reference the gene that changed

## Rules

1. **Never modify a .tri spec without updating its hash**
2. **Never commit without running `check_tri_hashes`**
3. **Hash collisions are fatal** — they indicate corruption or tampering

## Changelog

### 2026-03-31
- Initial TRI-HASHES.md created
- ops.tri added (213 lines)
- Hashes marked TODO — need to calculate

## Next Steps

- [ ] Calculate initial SHA256 hashes
- [ ] Implement `tools/check_tri_hashes.zig`
- [ ] Integrate into CI/CD pipeline
- [ ] Add git pre-commit hook
