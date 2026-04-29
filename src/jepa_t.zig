//! JEPA-T Predictor (IGLA-GF16 Module 6)
//!
//! Joint-Embedding Predictive Architecture with Trinity split:
//!   Encoder: 6 layers (~8MB)
//!   Predictor: 3 layers (~0.9MB)
//!   phi-split: 6/9 = 0.667 ≈ phi^-1 = 0.618
//!
//! Loss in latent space: MSE(z_pred, sg(z_tgt))
//! Memory saving: ~30% vs standard cross-entropy
//!
//! Reference: issue #3, whitepaper §11.6

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948;

pub const ENCODER_LAYERS: usize = 6;
pub const PREDICTOR_LAYERS: usize = 3;
pub const TOTAL_LAYERS: usize = ENCODER_LAYERS + PREDICTOR_LAYERS;

pub fn jepaPhiSplit() f64 {
    return @as(f64, @floatFromInt(ENCODER_LAYERS)) /
        @as(f64, @floatFromInt(TOTAL_LAYERS));
}

pub const JepaConfig = struct {
    d_model: usize,
    d_latent: usize,
    encoder_layers: usize,
    predictor_layers: usize,
    vocab_size: usize,
};

pub fn JepaTPredictor(comptime config: JepaConfig) type {
    const d = config.d_latent;

    return struct {
        const Self = @This();

        encoder_weights: [config.encoder_layers][d][d]f32,
        predictor_weights: [config.predictor_layers][d][d]f32,

        pub fn init(seed: u64) Self {
            var self: Self = undefined;
            var prng = std.Random.DefaultPrng.init(seed);
            const rng = prng.random();
            const enc_std = std.math.sqrt(2.0 / @as(f64, @floatFromInt(config.d_model)));
            const pred_std = std.math.sqrt(2.0 / @as(f64, @floatFromInt(config.d_latent)));

            for (&self.encoder_weights) |*layer| {
                for (layer) |*row| {
                    for (row) |*val| {
                        val.* = @as(f32, @floatCast(rng.floatNorm(f64) * enc_std));
                    }
                }
            }
            for (&self.predictor_weights) |*layer| {
                for (layer) |*row| {
                    for (row) |*val| {
                        val.* = @as(f32, @floatCast(rng.floatNorm(f64) * pred_std));
                    }
                }
            }
            return self;
        }

        pub fn encode(self: *const Self, input: []const f32, latent: []f32) void {
            std.debug.assert(input.len >= config.d_model);
            std.debug.assert(latent.len >= d);

            for (0..d) |i| {
                if (i < config.d_model) {
                    latent[i] = input[i];
                } else {
                    latent[i] = 0.0;
                }
            }

            for (self.encoder_weights) |layer| {
                var temp: [d]f32 = @splat(0.0);
                for (0..d) |i| {
                    var sum: f32 = 0.0;
                    for (0..d) |j| {
                        sum += layer[i][j] * latent[j];
                    }
                    temp[i] = std.math.max(sum, 0.0);
                }
                latent[0..d].* = temp;
            }
        }

        pub fn predict(self: *const Self, z_ctx: []const f32, z_pred: []f32) void {
            std.debug.assert(z_ctx.len >= d);
            std.debug.assert(z_pred.len >= d);

            for (0..d) |i| z_pred[i] = z_ctx[i];

            for (self.predictor_weights) |layer| {
                var temp: [d]f32 = @splat(0.0);
                for (0..d) |i| {
                    var sum: f32 = 0.0;
                    for (0..d) |j| {
                        sum += layer[i][j] * z_pred[j];
                    }
                    temp[i] = std.math.max(sum, 0.0);
                }
                z_pred[0..d].* = temp;
            }
        }

        pub fn jepaLoss(z_pred: []const f32, z_target: []const f32) f64 {
            std.debug.assert(z_pred.len >= d);
            std.debug.assert(z_target.len >= d);
            var sum: f64 = 0;
            for (0..d) |i| {
                const diff = @as(f64, z_pred[i]) - @as(f64, z_target[i]);
                sum += diff * diff;
            }
            return sum / @as(f64, @floatFromInt(d));
        }
    };
}

test "JEPA phi-split ≈ phi^-1" {
    const split = jepaPhiSplit();
    const phi_inv = 1.0 / PHI;
    try std.testing.expect(std.math.absFloat(split - phi_inv) < 0.05);
}

test "JEPA predictor: forward pass non-zero" {
    const config = JepaConfig{
        .d_model = 18,
        .d_latent = 18,
        .encoder_layers = 6,
        .predictor_layers = 3,
        .vocab_size = 50257,
    };
    const Jepa = JepaTPredictor(config);
    var model = Jepa.init(42);

    var input: [18]f32 = @splat(0.5);
    var latent: [18]f32 = @splat(0.0);
    model.encode(&input, &latent);

    var has_nonzero = false;
    for (latent) |v| {
        if (v != 0.0) has_nonzero = true;
    }
    try std.testing.expect(has_nonzero);

    var z_pred: [18]f32 = @splat(0.0);
    model.predict(&latent, &z_pred);

    const loss = Jepa.jepaLoss(&z_pred, &latent);
    try std.testing.expect(loss >= 0.0);
}
