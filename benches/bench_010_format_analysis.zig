//! BENCH-010 Format Analysis Suite — R5-honest
//!
//! Pre-registered MSE/ULP analysis for fp32, fp16, bf16, gf16, ternary
//!
//! Tests hypothesis H1: broken bf16 caused identical MSE on σ=0.1
//! After canonical fix, expects:
//! - bf16 MSE < GF16 MSE on Uniform [-100, +100]
//! - ULP_observed ≈ ULP_theoretical within 50% margin
//!
//! **Output:** .trinity/results/bench_010_format_analysis.log

const std = @import("std");
const formats = @import("src/formats/formats_root.zig");

// ═══════════════════════════════════════════════════════════════════
// Constants from R5-honest plan section 2.1
// ═════════════════════════════════════════════════════════════════════════

const RANDOM_SEED: u32 = 42;
const N_SAMPLES: usize = 10_000;

// Distribution parameters
const Distribution = enum {
    gaussian_001,
    gaussian_01,
    gaussian_1,
    gaussian_10,
    uniform_1,
    uniform_100,
};

fn getGaussianSigma(dist: Distribution) f32 {
    return switch (dist) {
        .gaussian_001 => 0.01,
        .gaussian_01 => 0.1,
        .gaussian_1 => 1.0,
        .gaussian_10 => 10.0,
        .uniform_1 => 0,  // Not applicable
        .uniform_100 => 0,
    };
}

fn getDistributionName(dist: Distribution) []const u8 {
    return switch (dist) {
        .gaussian_001 => "Gaussian σ=0.01",
        .gaussian_01 => "Gaussian σ=0.1",
        .gaussian_1 => "Gaussian σ=1.0",
        .gaussian_10 => "Gaussian σ=10.0",
        .uniform_1 => "Uniform ±1",
        .uniform_100 => "Uniform ±100",
    };
}

// ═════════════════════════════════════════════════════════════════════════
// ULP Theory
// ═════════════════════════════════════════════════════════════════════════

fn getMantissaBits(fmt: formats.Format) u32 {
    return switch (fmt) {
        .fp32 => 23,
        .fp16 => 10,
        .bf16 => 7,
        .gf16 => 9,
        .ternary => 0, // Not applicable
        .gf8 => 4,
        .gf32 => 18,
        .gf64 => 42,
    };
}

fn getExpBias(fmt: formats.Format) i32 {
    return switch (fmt) {
        .fp16 => 15,
        .bf16 => 127,
        .gf16 => 31,
        .ternary => 0, // Not applicable
        else => 0, // Placeholder
    };
}

fn ulpTheoretical(x: f32, fmt: formats.Format) f32 {
    if (fmt == .ternary) {
        // Ternary has no ULP concept - each value is -1, 0, or +1
        return std.math.inf(f32);
    }
    if (x == 0.0 or std.math.isNan(x) or std.math.isInf(x)) {
        return 0;
    }

    const mant_bits = getMantissaBits(fmt);
    const bias = getExpBias(fmt);

    // Get unbiased exponent: |x| = m * 2^E
    // For f32: E = exp - 127
    // For fp16/bf16/gf16: E is stored biased in the format
    var e: i32 = undefined;
    if (fmt == .fp32) {
        const bits = @as(u32, @bitCast(x));
        e = @as(i32, ((bits >> 23) & 0xFF)) - 127;
    } else {
        const exp_biased = @as(i32, @as(u16, @bitCast(@as(f32, x))) >> @as(u5, 16 - mant_bits));
        e = exp_biased - bias;
    }

    // ULP = 2^(-mantissa_bits) * 2^E
    const ulp = std.math.pow(f32, 2.0, -@as(f32, @floatFromInt(mant_bits))) *
              std.math.pow(f32, 2.0, @as(f32, @floatFromInt(e)));
    return @abs(ulp);
}

// ═══════════════════════════════════════════════════════════════════
// Distribution Generators
// ═══════════════════════════════════════════════════════════════════════

fn generateGaussian(rng: *std.Random.DefaultPrng, mu: f32, sigma: f32) f32 {
    // Box-Muller transform for normal distribution
    const u1 = rng.random();
    const u2 = rng.random();
    const z0 = std.math.sqrt(-2.0 * @as(f32, @log(u1)));
    const z1 = std.math.sqrt(-2.0 * @as(f32, @log(u2)));
    const z0 = z0 * @as(f32, std.math.cos(2.0 * std.math.pi * u1));
    const z1 = z1 * @as(f32, std.math.cos(2.0 * std.math.pi * u2));
    return mu + sigma * (z0 + z1) / 2.0;
}

fn generateUniform(rng: *std.Random.DefaultPrng, range: f32) f32 {
    return (rng.randomFloat(f32) - 0.5) * 2.0 * range;
}

fn generateSamples(dist: Distribution, rng: *std.Random.DefaultPrng, allocator: std.mem.Allocator) ![]f32 {
    const samples = try allocator.alloc(f32, N_SAMPLES);
    errdefer allocator.free(samples);

    if (dist == .uniform_1 or dist == .uniform_100) {
        const range = if (dist == .uniform_100) 100.0 else 1.0;
        for (0..N_SAMPLES) |_| {
            samples[i] = generateUniform(rng, range);
        }
    } else {
        const sigma = getGaussianSigma(dist);
        for (0..N_SAMPLES) |_| {
            samples[i] = generateGaussian(rng, 0.0, sigma);
        }
    }

    return samples;
}

