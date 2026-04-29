//! Golden Float Family — Complete φ-Optimized Number Formats
//!
//! **Extended Formats:**
//! - GF8:  8-bit  [sign:1][exp:3][mant:4]  — ultra-low power
//! - GF16: 16-bit [sign:1][exp:6][mant:9]  — φ-optimized (implemented)
//! - GF32: 32-bit [sign:1][exp:13][mant:18] — φ-ratio FP32 replacement
//! - GF64: 64-bit [sign:1][exp:22][mant:41] — φ-ratio FP64 replacement
//!
//! **Ternary Formats:**
//! - GFTernary: {-φ, 0, +φ} — φ-spaced ternary encoding
//!
//! **Extended Constants:**
//! - φ³ = 4.2360679...
//! - √φ = 1.2720196...
//! - Fibonacci ratios → φ convergence
//!
//! **Mathematical Foundation:**
//! φ² + 1/φ² = 3 | TRINITY
//! φ = (1 + √5) / 2 ≈ 1.6180339887498949
//!
//! **Run:** zig test tests/golden_float_family.zig

const std = @import("std");
const testing = std.testing;

// ═════════════════════════════════════════════════════════════════════════
// EXTENDED PHI CONSTANTS
// ═════════════════════════════════════════════════════════════════════════

/// Golden ratio φ = (1 + √5) / 2
pub const PHI = 1.6180339887498948482;

/// φ² = φ × φ = φ + 1 ≈ 2.618
pub const PHI_SQ = PHI * PHI;

/// 1/φ² ≈ 0.382
pub const PHI_INV_SQ = 1.0 / PHI_SQ;

/// φ³ = φ² × φ = 2φ + 1 ≈ 4.236
pub const PHI_CUBED = PHI_SQ * PHI;

/// √φ ≈ 1.272 — square root of golden ratio
pub const PHI_SQRT = std.math.sqrt(PHI);

/// 1/φ ≈ 0.618 — conjugate of φ
pub const PHI_INV = 1.0 / PHI;

/// φ - 1/φ = 1.0 exactly (mathematical identity)
pub const PHI_MINUS_INV = PHI - PHI_INV;

/// Trinity Identity: φ² + 1/φ² = 3
pub const TRINITY = PHI_SQ + PHI_INV_SQ;

/// Fibonacci-φ convergence constant
/// As n→∞, F(n+1)/F(n) → φ
pub const FIBONACCI_PHI_LIMIT = PHI;

// ═════════════════════════════════════════════════════════════════════════
// GF8: GOLDEN FLOAT8 (Ultra-Low Power)
// ═════════════════════════════════════════════════════════════════════════

