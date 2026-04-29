//! GoldenFloat — φ-Optimized Zig Kernel Build System
//! Zig 0.15 package system — module-only library
//!
//! **Build Targets:**
//! - `zig build` — Build module only
//! - `zig build test` — Run all tests
//! - `zig build shared` — Build libgoldenfloat.{so,dylib,dll}
//! - `zig build c-abi-test` — Test C-ABI layer

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
    // tri_gen executable — code generator from .tri specs
    // ─────────────────────────────────────────────────────────────────
    const tri_gen_module = b.createModule(.{
        .root_source_file = b.path("tools/gen/tri_gen.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tri_gen = b.addExecutable(.{
        .name = "tri_gen",
        .root_module = tri_gen_module,
    });

    b.installArtifact(tri_gen);

    const run_tri_gen = b.addRunArtifact(tri_gen);
    const gen_step = b.step("gen", "Generate code from .tri specs");
    gen_step.dependOn(&run_tri_gen.step);

    // ─────────────────────────────────────────────────────────────────
    // C-ABI Shared Library — libgoldenfloat.{so,dylib,dll}
    // ─────────────────────────────────────────────────────────────────
    const c_abi_module = b.createModule(.{
        .root_source_file = b.path("src/c_abi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const c_abi_lib = b.addLibrary(.{
        .name = "goldenfloat",
        .root_module = c_abi_module,
        .linkage = .dynamic,
        .version = .{ .major = 1, .minor = 1, .patch = 0 },
    });

    const c_abi_install = b.addInstallArtifact(c_abi_lib, .{});

    const header_install = b.addInstallHeaderFile(b.path("src/c/gf16.h"), "gf16.h");

    const shared_step = b.step("shared", "Build C-ABI shared library (libgoldenfloat)");
    shared_step.dependOn(&c_abi_install.step);
    shared_step.dependOn(&header_install.step);

    // ─────────────────────────────────────────────────────────────────
    // C-ABI Tests
    // ─────────────────────────────────────────────────────────────────
    const c_abi_test_module = b.createModule(.{
        .root_source_file = b.path("src/c_abi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const c_abi_tests = b.addTest(.{
        .name = "c-abi-tests",
        .root_module = c_abi_test_module,
    });

    const run_c_abi_tests = b.addRunArtifact(c_abi_tests);
    const c_abi_test_step = b.step("c-abi-test", "Run C-ABI tests");
    c_abi_test_step.dependOn(&run_c_abi_tests.step);

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

    // ─────────────────────────────────────────────────────────────────
    // Tests — transcendental functions (Wave 4B)
    // ─────────────────────────────────────────────────────────────────
    const transcendent_tests_root = b.createModule(.{
        .root_source_file = b.path("src/math/transcendental.zig"),
        .target = target,
        .optimize = optimize,
    });
    const transcendent_tests = b.addTest(.{
        .name = "transcendent-tests",
        .root_module = transcendent_tests_root,
    });

    const run_tests = b.addRunArtifact(formats_tests);
    const run_transcendent_tests = b.addRunArtifact(transcendent_tests);

    // ─────────────────────────────────────────────────────────────────
    // Tests — Trinity Constants (IGLA-GF16 Module 1)
    // ─────────────────────────────────────────────────────────────────
    const trinity_tests_root = b.createModule(.{
        .root_source_file = b.path("src/trinity_constants.zig"),
        .target = target,
        .optimize = optimize,
    });
    const trinity_tests = b.addTest(.{
        .name = "trinity-constants-tests",
        .root_module = trinity_tests_root,
    });
    const run_trinity_tests = b.addRunArtifact(trinity_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_transcendent_tests.step);
    test_step.dependOn(&run_c_abi_tests.step);
    test_step.dependOn(&run_trinity_tests.step);

    // ─────────────────────────────────────────────────────────────────
    // Benchmarks
    // ─────────────────────────────────────────────────────────────────
    const bench_008_module = b.createModule(.{
        .root_source_file = b.path("benches/bench_008_fashion_mnist.zig"),
        .target = target,
        .optimize = optimize,
    });
    const bench_008 = b.addExecutable(.{
        .name = "bench_008_fashion_mnist",
        .root_module = bench_008_module,
    });
    const run_bench_008 = b.addRunArtifact(bench_008);
    const bench_008_step = b.step("bench-008", "Run BENCH-008: Fashion-MNIST MLP Quantization Validation");
    bench_008_step.dependOn(&run_bench_008.step);

    const bench_009_module = b.createModule(.{
        .root_source_file = b.path("benches/bench_009_transformer_attention.zig"),
        .target = target,
        .optimize = optimize,
    });
    const bench_009 = b.addExecutable(.{
        .name = "bench_009_transformer_attention",
        .root_module = bench_009_module,
    });
    const run_bench_009 = b.addRunArtifact(bench_009);
    const bench_009_step = b.step("bench-009", "Run BENCH-009: Transformer Attention Pattern Analysis");
    bench_009_step.dependOn(&run_bench_009.step);

    const bench_step = b.step("bench", "Run all benchmarks");
    bench_step.dependOn(&run_bench_008.step);
    bench_step.dependOn(&run_bench_009.step);
}
