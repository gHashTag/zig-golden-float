//! BENCH-007b: φ-Distance Extended Range Benchmark
//!
//! Purpose: Re-run BENCH-007 on range [-10, 10] to differentiate MSE/MAE
//! across GF8/GF16/GF32/GF64 formats. BENCH-007 used [-1,1] where all
//! formats showed identical MSE=0.00329 / MAE=0.0496 due to limited dynamic range.
//!
//! Hypothesis: GF8 (3-bit exponent, max_val ≈ 15.0) should show significantly
//! higher MSE than GF64 at larger input range due to lower dynamic range and
//! coarser quantization step.
//!
//! Expected results:
//!   GF8    MSE >> GF16  (3-bit exp limits range, 4-bit mantissa coarser)
//!   GF16   MSE < GF8    (6-bit exp, 9-bit mantissa)
//!   GF32   MSE ≈ FP32   (13-bit exp, 18-bit mantissa)
//!   GF64   MSE ≈ 0      (21-bit exp, 42-bit mantissa, double precision)
//!
//! Results saved to: .trinity/results/bench_007b_extended_range.log
//!
//! Cross-reference: whitepaper.md §9.5 BENCH-007b, issue #12

use std::f64::consts::SQRT_2;

const PHI: f64 = 1.6180339887498948482;
const PHI_INV: f64 = 0.6180339887498948482;

// ── Format specs ────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy)]
struct FormatSpec {
    name: &'static str,
    exp_bits: u32,
    mantissa_bits: u32,
    phi_distance: f64, // from BENCH-007
}

const FORMATS: &[FormatSpec] = &[
    FormatSpec { name: "f32",       exp_bits: 8,  mantissa_bits: 23, phi_distance: 0.000 },
    FormatSpec { name: "GF8",       exp_bits: 3,  mantissa_bits: 4,  phi_distance: 0.132 },
    FormatSpec { name: "GF16",      exp_bits: 6,  mantissa_bits: 9,  phi_distance: 0.049 },
    FormatSpec { name: "GF32",      exp_bits: 13, mantissa_bits: 18, phi_distance: 0.340 },
    FormatSpec { name: "GF64",      exp_bits: 21, mantissa_bits: 42, phi_distance: 0.264 },
    FormatSpec { name: "fp16",      exp_bits: 5,  mantissa_bits: 10, phi_distance: 0.118 },
    FormatSpec { name: "bf16",      exp_bits: 8,  mantissa_bits: 7,  phi_distance: 0.525 },
    FormatSpec { name: "GFTernary", exp_bits: 0,  mantissa_bits: 1,  phi_distance: 0.000 },
];

// ── φ-optimal quantization (same logic as BENCH-007) ─────────────────────

fn phi_quantize(val: f64, exp_bits: u32, mantissa_bits: u32) -> f64 {
    if exp_bits == 0 {
        // GFTernary: {-φ, 0, +φ}
        if val > PHI / 2.0 { return PHI; }
        if val < -PHI / 2.0 { return -PHI; }
        return 0.0;
    }

    let max_exp: i32 = (1 << (exp_bits - 1)) - 1;
    let max_val = PHI.powi(max_exp);
    let clamped = val.clamp(-max_val, max_val);

    if clamped == 0.0 { return 0.0; }

    let sign = clamped.signum();
    let abs_val = clamped.abs();

    // φ-log quantization: exponent in base-φ
    let phi_exp = abs_val.ln() / PHI.ln();
    let quantized_exp = phi_exp.round();
    let exp_val = PHI.powf(quantized_exp);

    // Mantissa quantization: φ-ratio steps
    let mantissa_steps = (1u64 << mantissa_bits) as f64;
    let phi_ratio = PHI_INV.powi(mantissa_bits as i32);
    let mantissa_step = exp_val * phi_ratio;
    let mantissa_quant = ((abs_val - exp_val) / mantissa_step).round() * mantissa_step;

    sign * (exp_val + mantissa_quant)
}

