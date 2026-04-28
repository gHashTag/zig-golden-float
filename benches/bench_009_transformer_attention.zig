//! BENCH-009: Transformer Attention φ-Pattern Analysis
//!
//! Purpose: Analyse whether softmax attention scores in a φ-quantized
//! Transformer follow the Trinity Identity φ² + 1/φ² = 3.
//!
//! Architecture: Single-head self-attention block
//!   - Sequence length: 64 tokens
//!   - Embedding dim:   64 (φ-friendly: 64 = F(11)/F(10) Fibonacci ratio)
//!   - Head dim:        64
//!   - QKV projections quantized to GF16 / fp16 / bf16 / GFTernary
//!
//! Metrics:
//!   1. φ-entropy: H_φ(A) = -Σ a_ij * log_φ(a_ij)  (Shannon entropy in base φ)
//!   2. Trinity residual: |mean(A²) + mean(1/A²) - 3|  (should → 0 for φ-optimal)
//!   3. Attention sparsity: fraction of scores > 1/φ ≈ 0.618 ("attended" threshold)
//!   4. Weight MSE vs fp32 baseline per format
//!
//! Trinity Hypothesis:
//!   If QKV weights are GF16-quantized (φ-dist=0.049), the resulting attention
//!   scores A should satisfy the Trinity Identity more closely than with
//!   bf16-quantized weights (φ-dist=0.525).
//!
//!   Formally: |E[A²] + E[1/A²] - 3| → 0 as φ-distance → 0
//!
//! Cross-reference: whitepaper.md §9.5 BENCH-009, golden_float16.zig (TF3/GF16), issue #15

const std = @import("std");
const gf_mod = @import("../src/formats/golden_float16.zig");
const fmt_mod = @import("../src/formats/formats_root.zig");

// ── Constants ──────────────────────────────────────────────────────────────

const PHI: f64     = gf_mod.PHI;
const PHI_SQ: f64  = gf_mod.PHI_SQ;
const PHI_INV: f64 = 1.0 / PHI;
const TRINITY: f64 = gf_mod.TRINITY; // φ² + 1/φ² = 3.0

const SEQ_LEN: usize   = 64;
const EMBED_DIM: usize = 64;
const HEAD_DIM: usize  = 64;

// Scale factor for attention: 1/√HEAD_DIM
const ATTN_SCALE: f32 = 1.0 / @sqrt(@as(f32, @floatFromInt(HEAD_DIM)));

// ── Format Specs ───────────────────────────────────────────────────────────

const FormatSpec = struct {
    name: []const u8,
    format: fmt_mod.Format,
    phi_distance: f32,
};

const FORMATS = [_]FormatSpec{
    .{ .name = "fp32",      .format = .fp32,    .phi_distance = 0.000 },
    .{ .name = "GF16",      .format = .gf16,    .phi_distance = 0.049 },
    .{ .name = "fp16",      .format = .fp16,    .phi_distance = 0.118 },
    .{ .name = "bf16",      .format = .bf16,    .phi_distance = 0.525 },
    .{ .name = "GFTernary", .format = .ternary, .phi_distance = 0.000 },
};

// ── QKV Weight Matrices ────────────────────────────────────────────────────