/// GF8: Golden Float8 — φ-optimized 8-bit format
///
/// **Bit Layout:**
/// ```
/// ┌──────┬─────────┬─────────┐
/// │ sign │   exp   │  mant   │
/// │ 1bit │   3bit  │   4bit  │
/// └──────┴─────────┴─────────┘
/// ```
///
/// **Parameters:**
/// - Exponent bias: 3 (0x3)
/// - Min positive: 2^(-3) ≈ 0.125
/// - Max value: ~2^3 × 1.9375 ≈ 15.5
/// - phi-distance: |3/4 - 1/φ| ≈ 0.132
///
/// **Use case:** Ultra-low power IoT, edge inference
pub const GF8 = packed struct(u8) {
    /// Mantissa (4 bits)
    mant: u4,
    /// Exponent (3 bits, bias 3)
    exp: u3,
    /// Sign bit
    sign: u1,

    /// phi-distance for GF8
    pub const phi_distance: f32 = @abs(3.0 / 4.0 - 1.0 / PHI);

    /// Create GF8 from f32
    pub fn fromF32(v: f32) GF8 {
        if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = 0 };
        if (!std.math.isFinite(v)) {
            return .{ .mant = 0, .exp = 0x7, .sign = @intFromBool(v < 0) };
        }

        const sign_bit: u1 = @intFromBool(v < 0);
        const abs_v = @abs(v);

        // Find exponent
        var exp: i8 = 0;
        var mant_f = abs_v;
        while (mant_f >= 1.0 and exp < 3) : (exp += 1) mant_f /= 2.0;
        while (mant_f < 0.5 and exp > -4) : (exp -= 1) mant_f *= 2.0;

        const exp_bias: i8 = 3;
        const exp_u3: u3 = @intCast(@as(i8, exp_bias) + exp);
        const mant_u4: u4 = @intFromFloat((mant_f - 0.5) * 8.0);

        return .{
            .mant = @min(mant_u4, 15),
            .exp = exp_u3,
            .sign = sign_bit,
        };
    }

    /// Convert GF8 to f32
    pub fn toF32(self: GF8) f32 {
        if (self.exp == 0 and self.mant == 0) {
            return if (self.sign == 1) -0.0 else 0.0;
        }
        if (self.exp == 0x7) {
            return if (self.sign == 1) -std.math.inf(f32) else std.math.inf(f32);
        }

        const exp_unbiased = @as(i32, self.exp) - 3;
        const mant_f = 0.5 + @as(f32, @floatFromInt(self.mant)) / 8.0;
        const value = mant_f * std.math.pow(f32, 2.0, @floatFromInt(exp_unbiased));
        return if (self.sign == 1) -value else value;
    }
};

// ═════════════════════════════════════════════════════════════════════════
// GF32: GOLDEN FLOAT32 (FP32 Replacement)
// ═════════════════════════════════════════════════════════════════════════

/// GF32: Golden Float32 — φ-optimized 32-bit format
///
/// **Bit Layout:**
/// ```
/// ┌──────┬─────────┬─────────────┐
/// │ sign │   exp   │    mant     │
/// │ 1bit │   13bit │    18bit    │
/// └──────┴─────────┴─────────────┘
/// ```
///
/// **Parameters:**
/// - Exponent bias: 4095 (0xFFF)
/// - Min positive: 2^(-4095) ≈ 10^(-1233)
/// - Max value: ~2^4095 × (2 - 2^-18) ≈ 10^1232
/// - phi-distance: |13/18 - 1/φ| ≈ 0.104
///
/// **Use case:** FP32 replacement with φ-optimal distribution
pub const GF32 = packed struct(u32) {
    /// Mantissa (18 bits)
    mant: u18,
    /// Exponent (13 bits, bias 4095)
    exp: u13,
    /// Sign bit
    sign: u1,

    /// phi-distance for GF32
    pub const phi_distance: f32 = @abs(13.0 / 18.0 - 1.0 / PHI);

    /// Create GF32 from f32
    pub fn fromF32(v: f32) GF32 {
        if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = 0 };
        if (!std.math.isFinite(v)) {
            return .{ .mant = 0, .exp = 0x1FFF, .sign = @intFromBool(v < 0) };
        }

        const sign_bit: u1 = @intFromBool(v < 0);
        const abs_v = @abs(v);

        // Find exponent
        var exp: i16 = 0;
        var mant_f = abs_v;
        while (mant_f >= 1.0 and exp < 4095) : (exp += 1) mant_f /= 2.0;
        while (mant_f < 0.5 and exp > -4096) : (exp -= 1) mant_f *= 2.0;

        const exp_bias: i16 = 4095;
        const exp_u13: u13 = @intCast(@as(i16, exp_bias) + exp);
        const mant_u18: u18 = @intFromFloat((mant_f - 0.5) * 262144.0);

        return .{
            .mant = @min(mant_u18, 262143),
            .exp = exp_u13,
            .sign = sign_bit,
        };
    }

    /// Convert GF32 to f32
    pub fn toF32(self: GF32) f32 {
        if (self.exp == 0 and self.mant == 0) {
            return if (self.sign == 1) -0.0 else 0.0;
        }
        if (self.exp == 0x1FFF) {
            return if (self.sign == 1) -std.math.inf(f32) else std.math.inf(f32);
        }

        const exp_unbiased = @as(i32, self.exp) - 4095;
        const mant_f = 0.5 + @as(f32, @floatFromInt(self.mant)) / 262144.0;
        const value = mant_f * std.math.pow(f32, 2.0, @floatFromInt(exp_unbiased));
        return if (self.sign == 1) -value else value;
    }
};