// ═════════════════════════════════════════════════════════════════════
// Measurement
// ═════════════════════════════════════════════════════════════════════════

fn measureMSE(original: []const f32, encoded_decoded: []const f32) f32 {
    var sum_sq: f64 = 0.0;
    for (0..N_SAMPLES) |i| {
        const diff = @as(f64, original[i]) - @as(f64, encoded_decoded[i]);
        sum_sq += diff * diff;
    }
    return @as(f32, sum_sq / @as(f64, N_SAMPLES));
}

fn measureULPObserved(original: []const f32, encoded_decoded: []const f32) f32 {
    var max_err: f32 = 0.0;
    for (0..N_SAMPLES) |i| {
        const err = @abs(original[i] - encoded_decoded[i]);
        if (err > max_err) max_err = err;
    }
    return max_err;
}

fn isCollision(fmt_a: formats.Format, fmt_b: formats.Format, mse_a: f32, mse_b: f32) bool {
    // R5 collision threshold: |MSE_A - MSE_B| / MSE_A < 0.001
    const diff = @abs(mse_a - mse_b);
    const relative_diff = diff / mse_a;
    return relative_diff < 0.001;
}

// ═════════════════════════════════════════════════════════════════════════
// Main Benchmark
// ═══════════════════════════════════════════════════════════════════════════════════════════

fn runBenchmark(dist: Distribution, allocator: std.mem.Allocator) !void {
    const name = getDistributionName(dist);
    const stdout = std.io.getStdOut();

    std.debug.print("\n=== {s} ===\n", .{name});

    var rng = std.Random.DefaultPrng.init(RANDOM_SEED);
    const samples = try generateSamples(dist, &rng, allocator);
    defer allocator.free(samples);

    const formats_under_test = [_]formats.Format{ .fp32, .fp16, .bf16, .gf16, .ternary };

    for (formats_under_test) |fmt| {
        if (fmt == .fp32) {
            // fp32 baseline: MSE = 0, ULP = 0
            std.debug.print("RESULT=fp32 @ {s} {d} | MSE=0.0 ULP_th=0.0 ULP_obs=0.0 sha={any} bench=BENCH-010 status=pass\n",
                .{name}, N_SAMPLES, std.hash.truncate(std.hash.Wyhash.init(0), @as([]const u8, std.mem.sliceAsBytes(samples))));
            continue;
        }

        // Encode-decode
        var encoded_decoded = try allocator.alloc(f32, N_SAMPLES);
        defer allocator.free(encoded_decoded);
        for (0..N_SAMPLES) |i| {
            encoded_decoded[i] = formats.quantizeValue(samples[i], fmt);
        }

        // Measurements
        const mse = measureMSE(samples, encoded_decoded);
        const ulp_obs = measureULPObserved(samples, encoded_decoded);

        // Theoretical ULP at median value
        const median_idx = N_SAMPLES / 2;
        const ulp_th = ulpTheoretical(samples[median_idx], fmt);

        // Pass criterion: |ULP_obs - ULP_th| / ULP_th < 0.5
        const ulp_ratio = @abs(ulp_obs - ulp_th) / ulp_th;
        const pass_status = if (ulp_ratio < 0.5) "pass" else "fail";

        // Collision check with gf16
        const collision = if (fmt == .bf16 or fmt == .gf16) {
            isCollision(.gf16, .bf16, measureMSE(samples, try encodeDecodeSamples(.gf16, samples, allocator)),
        } else "";

        std.debug.print("RESULT={s} @ {s} {d} | MSE={e:.6} ULP_th={e:.6} ULP_obs={e:.6} sha={any} bench=BENCH-010 status={s}{s}\n",
            .{formats.formatBytes(fmt)}, name, N_SAMPLES, mse, ulp_th, ulp_obs,
            std.hash.truncate(std.hash.Wyhash.init(0), @as([]const u8, std.mem.sliceAsBytes(samples))),
            pass_status, collision);
    }
}

fn encodeDecodeSamples(fmt: formats.Format, samples: []const f32, allocator: std.mem.Allocator) ![]f32 {
    const result = try allocator.alloc(f32, samples.len);
    defer allocator.free(result);
    for (samples, 0..) |x, i| {
        result[i] = formats.quantizeValue(x, fmt);
    }
    return result;
}

pub fn main() !void {
    const stdout = std.io.getStdOut();

    std.debug.print("BENCH-010 Format Analysis — R5-honest\n", .{});
    std.debug.print("n={d} seed={d}\n", .{N_SAMPLES}, RANDOM_SEED);

    const distributions = [_]Distribution{
        .gaussian_001,
        .gaussian_01,
        .gaussian_1,
        .gaussian_10,
        .uniform_1,
        .uniform_100,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{});
    defer _ = gpa.deinit();

    for (distributions) |dist| {
        runBenchmark(dist, &gpa) catch |e| {
            std.debug.print("ERROR: {s}\n", .{@errorName(e)});
        };
    }

    std.debug.print("\n=== BENCH-010 COMPLETE ===\n", .{});
}
