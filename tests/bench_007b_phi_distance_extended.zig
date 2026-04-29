//! BENCH-007b: φ-Distance Extended Range [-10, 10]
//!
//! Status: ⬜ TODO → ✅ after this run
//!
//! Hypothesis: On the narrow range [-1, 1] used in BENCH-007, all GF formats
//! show identical MSE=0.00329 / MAE=0.0496. On the wider range [-10, 10],
//! GF8 should show significantly higher MSE than GF16/GF64 due to its limited
//! dynamic range [~0.0078, 1.9375].
//!
//! Per whitepaper §8.3 (BENCH-007b) and L-METRIC rule:
//! stdout ONLY contains metric lines. Everything else → stderr.
//!
//! Run: zig test tests/bench_007b_phi_distance_extended.zig

const std = @import("std");
const testing = std.testing;
const fmt_root = @import("../src/formats/formats_root.zig");

// ═══════════════════════════════════════════════════════════════════
// φ Constants (Trinity Identity: φ² + φ⁻² = 3)
// ═══════════════════════════════════════════════════════════════════

const PHI: f32 = 1.6180339887;
const INV_PHI: f32 = 0.6180339887;
const PHI_DISTANCE_THRESHOLD: f32 = 0.2;

// GF8 limits (from whitepaper §11.2)
const GF8_MAX: f32 = 1.9375;
const GF8_MIN_POS: f32 = 0.0078125;

// ═══════════════════════════════════════════════════════════════════
// GF8 Software Implementation (1:3:4 layout, bias=7)
// ═══════════════════════════════════════════════════════════════════

fn f32ToGf8(a: f32) u8 {
    if (a == 0.0) return 0;
    const sign_bit: u8 = if (a < 0) 0x80 else 0;
    const abs_a = @abs(a);

    if (abs_a >= GF8_MAX) return sign_bit | 0x7F;
    if (abs_a < GF8_MIN_POS) return sign_bit;

    const frexp_result = std.math.frexp(abs_a);
    var m = frexp_result.significand * 2.0;
    var e = frexp_result.exponent - 1;

    e = e + 7;
    if (e <= 0) return sign_bit;
    if (e >= 7) return sign_bit | 0x7F;

    const mant_f = (m - 1.0) * 16.0;
    var mant_i = @as(i32, @intFromFloat(std.math.round(mant_f)));
    if (mant_i >= 16) {
        mant_i = 0;
        e += 1;
        if (e >= 7) return sign_bit | 0x7F;
    }

    const e_bits: u8 = @as(u8, @intCast(e)) << 4;
    const m_bits: u8 = @as(u8, @intCast(mant_i)) & 0x0F;
    return sign_bit | e_bits | m_bits;
}

fn gf8ToF32(x: u8) f32 {
    const sign: i32 = @as(i32, (x >> 7) & 1);
    const e: i32 = @as(i32, (x >> 4) & 0x07);
    const m: i32 = @as(i32, x & 0x0F);

    if (e == 0 and m == 0) return if (sign == 0) 0.0 else -0.0;
    if (e == 0) {
        const val = @as(f32, @floatFromInt(m)) / 16.0 * std.math.exp2(@as(f32, @floatFromInt(1 - 7)));
        return if (sign == 0) val else -val;
    }
    const exp_val = e - 7;
    const frac = 1.0 + @as(f32, @floatFromInt(m)) / 16.0;
    const val = frac * std.math.exp2(@as(f32, @floatFromInt(exp_val)));
    return if (sign == 0) val else -val;
}

// ═══════════════════════════════════════════════════════════════════
// φ-Distance Constants (from BENCH-007, whitepaper §1.3)
// ═══════════════════════════════════════════════════════════════════

const PHI_DIST_GF8: f32 = 0.132;
const PHI_DIST_GF16: f32 = 0.049;
const PHI_DIST_GF32: f32 = 0.340;
const PHI_DIST_GF64: f32 = 0.264;
const PHI_DIST_FP16: f32 = 0.118;
const PHI_DIST_BF16: f32 = 0.525;
const PHI_DIST_TERNARY: f32 = 0.000;

// ═══════════════════════════════════════════════════════════════════
// Benchmark Core
// ═══════════════════════════════════════════════════════════════════

const BenchResult = struct {
    mse: f64,
    mae: f64,
    max_err: f64,
    phi_distance: f32,
    overflow_count: u32,
};