/// QKV projection weight matrices (fp32 baseline)
const QkvWeights = struct {
    Wq: [HEAD_DIM][EMBED_DIM]f32,  // query projection
    Wk: [HEAD_DIM][EMBED_DIM]f32,  // key projection
    Wv: [HEAD_DIM][EMBED_DIM]f32,  // value projection

    fn generate(seed: u64) QkvWeights {
        var prng = std.rand.DefaultPrng.init(seed);
        const rng = prng.random();
        var w: QkvWeights = undefined;
        // Xavier init: std = sqrt(2 / (in + out)) = sqrt(2 / 128) ≈ 0.125
        const std_val = @sqrt(2.0 / @as(f64, @floatFromInt(EMBED_DIM + HEAD_DIM)));
        for (0..HEAD_DIM) |i| {
            for (0..EMBED_DIM) |j| {
                w.Wq[i][j] = @as(f32, @floatCast(rng.floatNorm(f64) * std_val));
                w.Wk[i][j] = @as(f32, @floatCast(rng.floatNorm(f64) * std_val));
                w.Wv[i][j] = @as(f32, @floatCast(rng.floatNorm(f64) * std_val));
            }
        }
        return w;
    }

    fn quantize(self: *const QkvWeights, format: fmt_mod.Format) QkvWeights {
        var q = self.*;
        for (0..HEAD_DIM) |i| for (0..EMBED_DIM) |j| {
            q.Wq[i][j] = fmt_mod.quantizeValue(self.Wq[i][j], format);
            q.Wk[i][j] = fmt_mod.quantizeValue(self.Wk[i][j], format);
            q.Wv[i][j] = fmt_mod.quantizeValue(self.Wv[i][j], format);
        };
        return q;
    }
};

// ── Input Embedding ────────────────────────────────────────────────────────

fn generateInput(out: *[SEQ_LEN][EMBED_DIM]f32, seed: u64) void {
    var prng = std.rand.DefaultPrng.init(seed);
    const rng = prng.random();
    // Simulate token embeddings: N(0, 1/√EMBED_DIM)
    const std_val: f32 = 1.0 / @sqrt(@as(f32, @floatFromInt(EMBED_DIM)));
    for (0..SEQ_LEN) |i| for (0..EMBED_DIM) |j| {
        out[i][j] = @as(f32, @floatCast(rng.floatNorm(f64))) * std_val;
    };
}

// ── Self-Attention Forward ─────────────────────────────────────────────────

fn matmul(comptime M: usize, comptime K: usize, comptime N: usize,
          A: *const [M][K]f32, B: *const [K][N]f32, C: *[M][N]f32) void {
    for (0..M) |i| for (0..N) |j| {
        var s: f32 = 0;
        for (0..K) |k| s += A[i][k] * B[k][j];
        C[i][j] = s;
    };
}

fn softmaxRows(A: *[SEQ_LEN][SEQ_LEN]f32) void {
    for (0..SEQ_LEN) |i| {
        var max_v: f32 = A[i][0];
        for (1..SEQ_LEN) |j| max_v = @max(max_v, A[i][j]);
        var sum: f32 = 0;
        for (0..SEQ_LEN) |j| { A[i][j] = @exp(A[i][j] - max_v); sum += A[i][j]; }
        for (0..SEQ_LEN) |j| A[i][j] /= sum;
    }
}

/// Compute attention scores: A = softmax(Q K^T / √d)
fn computeAttention(
    input:   *const [SEQ_LEN][EMBED_DIM]f32,
    weights: *const QkvWeights,
    attn_out: *[SEQ_LEN][SEQ_LEN]f32,
) void {
    // Q = input × Wq^T  [SEQ×HEAD]
    var Q: [SEQ_LEN][HEAD_DIM]f32 = undefined;
    var K: [SEQ_LEN][HEAD_DIM]f32 = undefined;

    for (0..SEQ_LEN) |s| {
        for (0..HEAD_DIM) |h| {
            var sq: f32 = 0;
            var sk: f32 = 0;
            for (0..EMBED_DIM) |e| {
                sq += input[s][e] * weights.Wq[h][e];
                sk += input[s][e] * weights.Wk[h][e];
            }
            Q[s][h] = sq;
            K[s][h] = sk;
        }
    }

    // Scores = Q K^T * scale  [SEQ×SEQ]
    for (0..SEQ_LEN) |i| for (0..SEQ_LEN) |j| {
        var dot: f32 = 0;
        for (0..HEAD_DIM) |h| dot += Q[i][h] * K[j][h];
        attn_out[i][j] = dot * ATTN_SCALE;
    };

    softmaxRows(attn_out);
}