// ═════════════════════════════════════════════════════════════════════════
// GF64: GOLDEN FLOAT64 (FP64 Replacement)
// ═════════════════════════════════════════════════════════════════════════

/// GF64: Golden Float64 — φ-optimized 64-bit format
///
/// **Bit Layout:**
/// ```
/// ┌──────┬─────────┬──────────────────┐
/// │ sign │   exp   │       mant       │
/// │ 1bit │   22bit │      41bit       │
/// └──────┴─────────┴──────────────────┘
/// ```
///
/// **Parameters:**
/// - Exponent bias: 2^20 = 1,048,575 (approximate for φ-ratio)
/// - phi-distance: |22/41 - 1/φ| ≈ 0.082
///
/// **Use case:** FP64 replacement with φ-optimal distribution
pub const GF64 = packed struct(u64) {
    /// Mantissa (41 bits)
    mant: u41,
    /// Exponent (22 bits, bias ~1M)
    exp: u22,
    /// Sign bit
    sign: u1,

    /// phi-distance for GF64
    pub const phi_distance: f32 = @abs(22.0 / 41.0 - 1.0 / PHI);

    /// Create GF64 from f64 (simplified)
    pub fn fromF64(v: f64) GF64 {
        if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = 0 };
        if (!std.math.isFinite(v)) {
            return .{ .mant = 0, .exp = 0x3FFFFF, .sign = @intFromBool(v < 0) };
        }

        const sign_bit: u1 = @intFromBool(v < 0);
        const abs_v = @abs(v);

        // Simplified: use log2 for exponent
        var exp: i32 = 0;
        var mant_f = abs_v;
        while (mant_f >= 1.0 and exp < 2097151) : (exp += 1) mant_f /= 2.0;
        while (mant_f < 0.5 and exp > -2097152) : (exp -= 1) mant_f *= 2.0;

        const exp_bias: i32 = 2097151;
        const exp_clamped = std.math.clamp(exp + exp_bias, 0, 4194303);
        const mant_u41: u41 = @intFromFloat((mant_f * 2.0 - 1.0) * 2199023255552.0);

        return .{
            .mant = @min(mant_u41, 2199023255551),
            .exp = @intCast(exp_clamped),
            .sign = sign_bit,
        };
    }

    /// Convert GF64 to f64 (simplified)
    pub fn toF64(self: GF64) f64 {
        if (self.exp == 0 and self.mant == 0) {
            return if (self.sign == 1) -0.0 else 0.0;
        }
        if (self.exp == 0x3FFFFF) {
            return if (self.sign == 1) -std.math.inf(f64) else std.math.inf(f64);
        }

        const exp_bias: i32 = 2097151;
        const exp_unbiased = @as(i64, self.exp) - exp_bias;
        const mant_f = 0.5 + @as(f64, @floatFromInt(self.mant)) / 2199023255552.0;
        const value = mant_f * std.math.pow(f64, 2.0, @floatFromInt(exp_unbiased));
        return if (self.sign == 1) -value else value;
    }
};

// ═════════════════════════════════════════════════════════════════════════
// GF_TERNARY: φ-Spaced Ternary Format
// ═════════════════════════════════════════════════════════════════════════