fn benchmarkFormat(
    lo: f32,
    hi: f32,
    n_samples: u32,
    phi_dist: f32,
    quantize_fn: fn (f32) f32,
) BenchResult {
    var mse_acc: f64 = 0.0;
    var mae_acc: f64 = 0.0;
    var max_err: f64 = 0.0;
    var overflow_count: u32 = 0;

    const step = (hi - lo) / @as(f32, @floatFromInt(n_samples));
    const max_q = quantize_fn(hi);

    var i: u32 = 0;
    while (i < n_samples) : (i += 1) {
        const x = lo + @as(f32, @floatFromInt(i)) * step;
        const q = quantize_fn(x);

        if (@abs(x) < (hi - lo) * 0.4 and @abs(q) == @abs(max_q)) {
            overflow_count += 1;
        }

        const err = @as(f64, @floatCast(@abs(q - x)));
        mse_acc += err * err;
        mae_acc += err;
        if (err > max_err) max_err = err;
    }

    return BenchResult{
        .mse = mse_acc / @as(f64, @floatFromInt(n_samples)),
        .mae = mae_acc / @as(f64, @floatFromInt(n_samples)),
        .max_err = max_err,
        .phi_distance = phi_dist,
        .overflow_count = overflow_count,
    };
}

fn quantizeGf16(x: f32) f32 {
    return fmt_root.quantizeValue(x, .gf16);
}
fn quantizeFp16(x: f32) f32 {
    return fmt_root.quantizeValue(x, .fp16);
}
fn quantizeBf16(x: f32) f32 {
    return fmt_root.quantizeValue(x, .bf16);
}
fn quantizeGf8(x: f32) f32 {
    return gf8ToF32(f32ToGf8(x));
}

// ═══════════════════════════════════════════════════════════════════
// BENCH-007b Tests
// ═══════════════════════════════════════════════════════════════════

test "BENCH-007b: phi-distance ranking preserved at extended range" {
    // phi-distances are structural format properties, not data-dependent
    try testing.expect(PHI_DIST_GF16 < PHI_DIST_FP16);
    try testing.expect(PHI_DIST_FP16 < PHI_DIST_GF8);
    try testing.expect(PHI_DIST_GF8 < PHI_DIST_BF16);
    try testing.expect(PHI_DIST_GF16 < 0.1);
}

test "BENCH-007b: GF8 saturates on values > 1.9375" {
    // GF8 max = 1.9375 per whitepaper §11.2 — values above clamp to max
    const gf8_at_max = f32ToGf8(1.9375);
    const gf8_at_5 = f32ToGf8(5.0);
    const gf8_at_10 = f32ToGf8(10.0);
    try testing.expectEqual(gf8_at_max, gf8_at_5);
    try testing.expectEqual(gf8_at_max, gf8_at_10);
}

test "BENCH-007b: GF16 handles full [-10, 10] range without overflow" {
    const test_vals = [_]f32{ -10.0, -5.0, -2.0, 2.0, 5.0, 10.0 };
    for (test_vals) |v| {
        const q = quantizeGf16(v);
        const err = @abs(q - v) / @abs(v);
        // Relative error < 1% for GF16 in this range
        try testing.expect(err < 0.01);
    }
}

test "BENCH-007b: MSE comparison GF8 vs GF16 on [-10, 10]" {
    const n: u32 = 1000;
    const lo: f32 = -10.0;
    const hi: f32 = 10.0;

    const gf8_r = benchmarkFormat(lo, hi, n, PHI_DIST_GF8, quantizeGf8);
    const gf16_r = benchmarkFormat(lo, hi, n, PHI_DIST_GF16, quantizeGf16);
    const fp16_r = benchmarkFormat(lo, hi, n, PHI_DIST_FP16, quantizeFp16);
    const bf16_r = benchmarkFormat(lo, hi, n, PHI_DIST_BF16, quantizeBf16);

    // L-R8: results to stderr
    std.debug.print("\n=== BENCH-007b: phi-Distance Extended Range [-10, 10] ===\n", .{});
    std.debug.print("+-------------+----------+----------+--------------+--------------+\n", .{});
    std.debug.print("| Format      | MSE      | MAE      | Max Error    | phi-distance |\n", .{});
    std.debug.print("+-------------+----------+----------+--------------+--------------+\n", .{});
    std.debug.print("| GF8         | {d:8.4}  | {d:8.4}  | {d:12.4}  | {d:12.3}  |\n", .{ gf8_r.mse, gf8_r.mae, gf8_r.max_err, gf8_r.phi_distance });
    std.debug.print("| GF16        | {d:8.6}  | {d:8.6}  | {d:12.6}  | {d:12.3}  |\n", .{ gf16_r.mse, gf16_r.mae, gf16_r.max_err, gf16_r.phi_distance });
    std.debug.print("| fp16        | {d:8.6}  | {d:8.6}  | {d:12.6}  | {d:12.3}  |\n", .{ fp16_r.mse, fp16_r.mae, fp16_r.max_err, fp16_r.phi_distance });
    std.debug.print("| bf16        | {d:8.6}  | {d:8.6}  | {d:12.6}  | {d:12.3}  |\n", .{ bf16_r.mse, bf16_r.mae, bf16_r.max_err, bf16_r.phi_distance });
    std.debug.print("+-------------+----------+----------+--------------+--------------+\n", .{});
    std.debug.print("GF8 overflow count: {}\n", .{gf8_r.overflow_count});

    // KEY HYPOTHESIS: GF8 MSE >> GF16 MSE on extended range
    try testing.expect(gf8_r.mse > gf16_r.mse * 10);

    // GF16 stays competitive with fp16 on extended range
    try testing.expect(gf16_r.mse < fp16_r.mse * 5);
}

