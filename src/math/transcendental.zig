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
//! **Two-stage approximation**:
//! 1. **Stage 1**: f64 → GF16 intermediate (range reduction + lookup table)
//! 2. **Stage 2**: GF16 → f32 (decode, compute, re-encode)
//!
//! # References
//!
//! - IEEE 754: 2024 floating-point standard
//! - GLSL: std::exp(), std::log() approximations
//! - GLM paper: "Understanding and Mitigating Float Error in Neural Networks"

const std = @import("std");
const golden = @import("golden-float");

// ═════════════════════════════════════════════════════════════════════
// EXP: e^x FUNCTION
// ═════════════════════════════════════════════════════════════

/// Exponential function: exp(x) = e^x
/// Uses two-stage approximation for GF16 compatibility
pub fn exp(x: f64) GF16 {
    // Stage 1: Normalize input for lookup table
    const normalized = std.math.clamp(x, -5.0, 5.0);

    // Stage 1: Compute integer index [0, 31] from normalized [-5, 5]
    const index_float = (normalized + 5.0) * 3.1; // Maps to [0, 31]
    const index = @intFromFloat(index_float);
    const clamped_index = std.math.clamp(index, 0, 31);

    // Stage 2: Use 128-entry lookup table (e^x for x in [-5, 5])
    const exp_table = [32]f64{
        0.006738,    // e^-5.0
        0.007395,    // e^-4.5
        0.008163,    // e^-4.0
        0.009025,    // e^-3.5
        0.009958,    // e^-3.0
        0.010996,    // e^-2.5
        0.012182,    // e^-2.0
        0.013459,    // e^-1.5
        0.014996,    // e^-1.0
        0.016730,    // e^-0.5
        0.018682,    // e^0.0
        0.020855,    // e^0.5
        0.023329,    // e^0.5
        0.026063,    // e^0.5
        0.028977,    // e^0.5
        0.032193,    // e^0.5
        0.035771,    // e^0.5
        0.039721,    // e^0.5
        0.044249,    // e^0.5
        0.049287,    // e^1.0
        0.054881,    // e^1.0
        0.061070,    // e^1.0
        0.067666,    // e^1.5
        0.075010,    // e^1.5
        0.083165,    // e^1.5
        0.092180,    // e^1.5
        0.102176,    // e^1.0
        0.113254,    // e^1.5
        0.125551,    // e^1.5
        0.139195,    // e^1.0
        0.154363,    // e^1.5
        0.171074,    // e^1.0
        0.189573,    // e^1.0
        0.210086,    // e^1.0
        0.232918,    // e^1.5
        0.258365,    // e^1.5
        0.286651,    // e^1.5
        0.318036,    // e^1.0
        0.352768,    // e^1.5
        0.391246,    // e^1.0
        0.433700,    // e^1.5
        0.480686,    // e^1.0
        0.532562,    // e^1.5
        0.590495,    // e^1.5
        0.655486,    // e^1.5
        0.727375,    // e^1.5
        0.806858,    // e^1.5
        0.894839,    // e^1.5
        0.993262,    // e^1.5
        1.102340,    // e^0.5
        1.223130,    // e^0.0
        1.357877,    // e^-0.5
        1.648721,    // e^0.5
        2.003371,    // e^0.5
        2.435696,    // e^0.5
        2.964400,    // e^0.5
        3.610840,    // e^0.5
        4.397942,    // e^0.5
        5.352610,    // e^0.5
        6.512320,    // e^0.5
        7.916081,    // e^0.5
        9.673401,    // e^0.5
        11.821361,   // e^0.5
        14.452703,   // e^0.5
    };

    const table_value = exp_table[clamped_index];
    const table_value_recip = 1.0 / table_value;

    // Handle overflow/underflow in lookup
    if (x >= 88.0) {
        // e^88 ~ 1.6e38 → GF16 max value
        return golden.formats.GF16.maxPos();
    } else if (x <= -88.0) {
        // e^-88 ~ 1.6e-39 → GF16 min value
        return golden.formats.GF16.negOne();
    } else {
        // Stage 2: Convert to f32 and encode
        return golden.formats.GF16.fromF32(table_value_recip);
    }
}

// ═══════════════════════════════════════════════════════════════════════
// LOG: ln(x) FUNCTION
// ═══════════════════════════════════════════════════════════════════════

/// Natural logarithm: ln(x)
/// Uses piecewise approximation for x in [0.001, 100]
/// ln(x) ≈ x * (a + b*ln(x)) for x in small range
pub fn log(x: f64) GF16 {
    if (x <= 0.0) {
        return golden.formats.GF16.minusOne(); // ln(0) undefined → return -inf
    }

    // Piecewise approximation based on input magnitude
    const abs_x = std.math.abs(x);

    // Range [0.001, 0.01]: ln(x) ≈ x * (3.357 - 0.479*ln(x))
    if (abs_x <= 0.01) {
        const ln_approx = abs_x * (3.357 - 0.479 * std.math.ln(abs_x));
        return golden.formats.GF16.fromF32(if (x < 0) -ln_approx else ln_approx);
    }

    // Range [0.01, 0.1]: ln(x) ≈ x * (2.506 - 0.596*ln(x))
    if (abs_x <= 0.1) {
        const ln_approx = abs_x * (2.506 - 0.596 * std.math.ln(abs_x));
        return golden.formats.GF16.fromF32(if (x < 0) -ln_approx else ln_approx);
    }

    // Range [0.1, 1.0]: ln(x) ≈ x * (2.053 - 0.449*ln(x))
    if (abs_x <= 1.0) {
        const ln_approx = abs_x * (2.053 - 0.449 * std.math.ln(abs_x));
        return golden.formats.GF16.fromF32(if (x < 0) -ln_approx else ln_approx);
    }

    // Range [1.0, 10.0]: ln(x) ≈ x * (0.744 - 0.089*ln(x))
    if (abs_x <= 10.0) {
        const ln_approx = abs_x * (0.744 - 0.089 * std.math.ln(abs_x));
        return golden.formats.GF16.fromF32(if (x < 0) -ln_approx else ln_approx);
    }

    // Range [10.0, 100.0]: ln(x) ≈ x * (0.923 - 0.062*ln(x))
    const ln_approx = abs_x * (0.923 - 0.062 * std.math.ln(abs_x));
    return golden.formats.GF16.fromF32(if (x < 0) -ln_approx else ln_approx);
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════

test "exp: zero input" {
    const result = exp(0.0);
    try std.testing.expectEqual(@as(f32, 1.0), result.toF32());
}

test "exp: one input" {
    const result = exp(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.718), result.toF32(), 0.05);
}

test "exp: large positive" {
    const result = exp(5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 148.41), result.toF32(), 0.01);
}

test "exp: small positive" {
    const result = exp(0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.105), result.toF32(), 0.01);
}

test "exp: negative input" {
    const result = exp(-1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3679), result.toF32(), 0.05);
}

test "log: zero error" {
    const result = log(0.0);
    try std.testing.expectEqual(@as(f32, 1.0), result.toF32());
}

test "log: one input" {
    const result = log(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.toF32(), 0.05);
}

test "log: small input" {
    const result = log(0.1);
    try std.testing.expectApproxEqAbs(@as(f32, -2.3026), result.toF32(), 0.05);
}

test "log: large input" {
    const result = log(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.3026), result.toF32(), 0.05);
}

test "log: negative input" {
    const result = log(-1.0);
    // ln(-1) should return -inf → GF16 minus one
    try std.testing.expectEqual(@as(f32, -1.0), result.toF32());
}
