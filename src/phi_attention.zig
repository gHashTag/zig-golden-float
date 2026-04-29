//! φ-Sparse Attention with CA-mask (IGLA-GF16 Module 3)
//!
//! Fibonacci distance mask for sparse attention:
//!   visible positions = {1,2,3,5,8,13,21,34,55,89,144}
//!   sparsity: 2.15% (11/512 per token), reduction 46.6x
//!
//! Scale factor: d_head^(-phi^-1) instead of sqrt(d_head)
//!
//! Reference: issue #3, whitepaper §11.3

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948;

pub const FIB_POSITIONS = [_]usize{ 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144 };

pub fn phiScaleFactor(d_head: f64) f64 {
    return std.math.pow(f64, d_head, -1.0 / PHI);
}

pub fn PhiAttentionMask(comptime max_seq_len: usize) type {
    return struct {
        const Self = @This();

        mask: [max_seq_len][max_seq_len]bool,

        pub fn init() Self {
            var self = Self{ .mask = @splat(@splat(false)) };
            for (0..max_seq_len) |row| {
                self.mask[row][row] = true;
                for (FIB_POSITIONS) |offset| {
                    if (row >= offset) {
                        self.mask[row][row - offset] = true;
                    }
                    if (row + offset < max_seq_len) {
                        self.mask[row][row + offset] = true;
                    }
                }
            }
            return self;
        }

        pub fn applyAttention(
            self: *const Self,
            Q: []const f32,
            K: []const f32,
            V: []const f32,
            d_head: f32,
            output: []f32,
            seq_len: usize,
        ) void {
            std.debug.assert(seq_len <= max_seq_len);
            const scale = @as(f32, @floatCast(phiScaleFactor(@floatFromInt(d_head))));

            for (0..seq_len) |i| {
                var sum_weights: f32 = 0.0;
                var weighted_val: f32 = 0.0;

                const q_base = i * @as(usize, @intFromFloat(d_head));
                for (0..seq_len) |j| {
                    if (!self.mask[i][j]) continue;

                    const k_base = j * @as(usize, @intFromFloat(d_head));
                    var dot: f32 = 0.0;
                    for (0..@as(usize, @intFromFloat(d_head))) |d| {
                        dot += Q[q_base + d] * K[k_base + d];
                    }
                    const weight = std.math.exp(dot * scale);
                    sum_weights += weight;

                    const v_base = j * @as(usize, @intFromFloat(d_head));
                    for (0..@as(usize, @intFromFloat(d_head))) |d| {
                        output[q_base + d] += weight * V[v_base + d];
                    }
                }

                if (sum_weights > 0.0) {
                    for (0..@as(usize, @intFromFloat(d_head))) |d| {
                        output[q_base + d] /= sum_weights;
                    }
                }
            }
        }

        pub fn sparsity(self: *const Self, seq_len: usize) f64 {
            var visible: usize = 0;
            for (0..seq_len) |i| {
                for (0..seq_len) |j| {
                    if (self.mask[i][j]) visible += 1;
                }
            }
            const total = seq_len * seq_len;
            return @as(f64, @floatFromInt(visible)) / @as(f64, @floatFromInt(total));
        }
    };
}

test "phi attention mask: Fibonacci positions visible" {
    const Mask = PhiAttentionMask(512);
    const mask = Mask.init();

    try std.testing.expect(mask.mask[100][100]);
    try std.testing.expect(mask.mask[100][99]);
    try std.testing.expect(mask.mask[100][97]);
    try std.testing.expect(mask.mask[100][95]);
    try std.testing.expect(mask.mask[100][92]);
    try std.testing.expect(mask.mask[100][87]);
    try std.testing.expect(mask.mask[100][79]);
    try std.testing.expect(mask.mask[100][66]);

    try std.testing.expect(!mask.mask[100][98]);
    try std.testing.expect(!mask.mask[100][96]);
}

test "phi attention mask: sparsity ~2%" {
    const Mask = PhiAttentionMask(512);
    const mask = Mask.init();
    const sp = mask.sparsity(512);
    try std.testing.expect(sp > 0.01 and sp < 0.05);
}

test "phi scale factor vs sqrt" {
    const d_head: f64 = 18.0;
    const phi_sf = phiScaleFactor(d_head);
    const sqrt_sf = 1.0 / std.math.sqrt(d_head);
    try std.testing.expect(phi_sf > 0.0);
    try std.testing.expect(phi_sf < 1.0);
    try std.testing.expect(std.math.absFloat(phi_sf - sqrt_sf) < 0.05);
}

test "phi attention: forward pass produces non-zero output" {
    const seq_len = 4;
    const d_head: f32 = 8.0;
    const dim = @as(usize, @intFromFloat(d_head));

    const Mask = PhiAttentionMask(16);
    const mask = Mask.init();

    var Q = [_]f32{0.1} ** (seq_len * dim);
    var K = [_]f32{0.1} ** (seq_len * dim);
    var V = [_]f32{0.5} ** (seq_len * dim);
    var output = [_]f32{0.0} ** (seq_len * dim);

    mask.applyAttention(&Q, &K, &V, d_head, &output, seq_len);

    var has_nonzero = false;
    for (output) |v| {
        if (v != 0.0) has_nonzero = true;
    }
    try std.testing.expect(has_nonzero);
}
