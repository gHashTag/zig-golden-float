const std = @import("std");
const tc = @import("../src/trinity_constants.zig");
const jepa = @import("../src/jepa_t.zig");

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    try writer.print("IGLA-GF16 Architecture Verification\n", .{});
    try writer.print("====================================\n\n", .{});

    try writer.print("Architecture:\n", .{});
    try writer.print("  d_model  = {}  (Fib(12))\n", .{tc.D_MODEL});
    try writer.print("  n_heads  = {}  (Fib(6))\n", .{tc.N_HEADS});
    try writer.print("  d_head   = {}  (d_model/n_heads)\n", .{tc.D_HEAD});
    try writer.print("  d_ffn    = {}  (Fib(13) = d_model*phi)\n", .{tc.D_FFN});
    try writer.print("  n_layers = {}\n", .{tc.N_LAYERS});
    try writer.print("  vocab    = {}  (GPT-2 BPE)\n\n", .{tc.VOCAB});

    const total_mb = jepa.totalMB();
    const encoder_params = jepa.encoderParams();
    const predictor_params = jepa.predictorParams();
    const total_params = jepa.totalParams();

    try writer.print("Parameter Count:\n", .{});
    try writer.print("  Encoder:    {d:>12} params ({d:.1} MB GF16)\n", .{ encoder_params, @as(f64, @floatFromInt(encoder_params)) * 2.0 / 1048576.0 });
    try writer.print("  Predictor:  {d:>12} params ({d:.1} MB GF16)\n", .{ predictor_params, @as(f64, @floatFromInt(predictor_params)) * 2.0 / 1048576.0 });
    try writer.print("  Total:      {d:>12} params ({d:.1} MB GF16)\n", .{ total_params, total_mb });
    try writer.print("  Budget:     16.0 MB GF16 — {}\n\n", .{if (total_mb <= 16.0) "PASS" else "FAIL"});

    try writer.print("Trinity Constants:\n", .{});
    try writer.print("  PHI          = {d:.16}\n", .{tc.PHI});
    try writer.print("  PHI^2        = {d:.16}\n", .{tc.PHI_SQ});
    try writer.print("  1/PHI^2      = {d:.16}\n", .{tc.PHI_INV_SQ});
    try writer.print("  Trinity      = {d:.16} (should be 3.0)\n", .{tc.TRINITY});
    try writer.print("  ALPHA_PHI    = {d:.16} (= phi - 1.5)\n", .{tc.ALPHA_PHI});
    try writer.print("  phi-split    = {d:.3} (encoder/predictor)\n\n", .{jepa.PhiSplit});

    try writer.print("Proofs:\n", .{});
    const trinity_err = @abs(tc.TRINITY - 3.0);
    try writer.print("  [1] Trinity Identity  |phi^2+1/phi^2 - 3| = {e}  {}\n", .{ trinity_err, if (trinity_err < 1e-12) "PASS" else "FAIL" });
    const fib_proof = @as(f64, @floatFromInt(tc.D_MODEL)) * tc.PHI;
    const fib_err = @abs(fib_proof - @as(f64, @floatFromInt(tc.D_FFN)));
    try writer.print("  [5] Fib proof  144*phi = {d:.2} vs d_ffn={d}  |err|={e}  {}\n\n", .{ fib_proof, @as(f64, @floatFromInt(tc.D_FFN)), fib_err, if (fib_err < 0.1) "PASS" else "FAIL" });
}