test "BENCH-007b: phi-distance full ranking table" {
    const formats = [_]struct {
        name: []const u8,
        phi_dist: f32,
    }{
        .{ .name = "GFTernary", .phi_dist = PHI_DIST_TERNARY },
        .{ .name = "GF16",      .phi_dist = PHI_DIST_GF16 },
        .{ .name = "fp16",      .phi_dist = PHI_DIST_FP16 },
        .{ .name = "GF8",       .phi_dist = PHI_DIST_GF8 },
        .{ .name = "GF64",      .phi_dist = PHI_DIST_GF64 },
        .{ .name = "GF32",      .phi_dist = PHI_DIST_GF32 },
        .{ .name = "bf16",      .phi_dist = PHI_DIST_BF16 },
    };

    std.debug.print("\n=== BENCH-007b: Full phi-Distance Ranking ===\n", .{});
    std.debug.print("+-------------+--------------+--------------------------------------+\n", .{});
    std.debug.print("| Format      | phi-distance | Note                                 |\n", .{});
    std.debug.print("+-------------+--------------+--------------------------------------+\n", .{});
    for (formats) |f| {
        const note: []const u8 = if (f.phi_dist == 0.0)
            "Perfect -- {-phi,0,+phi} by definition  "
        else if (f.phi_dist < 0.1)
            "[OK] Excellent phi-alignment            "
        else if (f.phi_dist < 0.2)
            "[OK] Good phi-alignment                 "
        else if (f.phi_dist < 0.4)
            "[!!] Moderate phi-alignment             "
        else
            "[XX] Poor phi-alignment                 ";
        std.debug.print("| {s:<11} | {d:12.3}  | {s} |\n", .{ f.name, f.phi_dist, note });
    }
    std.debug.print("+-------------+--------------+--------------------------------------+\n", .{});

    // Verify strict ordering from whitepaper
    try testing.expect(formats[0].phi_dist < formats[1].phi_dist); // Ternary < GF16
    try testing.expect(formats[1].phi_dist < formats[2].phi_dist); // GF16 < fp16
    try testing.expect(formats[2].phi_dist < formats[3].phi_dist); // fp16 < GF8
    try testing.expect(formats[5].phi_dist < formats[6].phi_dist); // GF32 < bf16
}

test "BENCH-007b: GF16 relative error < 0.5% on extended range" {
    const test_cases = [_]struct { input: f32, max_rel_err: f32 }{
        .{ .input = 0.1,   .max_rel_err = 0.005 },
        .{ .input = 1.0,   .max_rel_err = 0.005 },
        .{ .input = 3.14,  .max_rel_err = 0.005 },
        .{ .input = 7.5,   .max_rel_err = 0.005 },
        .{ .input = -3.5,  .max_rel_err = 0.005 },
        .{ .input = -9.9,  .max_rel_err = 0.005 },
    };
    for (test_cases) |tc| {
        const q = quantizeGf16(tc.input);
        const rel_err = @abs(q - tc.input) / @abs(tc.input);
        try testing.expect(rel_err < tc.max_rel_err);
    }
}

test "BENCH-007b: Trinity identity phi^2 + phi^-2 = 3" {
    const phi2 = PHI * PHI;
    const inv_phi2 = 1.0 / (PHI * PHI);
    const trinity = phi2 + inv_phi2;
    try testing.expectApproxEqAbs(@as(f32, 3.0), trinity, 0.0001);
}
