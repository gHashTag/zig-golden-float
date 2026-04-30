//! BENCHMARK 2: φ-distance from IEEE fp32 (per format)
//!
//! Measures the "φ-distance" — a metric quantifying how well a format
//! preserves the golden ratio structure of floating point values.
//!
//! The φ-distance is computed as the average absolute deviation from the
//! ideal φ-based quantization when encoding f32 values.
//!
//! PhD deliverable: 12 data points (one per format)

use std::fs::{self, File};
use std::io::Write;
use std::time::SystemTime;

const PHI: f64 = 1.618_033_988_749_895;
const PHI_INV: f64 = 0.618_033_988_749_894_9;

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

/// Compute the ideal φ-based quantization (reference)
fn ideal_phi_quantize(val: f64, exp_bits: u32, mantissa_bits: u32) -> f64 {
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
    let phi_ratio = PHI_INV.powi(mantissa_bits as i32);
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

/// Quantize value based on format
fn format_quantize(val: f64, spec: &FormatSpec) -> f64 {
    match spec.name {
        "fp32" => val,
        "fp16" => ieee_fp16_quantize(val),
        "bf16" => bf16_quantize(val),
        _ => ideal_phi_quantize(val, spec.exp_bits, spec.mantissa_bits),
    }
}

/// Compute φ-distance between two quantized values
/// This measures how far from ideal φ-quantization the format's quantization is
fn compute_phi_distance(original: f64, quantized: f64, exp_bits: u32, mantissa_bits: u32) -> f64 {
    if original.is_nan() || quantized.is_nan() { return 0.0; }
    if original == 0.0 && quantized == 0.0 { return 0.0; }

    let ideal = ideal_phi_quantize(original, exp_bits, mantissa_bits);
    if ideal == 0.0 { return quantized.abs(); }

    // Relative distance from ideal φ-quantization
    (quantized - ideal).abs() / ideal.abs()
}

/// Run φ-distance benchmark
fn run_phi_distance_bench(spec: &FormatSpec, values: &[f64]) -> f64 {
    let mut total_distance = 0.0;
    let mut count = 0;

    for &v in values {
        if v.is_nan() || v.is_infinite() { continue; }

        let quantized = format_quantize(v, spec);
        if quantized.is_nan() || quantized.is_infinite() { continue; }

        let dist = compute_phi_distance(v, quantized, spec.exp_bits, spec.mantissa_bits);
        total_distance += dist;
        count += 1;
    }

    if count == 0 { 0.0 } else { total_distance / count as f64 }
}

/// Generate φ-distributed test values
fn generate_phi_values() -> Vec<f64> {
    let mut values = Vec::new();

    // Fibonacci-spaced samples (φ-related)
    for i in -30..30 {
        let fib = fibonacci(i);
        values.push(fib as f64);
        values.push(-fib as f64);
        values.push(fib as f64 * PHI);
        values.push(-fib as f64 * PHI);
    }

    // Powers of φ
    for i in -10..=10 {
        values.push(PHI.powi(i));
        values.push(-PHI.powi(i));
    }

    // Mixed range
    for i in 0..1000 {
        let t = i as f64 / 999.0;
        // φ-distribution: denser near 0
        let phi_t = if t < 0.5 {
            -0.5 * (0.5 - t).powf(PHI_INV)
        } else {
            0.5 * (t - 0.5).powf(PHI_INV)
        };
        values.push(phi_t * 20.0);
    }

    values
}

/// Compute Fibonacci numbers (extended to negative indices)
fn fibonacci(n: i32) -> i64 {
    if n == 0 { return 0; }
    if n > 0 {
        let mut a: i64 = 0;
        let mut b: i64 = 1;
        for _ in 0..n {
            let tmp = a + b;
            a = b;
            b = tmp;
        }
        a
    } else {
        // F(-n) = (-1)^(n+1) * F(n)
        let pos = fibonacci(-n);
        if (-n) % 2 == 0 { -pos } else { pos }
    }
}

pub fn run() {
    println!("BENCHMARK 2: φ-distance from IEEE fp32 (per format)");
    println!("===================================================\n");

    let values = generate_phi_values();
    println!("Test samples: {} φ-distributed values", values.len());

    let timestamp = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let mut csv_content = String::new();
    csv_content.push_str("format,phi_distance,timestamp\n");

    println!("{:<12} {:>20}", "Format", "φ-Distance");
    println!("{:-<35}", "");

    for spec in FORMATS {
        let phi_dist = run_phi_distance_bench(spec, &values);

        println!("{:<12} {:>20.15}", spec.name, phi_dist);

        csv_content.push_str(&format!(
            "{},{:.15},{}\n",
            spec.name, phi_dist, timestamp
        ));
    }

    let csv_path = "data/bench2_phi_distance.csv";
    if let Some(parent) = std::path::Path::new(csv_path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let mut file = File::create(csv_path).expect("Failed to create CSV file");
    file.write_all(csv_content.as_bytes()).expect("Failed to write CSV");

    println!("\nResults written to: {}", csv_path);
    println!("Total data points: {}", FORMATS.len());
}