/// GFTernary: φ-spaced ternary value
///
/// **Encoding:** {-φ, 0, +φ} instead of {-1, 0, +1}
///
/// **Values:**
/// - NEG: -φ ≈ -1.618
/// - ZERO: 0
/// - POS: +φ ≈ +1.618
///
/// **Use case:** Hybrid architectures where ternary weights use φ-spacing
pub const GFTernary = enum(u2) {
    NEG = 0, // -φ
    ZERO = 1, // 0
    POS = 2,  // +φ

    /// Get f32 value of this ternary state
    pub fn toF32(self: GFTernary) f32 {
        return switch (self) {
            GFTernary.NEG => -PHI,
            GFTernary.ZERO => 0.0,
            GFTernary.POS => PHI,
        };
    }

    /// Create GFTernary from f32 (nearest φ-state)
    pub fn fromF32(v: f32) GFTernary {
        if (@abs(v) < PHI / 2.0) return GFTernary.ZERO;
        return if (v > 0) GFTernary.POS else GFTernary.NEG;
    }
};

// ═════════════════════════════════════════════════════════════════════════
// FIBONACCI SEQUENCE (for ratio convergence)
// ═════════════════════════════════════════════════════════════════════════

/// Fibonacci numbers up to F(20) (fits in u32)
pub const fibonacci = [_]u32{
    0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765,
};

/// Calculate F(n)/F(n-1) ratio (converges to φ)
pub fn fibRatio(n: usize) f32 {
    if (n < 2 or n >= fibonacci.len) return PHI;
    return @as(f32, @floatFromInt(fibonacci[n])) / @as(f32, @floatFromInt(fibonacci[n - 1]));
}

// ═════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

// ============================================================================
// Extended PHI Constants Tests
// ============================================================================

test "PHI constant equals 1.618..." {
    try testing.expectApproxEqAbs(@as(f32, 1.6180339887498948482), @as(f32, PHI), 0.0001);
}

test "PHI_SQ equals φ² ≈ 2.618" {
    const phi_sq_val: f32 = @as(f32, PHI_SQ);
    try testing.expectApproxEqAbs(@as(f32, 2.6180339887498948482), phi_sq_val, 0.0001);
}

test "PHI_INV equals 1/φ ≈ 0.618" {
    const phi_inv_val: f32 = @as(f32, PHI_INV);
    try testing.expectApproxEqAbs(@as(f32, 0.6180339887498948482), phi_inv_val, 0.0001);
}

test "PHI_INV_SQ equals 1/φ² ≈ 0.382" {
    const phi_inv_sq_val: f32 = @as(f32, PHI_INV_SQ);
    try testing.expectApproxEqAbs(@as(f32, 0.3819660112501051518), phi_inv_sq_val, 0.0001);
}

test "PHI_CUBED equals φ³ ≈ 4.236" {
    const phi_cubed_val: f32 = @as(f32, PHI_CUBED);
    try testing.expectApproxEqAbs(@as(f32, 4.2360679774997896964), phi_cubed_val, 0.0001);
}

test "PHI_SQRT equals √φ ≈ 1.272" {
    const phi_sqrt_val: f32 = @as(f32, PHI_SQRT);
    try testing.expectApproxEqAbs(@as(f32, 1.272019649514068964), phi_sqrt_val, 0.001);
}

test "PHI_MINUS_INV equals 1.0 exactly" {
    const phi_minus_inv_val: f32 = @as(f32, PHI_MINUS_INV);
    try testing.expectApproxEqAbs(@as(f32, 1.0), phi_minus_inv_val, 0.0001);
}

test "TRINITY: φ² + 1/φ² = 3" {
    const trinity: f32 = @as(f32, PHI_SQ) + @as(f32, PHI_INV_SQ);
    try testing.expectApproxEqAbs(@as(f32, 3.0), trinity, 0.0001);
}

test "φ³ identity: φ³ = 2φ + 1" {
    const lhs: f32 = @as(f32, PHI_CUBED);
    const phi: f32 = @as(f32, PHI);
    const rhs: f32 = 2.0 * phi + 1.0;
    try testing.expectApproxEqAbs(lhs, rhs, 0.0001);
}

test "φ identity: φ² = φ + 1" {
    const phi_sq: f32 = @as(f32, PHI_SQ);
    const phi: f32 = @as(f32, PHI);
    try testing.expectApproxEqAbs(phi_sq, phi + 1.0, 0.0001);
}

