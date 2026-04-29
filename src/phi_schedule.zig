//! φ-LR Schedule (IGLA-GF16 Module 5)
//!
//! LR(t) = alpha_phi * phi^(-t/tau) where tau = T/(phi*27) = 228.9 steps
//! Warmup: linear to alpha_phi over Fib(7) = 21 steps
//! The constant 27 = 3^3 = (phi^2 + phi^-2)^3 from Trinity Identity
//!
//! Reference: issue #3, whitepaper §11.5

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948;
pub const ALPHA_PHI: f64 = 0.1180339887498948;
pub const WARMUP_STEPS: usize = 21;

pub fn phiLrSchedule(step: usize, total_steps: usize) f64 {
    if (step == 0) return 0.0;
    if (step <= WARMUP_STEPS) {
        return ALPHA_PHI * @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(WARMUP_STEPS));
    }
    const tau = @as(f64, @floatFromInt(total_steps)) / (PHI * 27.0);
    const t = @as(f64, @floatFromInt(step - WARMUP_STEPS));
    return ALPHA_PHI * std.math.pow(f64, PHI, -t / tau);
}

pub fn phiCosineSchedule(step: usize, total_steps: usize) f64 {
    if (step == 0) return 0.0;
    if (step <= WARMUP_STEPS) {
        return ALPHA_PHI * @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(WARMUP_STEPS));
    }
    const progress = @as(f64, @floatFromInt(step - WARMUP_STEPS)) /
        @as(f64, @floatFromInt(total_steps - WARMUP_STEPS));
    const cosine_factor = 0.5 * (1.0 + std.math.cos(std.math.pi * progress));
    return ALPHA_PHI * cosine_factor;
}

pub fn PhiLrIterator(comptime total_steps: usize) type {
    return struct {
        step: usize = 0,

        pub fn next(self: *@This()) f64 {
            const lr = phiLrSchedule(self.step, total_steps);
            self.step += 1;
            return lr;
        }

        pub fn reset(self: *@This()) void {
            self.step = 0;
        }
    };
}

test "phi LR: warmup phase" {
    const lr0 = phiLrSchedule(0, 5000);
    try std.testing.expectEqual(@as(f64, 0.0), lr0);

    const lr1 = phiLrSchedule(1, 5000);
    try std.testing.expect(lr1 > 0.0 and lr1 < ALPHA_PHI);

    const lr21 = phiLrSchedule(21, 5000);
    try std.testing.expectApproxEqAbs(ALPHA_PHI, lr21, 1e-6);
}

test "phi LR: decay phase decreases" {
    const lr100 = phiLrSchedule(100, 5000);
    const lr1000 = phiLrSchedule(1000, 5000);
    const lr5000 = phiLrSchedule(5000, 5000);
    try std.testing.expect(lr100 > lr1000);
    try std.testing.expect(lr1000 > lr5000);
}

test "phi LR: iterator" {
    var iter = PhiLrIterator(100).init();
    const lr0 = iter.next();
    const lr1 = iter.next();
    const lr21 = blk: {
        for (0..19) |_| _ = iter.next();
        break :blk iter.next();
    };
    try std.testing.expectEqual(@as(f64, 0.0), lr0);
    try std.testing.expect(lr1 > 0.0);
    try std.testing.expectApproxEqAbs(ALPHA_PHI, lr21, 1e-6);
}

test "phi cosine: warmup same as phi schedule" {
    const lr_phi = phiLrSchedule(10, 5000);
    const lr_cos = phiCosineSchedule(10, 5000);
    try std.testing.expectApproxEqAbs(lr_phi, lr_cos, 1e-10);
}
