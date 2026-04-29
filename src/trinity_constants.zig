//! Trinity Constants — φ-derived physics for IGLA-GF16 architecture
//!
//! Module 1 from IGLA-GF16 spec (issue #3).
//!
//! All hyperparameters derived from Trinity φ-algebra:
//!   PHI = (1 + √5) / 2 ≈ 1.6180339887498948
//!   PHI^2 + PHI^(-2) = 3  (Trinity Identity)
//!   ALPHA_PHI = PHI^(-3) / 2 ≈ 0.118034

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;

pub const PHI_SQ: f64 = PHI * PHI;

pub const PHI_INV: f64 = 1.0 / PHI;

pub const PHI_INV_SQ: f64 = 1.0 / PHI_SQ;

pub const TRINITY: f64 = PHI_SQ + PHI_INV_SQ;

pub const ALPHA_PHI: f64 = 1.0 / (PHI * PHI * PHI) / 2.0;

pub const ALPHA_PHI_X_PHI_INV: f64 = ALPHA_PHI * PHI_INV;

pub const ALPHA_PHI_X_PHI_INV_SQ: f64 = ALPHA_PHI * PHI_INV_SQ;

pub const ALPHA_PHI_X_PHI_INV_3: f64 = ALPHA_PHI * PHI_INV_SQ * PHI_INV;

pub const GF16_MANT_EXP_RATIO: f64 = 9.0 / 6.0;

pub const ALPHA_GF16: f64 = PHI - GF16_MANT_EXP_RATIO;

pub fn fib(comptime n: comptime_int) comptime_int {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

pub const FIBONACCI = [_]comptime_int{
    fib(0),  fib(1),  fib(2),  fib(3),  fib(4),
    fib(5),  fib(6),  fib(7),  fib(8),  fib(9),
    fib(10), fib(11), fib(12), fib(13), fib(14),
    fib(15), fib(16), fib(17), fib(18), fib(19),
    fib(20), fib(21), fib(22), fib(23), fib(24),
};

pub const D_MODEL: comptime_int = fib(12); // 144
pub const N_HEADS: comptime_int = fib(6); // 8
pub const D_HEAD: comptime_int = D_MODEL / N_HEADS; // 18
pub const D_FFN: comptime_int = fib(13); // 233
pub const N_LAYERS: comptime_int = 7;
pub const VOCAB: comptime_int = 50257;

comptime {
    if (!(TRINITY >= 2.9999 and TRINITY <= 3.0001)) {
        @compileError("Trinity identity violation: PHI^2 + PHI^(-2) must equal 3");
    }
    if (!(@abs(ALPHA_GF16 - ALPHA_PHI) < 0.001)) {
        @compileError("GF16 alpha_phi mismatch");
    }
}

test "trinity: PHI^2 + PHI^(-2) = 3" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), TRINITY, 1e-12);
}

test "trinity: PHI^2 = PHI + 1" {
    try std.testing.expectApproxEqAbs(PHI + 1.0, PHI_SQ, 1e-12);
}

test "trinity: ALPHA_PHI = 0.118034" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.118034), ALPHA_PHI, 1e-4);
}

test "trinity: GF16 mant/exp ratio = 1.5, deviation from PHI = ALPHA_PHI" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), GF16_MANT_EXP_RATIO, 1e-10);
    try std.testing.expectApproxEqAbs(ALPHA_PHI, ALPHA_GF16, 1e-3);
}

test "trinity: architecture dimensions from Fibonacci" {
    try std.testing.expectEqual(@as(comptime_int, 144), D_MODEL);
    try std.testing.expectEqual(@as(comptime_int, 8), N_HEADS);
    try std.testing.expectEqual(@as(comptime_int, 18), D_HEAD);
    try std.testing.expectEqual(@as(comptime_int, 233), D_FFN);
}

test "trinity: D_FFN ≈ D_MODEL × PHI" {
    const ratio = @as(f64, @floatFromInt(D_FFN)) / @as(f64, @floatFromInt(D_MODEL));
    try std.testing.expectApproxEqAbs(PHI, ratio, 0.01);
}

test "trinity: Fibonacci sequence" {
    try std.testing.expectEqual(@as(comptime_int, 0), FIBONACCI[0]);
    try std.testing.expectEqual(@as(comptime_int, 1), FIBONACCI[1]);
    try std.testing.expectEqual(@as(comptime_int, 144), FIBONACCI[12]);
    try std.testing.expectEqual(@as(comptime_int, 233), FIBONACCI[13]);
}

test "trinity: weight init sector constants" {
    try std.testing.expect(ALPHA_PHI > 0.1 and ALPHA_PHI < 0.2);
    try std.testing.expect(ALPHA_PHI_X_PHI_INV > 0.05 and ALPHA_PHI_X_PHI_INV < 0.1);
    try std.testing.expect(ALPHA_PHI_X_PHI_INV_SQ > 0.03 and ALPHA_PHI_X_PHI_INV_SQ < 0.06);
    try std.testing.expect(ALPHA_PHI_X_PHI_INV_3 > 0.01 and ALPHA_PHI_X_PHI_INV_3 < 0.04);
}