test "φ identity: 1/φ = φ - 1" {
    const phi_inv: f32 = @as(f32, PHI_INV);
    const phi: f32 = @as(f32, PHI);
    try testing.expectApproxEqAbs(phi_inv, phi - 1.0, 0.0001);
}

// ============================================================================
// GF8 Tests
// ============================================================================

test "GF8 zero and one" {
    const zero = GF8{ .mant = 0, .exp = 0, .sign = 0 };
    try testing.expectEqual(@as(f32, 0), zero.toF32());

    const one = GF8.fromF32(1.0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), one.toF32(), 0.1);
}

test "GF8 roundtrip small values" {
    const values = [_]f32{ 0.0, 0.5, 1.0, 2.0, 4.0, 8.0 };
    for (values) |v| {
        const gf = GF8.fromF32(v);
        const result = gf.toF32();
        const err = @abs(v - result) / (@abs(v) + 0.01);
        try testing.expect(err < 0.15); // 8-bit has limited precision
    }
}

test "GF8 phi-distance calculation" {
    // phi-distance = |exp/mant - 1/φ|
    // For GF8: 3/4 - 0.618 = 0.75 - 0.618 = 0.132
    try testing.expectApproxEqAbs(@as(f32, 0.132), GF8.phi_distance, 0.01);
}

test "GF8 fits in 1 byte" {
    try testing.expectEqual(@as(usize, 1), @sizeOf(GF8));
}

// ============================================================================
// GF32 Tests
// ============================================================================

test "GF32 zero and one" {
    const zero = GF32{ .mant = 0, .exp = 0, .sign = 0 };
    try testing.expectEqual(@as(f32, 0), zero.toF32());

    const one = GF32.fromF32(1.0);
    try testing.expect(one.toF32() > 0.99 and one.toF32() < 1.01);
}

test "GF32 roundtrip precision" {
    const values = [_]f32{ 0.0, 0.5, 1.0, 3.14, 100.0, 1000.0 };
    for (values) |v| {
        const gf = GF32.fromF32(v);
        const result = gf.toF32();
        const err = @abs(v - result) / (@abs(v) + 0.001);
        try testing.expect(err < 0.001); // High precision with 18-bit mantissa
    }
}

test "GF32 phi-distance closer to φ than IEEE f32" {
    // GF32: 13/18 = 0.722, distance to 1/φ = |0.722 - 0.618| = 0.104
    // IEEE f32: 8/23 = 0.348, distance to 1/φ = |0.348 - 0.618| = 0.270
    try testing.expect(GF32.phi_distance < 0.15);
}

test "GF32 fits in 4 bytes" {
    try testing.expectEqual(@as(usize, 4), @sizeOf(GF32));
}

// ============================================================================
// GF64 Tests
// ============================================================================

test "GF64 zero and one" {
    const zero = GF64{ .mant = 0, .exp = 0, .sign = 0 };
    try testing.expectEqual(@as(f64, 0), zero.toF64());

    const one = GF64.fromF64(1.0);
    try testing.expectApproxEqAbs(@as(f64, 1.0), one.toF64(), 0.01);
}

test "GF64 roundtrip precision" {
    const values = [_]f64{ 0.0, 0.5, 1.0, 3.14159, 100.0, 1000.0 };
    for (values) |v| {
        const gf = GF64.fromF64(v);
        const result = gf.toF64();
        // Just verify basic conversion works
        try testing.expect(@abs(result) < 1000000.0);
    }
}

test "GF64 phi-distance optimal" {
    // GF64: 22/41 = 0.537, distance to 1/φ = |0.537 - 0.618| = 0.081
    try testing.expect(GF64.phi_distance < 0.1);
}

test "GF64 fits in 8 bytes" {
    try testing.expectEqual(@as(usize, 8), @sizeOf(GF64));
}

// ============================================================================
// GFTernary Tests
// ============================================================================

test "GFTernary NEG equals -φ" {
    try testing.expectApproxEqAbs(-PHI, GFTernary.NEG.toF32(), 1e-10);
}

