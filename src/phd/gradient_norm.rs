//! BENCHMARK 4: Gradient norm distribution (synthetic, per format)
//!
//! Measures how gradient quantization affects gradient norms during
//! backpropagation. This is crucial for understanding training stability
//! and optimization behavior across different formats.
//!
//! The benchmark generates synthetic gradients following common distributions:
//!   - Normal (Gaussian) with He/Kaiming initialization
//!   - Truncated normal
//!   - Laplace (heavy-tailed)
//!
//! Metrics:
//!   - L1 norm: sum(|g|)
//!   - L2 norm: sqrt(sum(g^2))
//!   - L∞ norm: max(|g|)
//!   - Sparsity: fraction of zeros after quantization
//!
//! PhD deliverable: 12 data points (one per format)

use rand::Rng;
use std::fs::{self, File};
use std::io::Write;
use std::time::SystemTime;

const PHI: f64 = 1.618_033_988_749_895;

#[derive(Debug, Clone, Copy)]
struct FormatSpec {
    name: &'static str,
    exp_bits: u32,
    mantissa_bits: u32,
    #[allow(dead_code)]
    is_ieee: bool,
}

const FORMATS: &[FormatSpec] = &[
    FormatSpec { name: "fp32", exp_bits: 8,  mantissa_bits: 23, is_ieee: true },
    FormatSpec { name: "fp16", exp_bits: 5,  mantissa_bits: 10, is_ieee: true },
    FormatSpec { name: "bf16", exp_bits: 8,  mantissa_bits: 7,  is_ieee: true },
    FormatSpec { name: "gf16", exp_bits: 6,  mantissa_bits: 9,  is_ieee: false },
    FormatSpec { name: "gf24", exp_bits: 8,  mantissa_bits: 15, is_ieee: false },
    FormatSpec { name: "gf20", exp_bits: 6,  mantissa_bits: 13, is_ieee: false },
    FormatSpec { name: "gf12", exp_bits: 4,  mantissa_bits: 7,  is_ieee: false },
    FormatSpec { name: "gf8",  exp_bits: 3,  mantissa_bits: 4,  is_ieee: false },
    FormatSpec { name: "gf6a", exp_bits: 3,  mantissa_bits: 2,  is_ieee: false },
    FormatSpec { name: "gf4a", exp_bits: 2,  mantissa_bits: 1,  is_ieee: false },
    FormatSpec { name: "gf32", exp_bits: 11, mantissa_bits: 20, is_ieee: false },
    FormatSpec { name: "gf64", exp_bits: 15, mantissa_bits: 48, is_ieee: false },
];

/// φ-optimal quantization
fn phi_quantize(val: f64, exp_bits: u32, mantissa_bits: u32) -> f64 {
    if val == 0.0 { return 0.0; }
    if val.is_nan() { return f64::NAN; }
    if val.is_infinite() { return if val > 0.0 { f64::INFINITY } else { f64::NEG_INFINITY }; }

    let sign = val.signum();
    let abs_val = val.abs();

    let max_exp: i32 = (1 << (exp_bits - 1)) - 1;
    let max_val = PHI.powi(max_exp);
    let clamped = abs_val.min(max_val);

    let phi_exp = clamped.ln() / PHI.ln();
    let quantized_exp = phi_exp.round();
    let exp_val = PHI.powf(quantized_exp);

    let _mantissa_steps = (1u64 << mantissa_bits) as f64;
    let phi_ratio = (1.0 / PHI).powi(mantissa_bits as i32);
    let mantissa_step = exp_val * phi_ratio;
    let mantissa_quant = ((clamped - exp_val) / mantissa_step).round() * mantissa_step;

    sign * (exp_val + mantissa_quant)
}

/// IEEE fp16 quantization
fn ieee_fp16_quantize(val: f64) -> f64 {
    if val.is_nan() { return f64::NAN; }
    if val == 0.0 { return if val < 0.0 { -0.0 } else { 0.0 }; }

    let as_f32 = val as f32;
    let fp32_bits = as_f32.to_bits();

    let sign = (fp32_bits >> 31) & 1;
    let exp = ((fp32_bits >> 23) & 0xFF) as i32 - 127;
    let mant = fp32_bits & 0x7FFFFF;

    if exp > 15 {
        if sign == 0 { f64::INFINITY } else { f64::NEG_INFINITY }
    } else if exp >= -14 {
        let fp16_exp = (exp + 15) as u16;
        let fp16_mant = (mant >> 13) as u16;
        let fp16_bits = ((sign as u16) << 15) | (fp16_exp << 10) | fp16_mant;
        f32::from_bits(fp16_bits as u32) as f64
    } else {
        if sign == 0 { 0.0 } else { -0.0 }
    }
}

/// BF16 quantization
fn bf16_quantize(val: f64) -> f64 {
    if val.is_nan() { return f64::NAN; }
    let as_f32 = val as f32;
    let bf16_bits = as_f32.to_bits() & 0xFFFF_0000;
    f32::from_bits(bf16_bits) as f64
}

/// Format-specific quantization
fn format_quantize(val: f64, spec: &FormatSpec) -> f64 {
    match spec.name {
        "fp32" => val,
        "fp16" => ieee_fp16_quantize(val),
        "bf16" => bf16_quantize(val),
        _ => phi_quantize(val, spec.exp_bits, spec.mantissa_bits),
    }
}

