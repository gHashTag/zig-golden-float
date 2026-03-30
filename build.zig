//! GoldenFloat — φ-Optimized Zig Kernel Build System
//! Zig 0.15 package system — module-only library

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─────────────────────────────────────────────────────────────────
    // Library module (what users import via @import("golden-float"))
    // ─────────────────────────────────────────────────────────────────
    _ = b.addModule("golden-float", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // ─────────────────────────────────────────────────────────────────
    // Tests — formats (GF16/TF3)
    // ─────────────────────────────────────────────────────────────────
    const formats_tests_root = b.createModule(.{
        .root_source_file = b.path("src/formats/golden_float16.zig"),
        .target = target,
        .optimize = optimize,
    });
    const formats_tests = b.addTest(.{
        .name = "formats-tests",
        .root_module = formats_tests_root,
    });

    const run_tests = b.addRunArtifact(formats_tests);
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
}