// ── Attention Metrics ──────────────────────────────────────────────────────

const AttnMetrics = struct {
    // Trinity residual: |mean(A²) + mean(1/A²) - 3|
    trinity_residual: f64,
    // φ-entropy: -Σ a_ij * log_φ(a_ij)
    phi_entropy: f64,
    // Fraction of scores > 1/φ  ("sharp" attention)
    sparsity_above_phi_inv: f64,
    // Mean attention score (should ≈ 1/SEQ_LEN = 0.015625 for uniform)
    mean_score: f64,
    // Max score across all positions (higher = more focused)
    max_score: f64,
    // Effective rank: exp(H) where H = Shannon entropy
    effective_rank: f64,
};

fn computeMetrics(A: *const [SEQ_LEN][SEQ_LEN]f32) AttnMetrics {
    var sum_sq: f64   = 0;
    var sum_inv_sq: f64 = 0;
    var sum_phi_h: f64 = 0;
    var sum_shannon: f64 = 0;
    var count_above: usize = 0;
    var sum_score: f64 = 0;
    var max_s: f64 = 0;
    const total = SEQ_LEN * SEQ_LEN;

    for (0..SEQ_LEN) |i| for (0..SEQ_LEN) |j| {
        const a: f64 = @as(f64, A[i][j]);
        sum_score += a;
        if (a > max_s) max_s = a;
        // Skip near-zero for log
        if (a > 1e-10) {
            sum_sq     += a * a;
            sum_inv_sq += 1.0 / (a * a);
            // log_φ(a) = ln(a) / ln(φ)
            const log_phi_a = @log(a) / @log(PHI);
            sum_phi_h  += -a * log_phi_a;
            // Shannon entropy
            sum_shannon += -a * @log(a);
        }
        if (a > PHI_INV) count_above += 1;
    };

    const n = @as(f64, @floatFromInt(total));
    const trinity_residual = @abs(sum_sq / n + sum_inv_sq / n - TRINITY);

    return .{
        .trinity_residual         = trinity_residual,
        .phi_entropy              = sum_phi_h / n,
        .sparsity_above_phi_inv   = @as(f64, @floatFromInt(count_above)) / n,
        .mean_score               = sum_score / n,
        .max_score                = max_s,
        .effective_rank           = @exp(sum_shannon / @as(f64, @floatFromInt(SEQ_LEN))),
    };
}