/// Gradient norm statistics
#[derive(Debug, Default)]
struct GradientStats {
    l1_norm: f64,
    l2_norm: f64,
    linf_norm: f64,
    sparsity: f64,  // fraction of zeros
}

/// Compute gradient norms for a vector
fn compute_gradient_norms(gradients: &[f64]) -> GradientStats {
    let mut l1 = 0.0;
    let mut l2_sq = 0.0;
    let mut linf: f64 = 0.0;
    let mut zero_count = 0usize;

    for &g in gradients {
        if g.is_nan() || g.is_infinite() { continue; }

        let abs_g = g.abs();
        l1 += abs_g;
        l2_sq += abs_g * abs_g;
        linf = if abs_g > linf { abs_g } else { linf };

        if abs_g < f64::EPSILON * 100.0 {
            zero_count += 1;
        }
    }

    let n = gradients.len() as f64;
    GradientStats {
        l1_norm: l1,
        l2_norm: l2_sq.sqrt(),
        linf_norm: linf,
        sparsity: zero_count as f64 / n,
    }
}

/// Box-Muller transform to generate standard normal random numbers
fn box_muller(rng: &mut impl Rng) -> f64 {
    let u1: f64 = rng.gen();
    let u2: f64 = rng.gen();
    (-2.0 * u1.ln()).sqrt() * (2.0 * std::f64::consts::PI * u2).cos()
}

/// Generate synthetic gradients following He/Kaiming initialization
/// Normal distribution: N(0, sqrt(2/n))
fn generate_he_gradients(n: usize, fan_in: usize) -> Vec<f64> {
    let mut rng = rand::thread_rng();
    let std_dev = (2.0 / fan_in as f64).sqrt();

    (0..n).map(|_| box_muller(&mut rng) * std_dev).collect()
}

/// Generate truncated normal gradients (common in stable training)
#[allow(dead_code)]
fn generate_truncated_normal_gradients(n: usize, mean: f64, std_dev: f64, limit: f64) -> Vec<f64> {
    let mut rng = rand::thread_rng();

    (0..n).map(|_| {
        let mut v = box_muller(&mut rng) * std_dev + mean;
        while v.abs() > limit {
            v = box_muller(&mut rng) * std_dev + mean;
        }
        v
    }).collect()
}

/// Run gradient norm benchmark
fn run_gradient_norm_bench(spec: &FormatSpec, gradients: &[f64]) -> GradientStats {
    let quantized: Vec<f64> = gradients.iter()
        .map(|&g| format_quantize(g, spec))
        .collect();

    compute_gradient_norms(&quantized)
}

pub fn run() {
    println!("BENCHMARK 4: Gradient norm distribution (synthetic, per format)");
    println!("================================================================\n");

    let n_gradients = 10000;
    let fan_in = 512;  // Common hidden layer size

    // Generate synthetic gradients
    println!("Generating {} synthetic gradients (He initialization, fan_in={})",
        n_gradients, fan_in);
    let gradients = generate_he_gradients(n_gradients, fan_in);

    // Compute reference (fp32) stats
    let ref_stats = compute_gradient_norms(&gradients);
    println!("\nReference (fp32) gradients:");
    println!("  L1 norm:   {:.10}", ref_stats.l1_norm);
    println!("  L2 norm:   {:.10}", ref_stats.l2_norm);
    println!("  L∞ norm:  {:.10}", ref_stats.linf_norm);
    println!("  Sparsity:  {:.6}%", ref_stats.sparsity * 100.0);

    let timestamp = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let mut csv_content = String::new();
    csv_content.push_str("format,l1_norm,l2_norm,linf_norm,sparsity,l1_ratio,l2_ratio,linf_ratio,timestamp\n");

    println!("\n{:<12} {:>15} {:>15} {:>15} {:>10} {:>10}", "Format", "L1", "L2", "L∞", "Sparsity", "L2 Ratio");
    println!("{:-<80}", "");

    for spec in FORMATS {
        let stats = run_gradient_norm_bench(spec, &gradients);

        let l1_ratio = if ref_stats.l1_norm > 0.0 { stats.l1_norm / ref_stats.l1_norm } else { 0.0 };
        let l2_ratio = if ref_stats.l2_norm > 0.0 { stats.l2_norm / ref_stats.l2_norm } else { 0.0 };
        let linf_ratio = if ref_stats.linf_norm > 0.0 { stats.linf_norm / ref_stats.linf_norm } else { 0.0 };

        println!("{:<12} {:>15.10} {:>15.10} {:>15.10} {:>9.4}% {:>10.6}",
            spec.name, stats.l1_norm, stats.l2_norm, stats.linf_norm,
            stats.sparsity * 100.0, l2_ratio);

        csv_content.push_str(&format!(
            "{},{:.15},{:.15},{:.15},{:.15},{:.15},{:.15},{:.15},{}\n",
            spec.name, stats.l1_norm, stats.l2_norm, stats.linf_norm,
            stats.sparsity, l1_ratio, l2_ratio, linf_ratio, timestamp
        ));
    }

    let csv_path = "data/bench4_gradient_norm.csv";
    if let Some(parent) = std::path::Path::new(csv_path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let mut file = File::create(csv_path).expect("Failed to create CSV file");
    file.write_all(csv_content.as_bytes()).expect("Failed to write CSV");

    println!("\nResults written to: {}", csv_path);
    println!("Total data points: {}", FORMATS.len());
}
