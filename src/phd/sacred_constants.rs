//! BENCHMARK 3: Sacred constants preservation (π, e, φ, √2)
//!
//! Measures how well each format preserves the exact values of fundamental
//! mathematical constants. This is critical for scientific and ML applications
//! where constants are used repeatedly in computations.
//!
//! Metrics:
//!   - Absolute error: |constant - roundtrip(constant)|
//!   - Relative error: |constant - roundtrip(constant)| / |constant|
//!
//! PhD deliverable: 12 data points (one per format)

use std::f64::consts::PI;
use std::fs::{self, File};
use std::io::Write;
use std::time::SystemTime;

const PHI: f64 = 1.618_033_988_749_895;
const SQRT_2: f64 = std::f64::consts::SQRT_2;
const E: f64 = std::f64::consts::E;

/// Sacred constants to test
const SACRED_CONSTANTS: &[(&str, f64)] = &[
    ("pi", PI),
    ("e", E),
    ("phi", PHI),
    ("sqrt2", SQRT_2),
];

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

/// Test sacred constant preservation
fn test_constant(spec: &FormatSpec, _name: &str, value: f64) -> (f64, f64) {
    let quantized = format_quantize(value, spec);
    let abs_err = (value - quantized).abs();
    let rel_err = if value != 0.0 { abs_err / value.abs() } else { abs_err };
    (abs_err, rel_err)
}

pub fn run() {
    println!("BENCHMARK 3: Sacred constants preservation (π, e, φ, √2)");
    println!("============================================================\n");

    let timestamp = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let mut csv_content = String::new();
    csv_content.push_str("format,constant,abs_error,rel_error,timestamp\n");

    // Header for display
    println!("{:<12} {:<10} {:>15} {:>15}", "Format", "Constant", "Abs Error", "Rel Error");
    println!("{:-<55}", "");

    for spec in FORMATS {
        let mut total_rel_error = 0.0;
        let mut count = 0;

        for (name, value) in SACRED_CONSTANTS {
            let (abs_err, rel_err) = test_constant(spec, name, *value);

            println!("{:<12} {:<10} {:>15.15} {:>15.15}",
                spec.name, name, abs_err, rel_err);

            csv_content.push_str(&format!(
                "{},{},{:.20},{:.20},{}\n",
                spec.name, name, abs_err, rel_err, timestamp
            ));

            total_rel_error += rel_err;
            count += 1;
        }

        let avg_rel_error = total_rel_error / count as f64;
        println!("  → Average relative error: {:.15}\n", avg_rel_error);
    }

    let csv_path = "data/bench3_sacred_constants.csv";
    if let Some(parent) = std::path::Path::new(csv_path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let mut file = File::create(csv_path).expect("Failed to create CSV file");
    file.write_all(csv_content.as_bytes()).expect("Failed to write CSV");

    println!("Results written to: {}", csv_path);
    println!("Total data points: {} ({} formats × {} constants)",
        FORMATS.len() * SACRED_CONSTANTS.len(),
        FORMATS.len(),
        SACRED_CONSTANTS.len()
    );
}