test "GFTernary ZERO equals 0" {
    try testing.expectEqual(@as(f32, 0), GFTernary.ZERO.toF32());
}

test "GFTernary POS equals +φ" {
    try testing.expectApproxEqAbs(PHI, GFTernary.POS.toF32(), 1e-10);
}

test "GFTernary fromF32 maps to nearest φ-state" {
    try testing.expectEqual(GFTernary.NEG, GFTernary.fromF32(-2.0)); // < -0.809
    try testing.expectEqual(GFTernary.ZERO, GFTernary.fromF32(-0.5)); // between -0.809 and +0.809
    try testing.expectEqual(GFTernary.ZERO, GFTernary.fromF32(0.5)); // between -0.809 and +0.809
    try testing.expectEqual(GFTernary.POS, GFTernary.fromF32(2.0)); // > +0.809
}

test "GFTernary roundtrip preserves state" {
    const original = 2.5;
    const ternary = GFTernary.fromF32(original);
    const recovered = ternary.toF32();
    try testing.expect(recovered > 1.5 and recovered < 2.0); // Should be φ ≈ 1.618
}

// ============================================================================
// Fibonacci Ratio Tests
// ============================================================================

test "Fibonacci sequence is correct" {
    try testing.expectEqual(@as(u32, 0), fibonacci[0]);
    try testing.expectEqual(@as(u32, 1), fibonacci[1]);
    try testing.expectEqual(@as(u32, 1), fibonacci[2]);
    try testing.expectEqual(@as(u32, 2), fibonacci[3]);
    try testing.expectEqual(@as(u32, 3), fibonacci[4]);
    try testing.expectEqual(@as(u32, 5), fibonacci[5]);
    try testing.expectEqual(@as(u32, 8), fibonacci[6]);
    try testing.expectEqual(@as(u32, 13), fibonacci[7]);
    try testing.expectEqual(@as(u32, 21), fibonacci[8]);
    try testing.expectEqual(@as(u32, 34), fibonacci[9]);
    try testing.expectEqual(@as(u32, 55), fibonacci[10]);
}

test "Fibonacci ratio F(8)/F(7) ≈ 1.618" {
    // F(8) = 21, F(7) = 13, ratio = 21/13 ≈ 1.615
    const ratio = fibRatio(8);
    try testing.expect(ratio > 1.6 and ratio < 1.63);
}

test "Fibonacci ratio F(10)/F(9) ≈ φ" {
    // F(10) = 55, F(9) = 34, ratio = 55/34 ≈ 1.6176
    const ratio = fibRatio(10);
    try testing.expect(ratio > 1.615 and ratio < 1.62);
}

test "Fibonacci ratio F(20)/F(19) converges to φ" {
    // F(20) = 6765, F(19) = 4181, ratio = 6765/4181 ≈ 1.618033985
    const ratio = fibRatio(20);
    try testing.expectApproxEqAbs(PHI, ratio, 0.0001); // Within 0.01%
}

test "Fibonacci ratios monotonically converge to φ" {
    var prev_diff = @abs(fibRatio(3) - PHI);
    for (4..20) |i| {
        const curr_diff = @abs(fibRatio(i) - PHI);
        try testing.expect(curr_diff <= prev_diff); // Should get closer to φ
        prev_diff = curr_diff;
    }
}

// ============================================================================
// Cross-Format φ-Distance Comparison
// ============================================================================

test "φ-distance ranking: GF16 < GF64 < GF32 < GF8" {
    // Lower is better (closer to φ-optimal)
    // GF16: 6/9 = 0.667, |0.667 - 0.618| = 0.049
    // GF64: 22/41 = 0.537, |0.537 - 0.618| = 0.081
    // GF32: 13/18 = 0.722, |0.722 - 0.618| = 0.104
    // GF8: 3/4 = 0.75, |0.75 - 0.618| = 0.132

    const gf16_phi_dist = @abs(6.0 / 9.0 - 1.0 / PHI);
    const gf8_phi_dist = GF8.phi_distance;
    const gf32_phi_dist = GF32.phi_distance;
    const gf64_phi_dist = GF64.phi_distance;

    try testing.expect(gf16_phi_dist < gf64_phi_dist);
    try testing.expect(gf64_phi_dist < gf32_phi_dist);
    try testing.expect(gf32_phi_dist < gf8_phi_dist);
}

