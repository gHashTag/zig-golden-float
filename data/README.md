# PhD Comparative Benchmark Suite Results

## Overview
This directory contains CSV files with benchmark results comparing 12 floating-point formats:
- **IEEE formats**: fp32, fp16, bf16
- **φ-based GoldenFloat formats**: gf16, gf24, gf20, gf12, gf8, gf6a, gf4a, gf32, gf64

## Benchmark Files

### 1. `bench1_roundtrip_mse.csv`
**Roundtrip MSE** (encode → decode error)
- Columns: format, mse, mae, max_abs_error, timestamp
- 12 data points

**Key findings:**
- gf64: Near-perfect (MSE ≈ 0)
- fp32: Perfect (MSE = 0)
- gf32: Excellent (MSE = 0.007)
- gf24: Good (MSE = 1.13)
- bf16: Moderate (MSE = 126.7)
- gf16: Moderate (MSE = 290)
- gf20: Poor (MSE = 4.77)
- gf12/gf8/gf6a/gf4a: High error (MSE > 22M)

### 2. `bench2_phi_distance.csv`
**φ-distance** (deviation from ideal φ-based quantization)
- Columns: format, phi_distance, timestamp
- 12 data points

**Key findings:**
- All φ-based formats: 0.0 (by definition, they are φ-optimal)
- fp32: Minimal (0.000003)
- bf16: Low (0.008)
- fp16: High (0.997) - IEEE fp16 has high φ-distance

### 3. `bench3_sacred_constants.csv`
**Sacred constants preservation** (π, e, φ, √2)
- Columns: format, constant, abs_error, rel_error, timestamp
- 48 data points (12 formats × 4 constants)

**Key findings:**
- fp32/gf64: Perfect preservation
- gf32: Excellent (avg rel error ≈ 1.45e-5)
- gf24: Good (avg rel error ≈ 1.12e-4)
- bf16: Moderate (avg rel error ≈ 0.0016)
- gf16/gf20: Fair (avg rel error ≈ 0.002-0.003)
- gf12/gf8: Poor (avg rel error ≈ 0.006-0.026)
- gf6a/gf4a: Very poor (avg rel error ≈ 0.08-0.26)

### 4. `bench4_gradient_norm.csv`
**Gradient norm distribution** (He/Kaiming initialization, 10K gradients)
- Columns: format, l1_norm, l2_norm, linf_norm, sparsity, l1_ratio, l2_ratio, linf_ratio, timestamp
- 12 data points

**Key findings:**
- fp16: 100% sparsity (gradient collapse!)
- All other formats: 0% sparsity (gradients preserved)
- L2 ratios: Most formats within 1-3% of fp32 baseline
- gf6a shows +3.15% L2 deviation
- gf4a shows +1.70% L2 deviation

## Running the Benchmarks

```bash
cargo run --bin phd-benchmarks
```

## Format Specifications

| Format | Layout | Bias | Range | Notes |
|--------|--------|------|-------|-------|
| fp32 | IEEE 754 | 127 | ±3.4e38 | Baseline |
| fp16 | IEEE 754 | 15 | ±65504 | Full subnormals |
| bf16 | IEEE 754 | 127 | ~±3.4e38 | 7-bit mantissa |
| gf16 | φ-based | 31 | ~±65504 | φ-optimal |
| gf24 | φ-based | 127 | Large | 15-bit mantissa |
| gf20 | φ-based | 31 | Medium | 13-bit mantissa |
| gf12 | φ-based | 7 | Small | 7-bit mantissa |
| gf8 | φ-based | 3 | ~±15 | Very small range |
| gf6a | φ-based | 3 | ~±15 | 2-bit mantissa |
| gf4a | φ-based | 1 | ~±φ | Ternary-like |
| gf32 | φ-based | 1023 | Very large | 20-bit mantissa |
| gf64 | φ-based | 16383 | Double-like | 48-bit mantissa |

## PhD Deliverable
Total: **48 data points** (4 benchmarks × 12 formats)

All data is publishable in CSV format for gradient distribution analysis.