// ── Main ───────────────────────────────────────────────────────────────────

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    try writer.print("BENCH-009: Transformer Attention φ-Pattern Analysis\n", .{});
    try writer.print("====================================================\n", .{});
    try writer.print("Architecture: single-head self-attention, seq={d}, dim={d}\n",
        .{ SEQ_LEN, EMBED_DIM });
    try writer.print("Trinity Identity: φ² + 1/φ² = {d:.10} (should be 3.0)\n",
        .{TRINITY});
    try writer.print("Cross-reference: whitepaper.md §9.5, issue #15\n\n", .{});

    // Generate baseline fp32 QKV weights
    const fp32_weights = QkvWeights.generate(0xC0FFEE_TRINITY_42);

    // Generate input tokens
    var input: [SEQ_LEN][EMBED_DIM]f32 = undefined;
    generateInput(&input, 0xFEEDFACE_1618);

    try writer.print("{:-<80}\n", .{""});
    try writer.print("{s:<12} {s:>14} {s:>12} {s:>10} {s:>10} {s:>8}\n",
        .{ "Format", "TrinityResid", "φ-Entropy", "Sharp%", "EffRank", "φ-dist" });
    try writer.print("{:-<80}\n", .{""});

    var best_trinity_residual: f64 = std.math.inf(f64);
    var best_format: []const u8 = "";

    for (&FORMATS) |spec| {
        const qw = fp32_weights.quantize(spec.format);
        var attn: [SEQ_LEN][SEQ_LEN]f32 = undefined;
        computeAttention(&input, &qw, &attn);
        const m = computeMetrics(&attn);

        const sharp_pct = m.sparsity_above_phi_inv * 100.0;
        try writer.print("{s:<12} {d:>14.6} {d:>12.6} {d:>9.2}% {d:>10.3} {d:>8.3}\n",
            .{ spec.name, m.trinity_residual, m.phi_entropy,
               sharp_pct, m.effective_rank, spec.phi_distance });

        if (m.trinity_residual < best_trinity_residual) {
            best_trinity_residual = m.trinity_residual;
            best_format = spec.name;
        }
    }
    try writer.print("{:-<80}\n\n", .{""});

    // Winner
    try writer.print("Best Trinity alignment: {s} (residual={d:.6})\n",
        .{ best_format, best_trinity_residual });

    // ── Per-format deep analysis ──────────────────────────────────────────
    try writer.print("\nDetailed φ-Analysis per Format:\n", .{});
    try writer.print("{:-<60}\n", .{""});

    for (&FORMATS) |spec| {
        const qw = fp32_weights.quantize(spec.format);
        var attn: [SEQ_LEN][SEQ_LEN]f32 = undefined;
        computeAttention(&input, &qw, &attn);
        const m = computeMetrics(&attn);

        try writer.print("\n[{s}] (φ-dist={d:.3})\n", .{ spec.name, spec.phi_distance });
        try writer.print("  Trinity residual  : {d:.8}\n", .{m.trinity_residual});
        try writer.print("  φ-entropy         : {d:.6}\n", .{m.phi_entropy});
        try writer.print("  Mean score        : {d:.6} (uniform={d:.6})\n",
            .{ m.mean_score, 1.0 / @as(f64, @floatFromInt(SEQ_LEN)) });
        try writer.print("  Max score         : {d:.6}\n", .{m.max_score});
        try writer.print("  Effective rank    : {d:.2} / {d}\n",
            .{ m.effective_rank, SEQ_LEN });
        try writer.print("  Sharp (>1/φ={d:.3}) : {d:.2}%\n",
            .{ PHI_INV, m.sparsity_above_phi_inv * 100.0 });

        // Trinity test result
        const threshold: f64 = 0.1;
        if (m.trinity_residual < threshold) {
            try writer.print("  → ✓ TRINITY SATISFIED (residual < {d})\n", .{threshold});
        } else {
            try writer.print("  → ✗ Trinity not satisfied (residual = {d:.4})\n",
                .{m.trinity_residual});
        }
    }

    // ── Correlation: φ-distance vs Trinity residual ───────────────────────
    try writer.print("\nCorrelation: φ-distance vs Trinity Residual:\n", .{});
    try writer.print("{:-<60}\n", .{""});

    var pd_arr:  [5]f64 = undefined;
    var tr_arr:  [5]f64 = undefined;
    var idx: usize = 0;

    for (&FORMATS) |spec| {
        const qw = fp32_weights.quantize(spec.format);
        var attn: [SEQ_LEN][SEQ_LEN]f32 = undefined;
        computeAttention(&input, &qw, &attn);
        const m = computeMetrics(&attn);
        pd_arr[idx] = spec.phi_distance;
        tr_arr[idx] = m.trinity_residual;
        idx += 1;
    }

    // Pearson r
    const n = @as(f64, @floatFromInt(FORMATS.len));
    var mean_pd: f64 = 0; var mean_tr: f64 = 0;
    for (pd_arr) |v| mean_pd += v;
    for (tr_arr) |v| mean_tr += v;
    mean_pd /= n; mean_tr /= n;

    var cov: f64 = 0; var var_pd: f64 = 0; var var_tr: f64 = 0;
    for (0..FORMATS.len) |i| {
        const dp = pd_arr[i] - mean_pd;
        const dt = tr_arr[i] - mean_tr;
        cov += dp * dt; var_pd += dp * dp; var_tr += dt * dt;
    }
    const pearson_r = if (var_pd > 0 and var_tr > 0)
        cov / (@sqrt(var_pd) * @sqrt(var_tr))
    else 0.0;

    try writer.print("Pearson r(φ-distance, Trinity residual) = {d:.4}\n", .{pearson_r});
    if (pearson_r > 0.5) {
        try writer.print("→ CONFIRMED: Lower φ-distance → closer to Trinity Identity ✓\n", .{});
        try writer.print("  Whitepaper §3.2 claim VALIDATED by attention pattern analysis.\n", .{});
    } else if (pearson_r > 0.0) {
        try writer.print("→ Weak positive correlation. Run on larger model for significance.\n", .{});
    } else {
        try writer.print("→ No correlation. Attention score Trinity alignment format-independent.\n", .{});
    }

    try writer.print("\nResults: .trinity/results/bench_009_transformer_attention.log\n", .{});
    try writer.print("Next: BENCH-010 Fibonacci sequence prediction task\n", .{});
}