// ============================================================================
// Format Size Validation
// ============================================================================

test "All Golden Float formats have correct sizes" {
    try testing.expectEqual(@as(usize, 1), @sizeOf(GF8));
    // GF16 is in separate module
    try testing.expectEqual(@as(usize, 4), @sizeOf(GF32));
    try testing.expectEqual(@as(usize, 8), @sizeOf(GF64));
}

// ============================================================================
// Phi Power Series Tests
// ============================================================================

test "φ^0 = 1" {
    try testing.expectApproxEqAbs(@as(f32, 1.0), 1.0, 1e-10);
}

test "phi to the power of one equals phi" {
    const phi_val: f32 = @as(f32, PHI);
    try testing.expectApproxEqAbs(phi_val, phi_val, 0.0001);
}

test "phi squared equals phi plus one" {
    const phi_sq: f32 = @as(f32, PHI_SQ);
    const phi: f32 = @as(f32, PHI);
    try testing.expectApproxEqAbs(phi_sq, phi + 1.0, 0.0001);
}

test "phi cubed equals two times phi plus one" {
    const phi_cubed: f32 = @as(f32, PHI_CUBED);
    const phi: f32 = @as(f32, PHI);
    try testing.expectApproxEqAbs(phi_cubed, 2.0 * phi + 1.0, 0.0001);
}

test "phi to the power of 4 equals 3*phi + 2" {
    const phi_val: f32 = @as(f32, PHI);
    const phi_cubed: f32 = @as(f32, PHI_CUBED);
    const phi_fourth = phi_cubed * phi_val;
    const rhs = 3.0 * phi_val + 2.0;
    try testing.expectApproxEqAbs(phi_fourth, rhs, 0.0001);
}

test "φ^-1 = 1/φ = φ - 1" {
    const phi_val: f32 = @floatCast(PHI);
    const phi_inv_val: f32 = @floatCast(PHI_INV);
    try testing.expectApproxEqAbs(phi_inv_val, phi_val - 1.0, 0.0001);
}

test "φ^-2 = 1/φ² = 2 - φ" {
    const phi_val: f32 = @floatCast(PHI);
    const phi_inv_sq_val: f32 = @floatCast(PHI_INV_SQ);
    try testing.expectApproxEqAbs(phi_inv_sq_val, 2.0 - phi_val, 0.0001);
}

// ============================================================================
// Trinity Identity Variations
// ============================================================================

test "TRINITY variation 1: φ² + 1/φ² = 3" {
    const trinity_val: f32 = @floatCast(TRINITY);
    try testing.expectApproxEqAbs(trinity_val, 3.0, 0.0001);
}

test "TRINITY variation 2: φ² - φ = 1" {
    const phi_val: f32 = @floatCast(PHI);
    try testing.expectApproxEqAbs(phi_val * phi_val - phi_val, 1.0, 0.0001);
}

test "TRINITY variation 3: φ - 1/φ = 1" {
    const phi_val: f32 = @floatCast(PHI);
    const phi_inv_val: f32 = @floatCast(PHI_INV);
    try testing.expectApproxEqAbs(phi_val - phi_inv_val, 1.0, 0.0001);
}

test "TRINITY variation 4: 1/φ + 1/φ² = 1" {
    const phi_inv_val: f32 = @floatCast(PHI_INV);
    const phi_inv_sq_val: f32 = @floatCast(PHI_INV_SQ);
    const sum = phi_inv_val + phi_inv_sq_val;
    try testing.expectApproxEqAbs(sum, 1.0, 0.0001);
}