fn ieee_fp16_quantize(val: f64) -> f64 {
    // Simulate IEEE fp16 (1:5:10) via f32 cast chain
    let as_f32 = val as f32;
    // fp16 has ~3 decimal digits precision, range ±65504
    let fp16_bits = as_f32.to_bits();
    // Truncate mantissa to 10 bits (drop lower 13 bits of f32 mantissa)
    let truncated = fp16_bits & 0xFFFF_E000;
    f32::from_bits(truncated) as f64
}

fn bf16_quantize(val: f64) -> f64 {
    // BF16 (1:8:7): truncate f32 mantissa to 7 bits (drop lower 16 bits)
    let as_f32 = val as f32;
    let bf16_bits = as_f32.to_bits() & 0xFFFF_0000;
    f32::from_bits(bf16_bits) as f64
}

// ── Benchmark runner ────────────────────────────────────────────────────────

#[derive(Debug)]
struct BenchResult {
    format: &'static str,
    range_label: &'static str,
    mse: f64,
    mae: f64,
    max_abs_err: f64,
    phi_distance: f64,
    dynamic_range_ok: bool, // true if format can represent range without saturation
    sample_count: usize,
}

fn run_benchmark(spec: &FormatSpec, values: &[f64], range_label: &'static str) -> BenchResult {
    let mut sum_sq_err = 0.0f64;
    let mut sum_abs_err = 0.0f64;
    let mut max_abs_err = 0.0f64;
    let mut saturated_count = 0usize;

    // Max representable value for this format
    let max_representable = if spec.exp_bits == 0 {
        PHI // GFTernary
    } else {
        let max_exp: i32 = (1 << (spec.exp_bits - 1)) - 1;
        PHI.powi(max_exp)
    };

    for &v in values {
        let quantized = match spec.name {
            "f32" => v,
            "fp16" => ieee_fp16_quantize(v),
            "bf16" => bf16_quantize(v),
            _ => phi_quantize(v, spec.exp_bits, spec.mantissa_bits),
        };

        if v.abs() > max_representable { saturated_count += 1; }

        let err = v - quantized;
        sum_sq_err += err * err;
        sum_abs_err += err.abs();
        if err.abs() > max_abs_err { max_abs_err = err.abs(); }
    }

    let n = values.len() as f64;
    BenchResult {
        format: spec.name,
        range_label,
        mse: sum_sq_err / n,
        mae: sum_abs_err / n,
        max_abs_err,
        phi_distance: spec.phi_distance,
        dynamic_range_ok: saturated_count == 0,
        sample_count: values.len(),
    }
}

// ── Test ranges ─────────────────────────────────────────────────────────────

fn linspace(start: f64, end: f64, n: usize) -> Vec<f64> {
    (0..n).map(|i| start + (end - start) * i as f64 / (n - 1) as f64).collect()
}

fn phi_spaced(start: f64, end: f64, n: usize) -> Vec<f64> {
    // φ-spaced samples: denser near 0, sparser at extremes (like real weight distributions)
    (0..n).map(|i| {
        let t = i as f64 / (n - 1) as f64;
        // Transform: use φ-distribution for sample density
        let phi_t = if t < 0.5 {
            -(0.5 - t).powf(PHI_INV) * (end - start) / 2.0
        } else {
            (t - 0.5).powf(PHI_INV) * (end - start) / 2.0
        };
        phi_t.clamp(start, end)
    }).collect()
}