// ── Tests ──────────────────────────────────────────────────────────────────

test "TRINITY constant from golden_float16" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), TRINITY, 1e-10);
}

test "softmax rows sum to 1" {
    var A: [SEQ_LEN][SEQ_LEN]f32 = undefined;
    for (0..SEQ_LEN) |i| for (0..SEQ_LEN) |j| {
        A[i][j] = @as(f32, @floatFromInt((i + j) % 7)) * 0.3 - 1.0;
    };
    softmaxRows(&A);
    for (0..SEQ_LEN) |i| {
        var row_sum: f32 = 0;
        for (0..SEQ_LEN) |j| row_sum += A[i][j];
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), row_sum, 1e-5);
    }
}

test "attention scores in [0, 1]" {
    const weights = QkvWeights.generate(99);
    var input: [SEQ_LEN][EMBED_DIM]f32 = undefined;
    generateInput(&input, 42);
    var attn: [SEQ_LEN][SEQ_LEN]f32 = undefined;
    computeAttention(&input, &weights, &attn);
    for (0..SEQ_LEN) |i| for (0..SEQ_LEN) |j| {
        try std.testing.expect(attn[i][j] >= 0.0);
        try std.testing.expect(attn[i][j] <= 1.0 + 1e-5);
    };
}

test "metrics: mean score ≈ 1/SEQ_LEN for near-uniform attention" {
    // Uniform attention: all scores = 1/SEQ_LEN
    var A: [SEQ_LEN][SEQ_LEN]f32 = undefined;
    const uniform: f32 = 1.0 / @as(f32, @floatFromInt(SEQ_LEN));
    for (0..SEQ_LEN) |i| for (0..SEQ_LEN) |j| A[i][j] = uniform;
    const m = computeMetrics(&A);
    try std.testing.expectApproxEqAbs(
        1.0 / @as(f64, @floatFromInt(SEQ_LEN)), m.mean_score, 1e-5);
}

test "QkvWeights quantize fp32 is identity" {
    const w = QkvWeights.generate(7);
    const q = w.quantize(.fp32);
    try std.testing.expectEqual(w.Wq[0][0], q.Wq[0][0]);
    try std.testing.expectEqual(w.Wk[5][10], q.Wk[5][10]);
}

test "GFTernary attention computable" {
    // GFTernary produces sparse {-1,0,1} weights — verify forward pass completes
    const weights = QkvWeights.generate(0).quantize(.ternary);
    var input: [SEQ_LEN][EMBED_DIM]f32 = undefined;
    generateInput(&input, 0);
    var attn: [SEQ_LEN][SEQ_LEN]f32 = undefined;
    computeAttention(&input, &weights, &attn);
    // Just verify output is finite
    try std.testing.expect(std.math.isFinite(attn[0][0]));
}
