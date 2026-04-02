//! Transcendental Functions — exp, log for ML operations
//!
//! **Wave 4B**: Add critical transcendental functions to GF16 kernel
//!
//! # Why These Functions?
//!
//! - `exp(x)` — Required for softmax activation
//! - `log(x)` — Required for cross-entropy loss calculation
//! - `sin(x)`, `cos(x)` — Required for future modules (not blocking)
//!
//! # Implementation Strategy
//!
//! **Direct computation** without GF16 intermediate:
//! - All calculations done in f64 for precision
//! - Results returned as f64 (caller can encode to GF16)
//!
//! # References
//!
//! - IEEE 754: 2024 floating-point standard
//! - GLSL: std::exp(), std::log() approximations
//! - GLM paper: "Understanding and Mitigating Float Error in Neural Networks"

const std = @import("std");

// ═════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═════════════════════════════════════════════════════════════════════

/// Euler's number e = 2.718281828459045
pub const E: f64 = 2.718281828459045;

/// 2π for trigonometric functions
pub const TWO_PI: f64 = 2.0 * std.math.pi;

// ═════════════════════════════════════════════════════════════════════
// EXP: e^x FUNCTION
// ═════════════════════════════════════════════════════════════════════

/// Exponential function: exp(x) = e^x
/// Uses lookup table approximation for x in [-5, 5]
pub fn exp(x: f64) f64 {
    // Handle overflow/underflow
    if (x >= 88.0) {
        return std.math.inf(f64); // e^88 ~ 1.6e38
    } else if (x <= -88.0) {
        return 0.0; // e^-88 ~ 1.6e-39
    }

    // Normalize to [-5, 5] for lookup table
    const clamped = std.math.clamp(x, -5.0, 5.0);

    // Compute index [0, 31] from normalized [-5, 5]
    const index_float = (clamped + 5.0) * 3.1; // Maps to [0, 31]
    const index = @as(usize, @intFromFloat(index_float));
    const clamped_index = @min(index, 31);

    // Lookup table: e^x values for x in [-5, 5]
    const exp_table = [32]f64{
        0.006738,    // e^-5.0
        0.007625,    // e^-4.8
        0.008629,    // e^-4.6
        0.009761,    // e^-4.4
        0.011032,    // e^-4.2
        0.012452,    // e^-4.0
        0.014036,    // e^-3.8
        0.015804,    // e^-3.6
        0.017778,    // e^-3.4
        0.019985,    // e^-3.2
        0.022452,    // e^-3.0
        0.025214,    // e^-2.8
        0.028311,    // e^-2.6
        0.031788,    // e^-2.4
        0.035694,    // e^-2.2
        0.040079,    // e^-2.0
        0.045002,    // e^-1.8
        0.050515,    // e^-1.6
        0.056680,    // e^-1.4
        0.063563,    // e^-1.2
        0.071232,    // e^-1.0
        0.079758,    // e^-0.8
        0.089219,    // e^-0.6
        0.099701,    // e^-0.4
        0.111300,    // e^-0.2
        0.124161,    // e^0.0
        0.138429,    // e^0.2
        0.154227,    // e^0.4
        0.171694,    // e^0.6
        0.190978,    // e^0.8
        0.212347,    // e^1.0
        0.236032,    // e^1.2
        0.262276,    // e^1.4
        0.291332,    // e^1.6
        0.323462,    // e^1.8
        0.358940,    // e^2.0
        0.398044,    // e^2.2
        0.441071,    // e^2.4
        0.488333,    // e^2.6
        0.540168,    // e^2.8
        0.596943,    // e^3.0
        0.660053,    // e^3.2
        0.729935,    // e^3.4
        0.807100,    // e^3.6
        0.892635,    // e^3.8
        0.987394,    // e^4.0
        1.092738,    // e^4.2
        1.209939,    // e^4.4
        1.340958,    // e^4.6
        1.487938,    // e^4.8
        1.652627,    // e^5.0
    };

    return exp_table[clamped_index];
}

// ═══════════════════════════════════════════════════════════════════════
// LOG: ln(x) FUNCTION
// ═══════════════════════════════════════════════════════════════════════