// ── Main ────────────────────────────────────────────────────────────────────

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let format_filter: Option<Vec<&str>> = if args.len() > 1 {
        let mut found = false;
        for arg in &args[1..] {
            if arg.starts_with("--formats=") {
                found = true;
                break;
            }
        }
        if found {
            let formats_arg = args.iter().find(|a| a.starts_with("--formats=")).unwrap();
            let formats_str = &formats_arg["--formats=".len()..];
            Some(formats_str.split(',').map(|s| s.trim()).collect())
        } else {
            None
        }
    } else {
        None
    };

    let active_formats: Vec<&FormatSpec> = if let Some(ref filter) = format_filter {
        FORMATS.iter().filter(|f| filter.contains(&f.name)).collect()
    } else {
        FORMATS.iter().collect()
    };

    if active_formats.is_empty() {
        eprintln!("No matching formats. Available: f32, fp16, gf8, GF8, GF16, GF32, GF64, bf16, GFTernary");
        eprintln!("Usage: {} [--formats=f32,fp16,gf8,gf16]", args[0]);
        std::process::exit(1);
    }

    println!("BENCH-007b: φ-Distance Extended Range Benchmark");
    println!("================================================");
    if let Some(ref filter) = format_filter {
        println!("Formats filter: {}", filter.join(","));
    } else {
        println!("Formats: all");
    }
    println!("Cross-reference: whitepaper.md §9.5, issue #12");
    println!();

    // Test ranges for BENCH-007b
    let ranges: &[(&'static str, f64, f64)] = &[
        ("[-1,1]  (BENCH-007 baseline)",  -1.0,   1.0),
        ("[-10,10] (BENCH-007b target)",  -10.0,  10.0),
        ("[-100,100] (stress test)",      -100.0, 100.0),
        ("φ-distributed [-10,10]",        -10.0,  10.0),  // φ-spaced
    ];

    let n_samples = 10_000usize;

    let mut all_results: Vec<BenchResult> = Vec::new();

    for (range_idx, (label, start, end)) in ranges.iter().enumerate() {
        let values: Vec<f64> = if range_idx == 3 {
            phi_spaced(*start, *end, n_samples)
        } else {
            linspace(*start, *end, n_samples)
        };

        println!("Range: {}", label);
        println!("{:-<70}", "");
        println!("{:<12} {:>10} {:>10} {:>12} {:>10} {:>6}",
            "Format", "MSE", "MAE", "MaxAbsErr", "φ-dist", "InRange");
        println!("{:-<70}", "");

        let mut range_results: Vec<BenchResult> = active_formats.iter()
            .map(|spec| run_benchmark(spec, &values, label))
            .collect();

        // Sort by MSE for display
        range_results.sort_by(|a, b| a.mse.partial_cmp(&b.mse).unwrap());

        for r in &range_results {
            let in_range = if r.dynamic_range_ok { "✓" } else { "CLIP" };
            println!("{:<12} {:>10.6} {:>10.6} {:>12.6} {:>10.3} {:>6}",
                r.format, r.mse, r.mae, r.max_abs_err, r.phi_distance, in_range);
        }
        println!();

        all_results.extend(range_results);
    }

    // ── φ-distance vs MSE correlation analysis ───────────────────────────
    println!("φ-Distance vs MSE Correlation (range [-10,10], n={})", n_samples);
    println!("{:-<70}", "");
    println!("Hypothesis: formats with lower φ-distance should have lower quantization error");
    println!("(on φ-distributed inputs that match the format's mathematical basis)");
    println!();

    let range_10_results: Vec<&BenchResult> = all_results.iter()
        .filter(|r| r.range_label.contains("[-10,10]") && !r.range_label.contains("φ-dist"))
        .collect();

    if !range_10_results.is_empty() {
        let phi_dists: Vec<f64> = range_10_results.iter().map(|r| r.phi_distance).collect();
        let mses: Vec<f64> = range_10_results.iter().map(|r| r.mse).collect();

        let n = phi_dists.len() as f64;
        let mean_pd = phi_dists.iter().sum::<f64>() / n;
        let mean_mse = mses.iter().sum::<f64>() / n;

        let cov: f64 = phi_dists.iter().zip(mses.iter())
            .map(|(pd, mse)| (pd - mean_pd) * (mse - mean_mse))
            .sum::<f64>() / n;

        let std_pd = (phi_dists.iter().map(|pd| (pd - mean_pd).powi(2)).sum::<f64>() / n).sqrt();
        let std_mse = (mses.iter().map(|mse| (mse - mean_mse).powi(2)).sum::<f64>() / n).sqrt();

        if std_pd > 0.0 && std_mse > 0.0 {
            let pearson_r = cov / (std_pd * std_mse);
            println!("Pearson r (φ-distance vs MSE) = {:.4}", pearson_r);
            if pearson_r > 0.5 {
                println!("→ CONFIRMED: Higher φ-distance correlates with higher MSE ✓");
            } else if pearson_r < -0.5 {
                println!("→ INVERTED: Lower φ-distance has higher MSE — unexpected");
            } else {
                println!("→ WEAK correlation — MSE dominated by bit-width, not φ-alignment");
            }
        }
    }

    println!();

    // ── GF family ranking by MSE at [-10, 10] ───────────────────────────
    println!("GF Family MSE Ranking at [-10, 10]:");
    println!("{:-<50}", "");

    let mut gf_results: Vec<&BenchResult> = all_results.iter()
        .filter(|r| {
            r.range_label.contains("[-10,10]") &&
            !r.range_label.contains("φ-dist") &&
            (r.format.starts_with("GF") || r.format == "fp16" || r.format == "bf16")
        })
        .collect();

    gf_results.sort_by(|a, b| a.mse.partial_cmp(&b.mse).unwrap());

    for (rank, r) in gf_results.iter().enumerate() {
        let medal = match rank { 0 => "🥇", 1 => "🥈", 2 => "🥉", _ => "  " };
        let clip_note = if !r.dynamic_range_ok { " ← SATURATES" } else { "" };
        println!("{} {:>2}. {:<12} MSE={:.6}  φ-dist={:.3}{}",
            medal, rank + 1, r.format, r.mse, r.phi_distance, clip_note);
    }

    println!();
    println!("Results: .trinity/results/bench_007b_extended_range.log");
    println!("Next: BENCH-008 Fashion-MNIST validation");
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_phi_quantize_within_range() {
        // GF8 max_val = φ^7 ≈ 29.0 — should handle [-10, 10] without saturation
        let max_exp_gf8: i32 = (1 << (3u32 - 1)) - 1; // = 3
        let max_val_gf8 = PHI.powi(max_exp_gf8);
        assert!(max_val_gf8 > 10.0, "GF8 max_val={} should cover [-10,10]", max_val_gf8);
    }

    #[test]
    fn test_ternary_range() {
        assert_eq!(phi_quantize(5.0, 0, 1), PHI);
        assert_eq!(phi_quantize(-5.0, 0, 1), -PHI);
        assert_eq!(phi_quantize(0.0, 0, 1), 0.0);
    }

    #[test]
    fn test_gf16_better_than_gf8_at_wide_range() {
        let values: Vec<f64> = (-100..=100).map(|i| i as f64 * 0.1).collect();
        let gf8_spec  = FormatSpec { name: "GF8",  exp_bits: 3,  mantissa_bits: 4,  phi_distance: 0.132 };
        let gf16_spec = FormatSpec { name: "GF16", exp_bits: 6,  mantissa_bits: 9,  phi_distance: 0.049 };
        let r8  = run_benchmark(&gf8_spec,  &values, "test");
        let r16 = run_benchmark(&gf16_spec, &values, "test");
        // GF16 should have lower MSE than GF8 on [-10, 10] range
        assert!(r16.mse <= r8.mse,
            "Expected GF16 MSE ({}) <= GF8 MSE ({}) on wide range", r16.mse, r8.mse);
    }

    #[test]
    fn test_linspace_endpoints() {
        let v = linspace(-10.0, 10.0, 5);
        assert!((v[0] - (-10.0)).abs() < 1e-10);
        assert!((v[4] - 10.0).abs() < 1e-10);
    }

    #[test]
    fn test_bench007b_baseline_matches_bench007() {
        // On [-1, 1] all GF formats should still show low MSE (matching BENCH-007)
        let values = linspace(-1.0, 1.0, 1000);
        let gf16_spec = FormatSpec { name: "GF16", exp_bits: 6, mantissa_bits: 9, phi_distance: 0.049 };
        let r = run_benchmark(&gf16_spec, &values, "[-1,1]");
        assert!(r.mse < 0.01, "GF16 MSE on [-1,1] should be < 0.01, got {}", r.mse);
    }
}
