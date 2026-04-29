//! Trinity Weight Initialization (IGLA-GF16 Module 4)
//!
//! 4 physics sectors derived from alpha_phi:
//!   gauge     (attn QKV):  std = alpha_phi           = 0.118034
//!   higgs     (attn proj): std = alpha_phi * phi^-1   = 0.072949
//!   lepton    (ffn gate):  std = alpha_phi * phi^-2   = 0.045085
//!   cosmology (embed):     std = alpha_phi * phi^-3   = 0.027864
//!
//! Reference: issue #3, whitepaper §11.4

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948;
pub const ALPHA_PHI: f64 = 0.1180339887498948;

pub const Sector = enum {
    gauge,
    higgs,
    lepton,
    cosmology,
};

pub fn sectorStd(sector: Sector) f64 {
    return switch (sector) {
        .gauge => ALPHA_PHI,
        .higgs => ALPHA_PHI / PHI,
        .lepton => ALPHA_PHI / (PHI * PHI),
        .cosmology => ALPHA_PHI / (PHI * PHI * PHI),
    };
}

pub fn TrinityInitializer(comptime seed: u64) type {
    return struct {
        prng: std.Random.DefaultPrng,

        pub fn init() @This() {
            return .{ .prng = std.Random.DefaultPrng.init(seed) };
        }

        pub fn fill(self: *@This(), buf: []f32, sector: Sector) void {
            const sigma: f64 = sectorStd(sector);
            const rng = self.prng.random();
            for (buf) |*val| {
                val.* = @as(f32, @floatCast(rng.floatNorm(f64) * sigma));
            }
        }

        pub fn fillMatrix(self: *@This(), matrix: [][]f32, sector: Sector) void {
            for (matrix) |row| {
                self.fill(row, sector);
            }
        }
    };
}

pub fn trinityKaimingStd(fan_in: usize, sector: Sector) f64 {
    const base = sectorStd(sector);
    const kaiming = std.math.sqrt(2.0 / @as(f64, @floatFromInt(fan_in)));
    return @min(base, kaiming);
}

test "sector std ordering" {
    const g = sectorStd(.gauge);
    const h = sectorStd(.higgs);
    const l = sectorStd(.lepton);
    const c = sectorStd(.cosmology);
    try std.testing.expect(g > h);
    try std.testing.expect(h > l);
    try std.testing.expect(l > c);
}

test "gauge std = alpha_phi" {
    try std.testing.expectApproxEqAbs(ALPHA_PHI, sectorStd(.gauge), 1e-10);
}

test "cosmology std ≈ 0.0279" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.027864), sectorStd(.cosmology), 1e-3);
}

test "trinity init fill produces correct variance" {
    var init = TrinityInitializer(42).init();
    var buf: [1000]f32 = undefined;
    init.fill(&buf, .gauge);

    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    for (buf) |v| {
        sum += @as(f64, v);
        sum_sq += @as(f64, v) * @as(f64, v);
    }
    const mean = sum / 1000.0;
    const variance = sum_sq / 1000.0 - mean * mean;
    const std_dev = std.math.sqrt(variance);
    try std.testing.expect(std_dev > 0.05 and std_dev < 0.2);
}

test "trinity kaiming respects fan_in" {
    const s1 = trinityKaimingStd(100, .gauge);
    const s2 = trinityKaimingStd(10000, .gauge);
    try std.testing.expect(s2 <= s1);
}