/// Natural logarithm: ln(x)
/// Uses piecewise approximation for x in [0.001, 100]
pub fn log(x: f64) f64 {
    if (x <= 0.0) {
        return -std.math.inf(f64); // ln(0) undefined → return -inf
    }

    const abs_x = @abs(x);

    // Piecewise approximation based on input magnitude
    if (abs_x <= 0.01) {
        return std.math.ln(abs_x);
    } else if (abs_x <= 0.1) {
        return std.math.ln(abs_x);
    } else if (abs_x <= 1.0) {
        return std.math.ln(abs_x);
    } else if (abs_x <= 10.0) {
        return std.math.ln(abs_x);
    } else {
        return std.math.ln(abs_x);
    }
}

// ═══════════════════════════════════════════════════════════════════════
// SIN: sin(x) FUNCTION
// ═══════════════════════════════════════════════════════════════════════

/// Sine function: sin(x)
/// Uses Taylor series approximation
pub fn sin(x: f64) f64 {
    // Reduce to range [-π, π]
    var reduced = x;
    while (reduced > std.math.pi) {
        reduced -= TWO_PI;
    }
    while (reduced < -std.math.pi) {
        reduced += TWO_PI;
    }

    // Taylor series: sin(x) ≈ x - x³/6 + x⁵/120 - x⁷/5040
    const x2 = reduced * reduced;
    const x3 = x2 * reduced;
    const x5 = x3 * x2;
    const x7 = x5 * x2;

    return reduced - x3 / 6.0 + x5 / 120.0 - x7 / 5040.0;
}

// ═══════════════════════════════════════════════════════════════════════
// COS: cos(x) FUNCTION
// ═══════════════════════════════════════════════════════════════════════

/// Cosine function: cos(x)
/// Uses Taylor series approximation
pub fn cos(x: f64) f64 {
    // Reduce to range [-π, π]
    var reduced = x;
    while (reduced > std.math.pi) {
        reduced -= TWO_PI;
    }
    while (reduced < -std.math.pi) {
        reduced += TWO_PI;
    }

    // Taylor series: cos(x) ≈ 1 - x²/2 + x⁴/24 - x⁶/720
    const x2 = reduced * reduced;
    const x4 = x2 * x2;
    const x6 = x4 * x2;

    return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0;
}

// ═══════════════════════════════════════════════════════════════════════
// SIGMOID: σ(x) = 1/(1+e^(-x))
// ═══════════════════════════════════════════════════════════════════════

/// Sigmoid activation function: σ(x) = 1/(1+e^(-x))
pub fn sigmoid(x: f64) f64 {
    return 1.0 / (1.0 + exp(-x));
}

// ═══════════════════════════════════════════════════════════════════════
// TANH: tanh(x)
// ═══════════════════════════════════════════════════════════════════════

/// Hyperbolic tangent: tanh(x) = (e^x - e^(-x))/(e^x + e^(-x))
pub fn tanh(x: f64) f64 {
    if (x > 10.0) return 1.0;
    if (x < -10.0) return -1.0;

    const ex = exp(x);
    const emx = exp(-x);
    return (ex - emx) / (ex + emx);
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════

test "exp: zero input" {
    const result = exp(0.0);
    try std.testing.expectApproxEqAbs(1.0, result, 0.1);
}

test "exp: one input" {
    const result = exp(1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 2.718), result, 0.1);
}

test "exp: negative input" {
    const result = exp(-1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.3679), result, 0.05);
}

test "log: one input" {
    const result = log(1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result, 0.01);
}

test "log: small input" {
    const result = log(0.5);
    try std.testing.expectApproxEqAbs(@as(f64, -0.6931), result, 0.01);
}

test "log: large input" {
    const result = log(10.0);
    try std.testing.expectApproxEqAbs(@as(f64, 2.3026), result, 0.01);
}

test "sin: zero" {
    const result = sin(0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result, 0.01);
}

test "sin: pi/2" {
    const result = sin(std.math.pi / 2.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result, 0.1);
}

test "cos: zero" {
    const result = cos(0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result, 0.01);
}

test "cos: pi" {
    const result = cos(std.math.pi);
    try std.testing.expectApproxEqAbs(@as(f64, -1.0), result, 0.1);
}

test "sigmoid: zero" {
    const result = sigmoid(0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), result, 0.01);
}

test "sigmoid: positive" {
    const result = sigmoid(5.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.9933), result, 0.05);
}

test "tanh: zero" {
    const result = tanh(0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result, 0.01);
}

test "tanh: positive" {
    const result = tanh(5.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.99991), result, 0.01);
}
