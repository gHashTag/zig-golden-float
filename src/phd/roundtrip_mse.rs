//! BENCHMARK 1: Roundtrip MSE (encode → decode) per format
//!
//! Measures the mean squared error when encoding f32 values to target formats
//! and then decoding back to f32. This is a fundamental quantization quality metric.
//!
//! PhD deliverable: 12 data points (one per format)

use std::f64::consts::PI;
use std::fs::{self, File};
use std::io::Write;
use std::time::SystemTime;

const PHI: f64 = 1.618_033_988_749_895;
const SQRT_2: f64 = std::f64::consts::SQRT_2;
const E: f64 = std::f64::consts::E;

#[derive(Debug, Clone, Copy)]
struct FormatSpec {
    name: &'static str,
    exp_bits: u32,
    mantissa_bits: u32,
    #[allow(dead_code)]
    is_ieee: bool,  // true for IEEE formats, false for φ-based
}

const FORMATS: &[FormatSpec] = &[
    // IEEE formats
    FormatSpec { name: "fp32", exp_bits: 8,  mantissa_bits: 23, is_ieee: true },
    FormatSpec { name: "fp16", exp_bits: 5,  mantissa_bits: 10, is_ieee: true },
    FormatSpec { name: "bf16", exp_bits: 8,  mantissa_bits: 7,  is_ieee: true },
    // φ-based GoldenFloat formats
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

/// φ-optimal quantization: encode f64 to φ-based format
fn phi_quantize(val: f64, exp_bits: u32, mantissa_bits: u32) -> f64 {
    // Handle special cases
    if val == 0.0 { return 0.0; }
    if val.is_nan() { return f64::NAN; }
    if val.is_infinite() { return if val > 0.0 { f64::INFINITY } else { f64::NEG_INFINITY }; }

    let sign = val.signum();
    let abs_val = val.abs();

    // Maximum exponent value
    let max_exp: i32 = (1 << (exp_bits - 1)) - 1;
    let max_val = PHI.powi(max_exp);

    // Clamp to representable range
    let clamped = abs_val.min(max_val);

    // φ-log quantization: exponent in base-φ
    let phi_exp = clamped.ln() / PHI.ln();
    let quantized_exp = phi_exp.round();
    let exp_val = PHI.powf(quantized_exp);

    // Mantissa quantization: φ-ratio steps
    let _mantissa_steps = (1u64 << mantissa_bits) as f64;
    let phi_ratio = (1.0 / PHI).powi(mantissa_bits as i32);
    let mantissa_step = exp_val * phi_ratio;

    let mantissa_quant = ((clamped - exp_val) / mantissa_step).round() * mantissa_step;

    sign * (exp_val + mantissa_quant)
}

/// IEEE fp16 quantization via bit manipulation
fn ieee_fp16_quantize(val: f64) -> f64 {
    if val.is_nan() { return f64::NAN; }
    if val == 0.0 { return if val < 0.0 { -0.0 } else { 0.0 }; }

    let as_f32 = val as f32;
    let fp32_bits = as_f32.to_bits();

    let sign = (fp32_bits >> 31) & 1;
    let exp = ((fp32_bits >> 23) & 0xFF) as i32 - 127;
    let mant = fp32_bits & 0x7FFFFF;

    // fp16: 1 sign, 5 exponent (bias 15), 10 mantissa
    if exp > 15 {
        // Overflow
        if sign == 0 { f64::INFINITY } else { f64::NEG_INFINITY }
    } else if exp >= -14 {
        let fp16_exp = (exp + 15) as u16;
        let fp16_mant = (mant >> 13) as u16;
        let fp16_bits = ((sign as u16) << 15) | (fp16_exp << 10) | fp16_mant;
        f32::from_bits(fp16_bits as u32) as f64
    } else {
        // Subnormal or underflow
        if sign == 0 { 0.0 } else { -0.0 }
    }
}

/// BF16 quantization: truncate f32 mantissa to 7 bits
fn bf16_quantize(val: f64) -> f64 {
    if val.is_nan() { return f64::NAN; }
    let as_f32 = val as f32;
    let bf16_bits = as_f32.to_bits() & 0xFFFF_0000;
    f32::from_bits(bf16_bits) as f64
}

/// Run roundtrip MSE test for a single format
fn run_roundtrip_bench(spec: &FormatSpec, values: &[f64]) -> (f64, f64, f64) {
    let mut sum_sq_err = 0.0;
    let mut sum_abs_err = 0.0;
    let mut max_err: f64 = 0.0;

    for &v in values {
        if v.is_nan() || v.is_infinite() { continue; }

        let quantized = match spec.name {
            "fp32" => v,
            "fp16" => ieee_fp16_quantize(v),
            "bf16" => bf16_quantize(v),
            _ => phi_quantize(v, spec.exp_bits, spec.mantissa_bits),
        };

        if quantized.is_nan() || quantized.is_infinite() { continue; }

        let err = v - quantized;
        let abs_err = err.abs();
        sum_sq_err += err * err;
        sum_abs_err += abs_err;
        max_err = if abs_err > max_err { abs_err } else { max_err };
    }

    let n = values.len() as f64;
    (sum_sq_err / n, sum_abs_err / n, max_err)
}

/// Generate test values spanning different ranges
fn generate_test_values() -> Vec<f64> {
    let mut values = Vec::new();

    // Uniform samples across ranges
    for range in [(-10.0, 10.0), (-1.0, 1.0), (0.01, 100.0)] {
        let n = 1000;
        for i in 0..n {
            let t = i as f64 / (n - 1) as f64;
            let v = range.0 + (range.1 - range.0) * t;
            values.push(v);
        }
    }

    // Log-spaced samples (more dense near 0)
    for i in -100..100 {
        if i == 0 { continue; }
        let exp = i as f64 / 20.0;
        values.push(10.0_f64.powf(exp));
        values.push(-10.0_f64.powf(exp));
    }

    // Add sacred constants
    values.push(PI);
    values.push(E);
    values.push(PHI);
    values.push(SQRT_2);

    values
}

pub fn run() {
    println!("BENCHMARK 1: Roundtrip MSE (encode → decode) per format");
    println!("========================================================\n");

    let values = generate_test_values();
    println!("Test samples: {} values", values.len());
    println!("Range: [-10, 10] + log-spaced + sacred constants\n");

    let timestamp = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let mut csv_content = String::new();
    csv_content.push_str("format,mse,mae,max_abs_error,timestamp\n");

    println!("{:<12} {:>15} {:>15} {:>15}", "Format", "MSE", "MAE", "MaxAbsErr");
    println!("{:-<60}", "");

    for spec in FORMATS {
        let (mse, mae, max_err) = run_roundtrip_bench(spec, &values);

        println!("{:<12} {:>15.10} {:>15.10} {:>15.10}",
            spec.name, mse, mae, max_err);

        csv_content.push_str(&format!(
            "{},{:.15},{:.15},{:.15},{}\n",
            spec.name, mse, mae, max_err, timestamp
        ));
    }

    // Write CSV file
    let csv_path = "data/bench1_roundtrip_mse.csv";
    if let Some(parent) = std::path::Path::new(csv_path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let mut file = File::create(csv_path).expect("Failed to create CSV file");
    file.write_all(csv_content.as_bytes()).expect("Failed to write CSV");

    println!("\nResults written to: {}", csv_path);
    println!("Total data points: {}", FORMATS.len());
}
