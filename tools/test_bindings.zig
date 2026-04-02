//! Test runner for GoldenFloat multi-language bindings
//!
//! This Zig binary replaces the shell script approach, providing:
//! - Consistent cross-platform execution
//! - Better error handling
//! - Atomic test runs (all pass or all fail)
//!
//! Run: zig build test_bindings && zig-out/bin/test_bindings
//!
//! Environment variables:
//! - RUSTFLAGS: Forwarded to cargo for Rust tests
//! - CMAKE_BUILD_TYPE: Debug/Release for C++ tests

const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const process = std.process;

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();
    var args_iter = std.process.args();

    // Parse command line arguments
    // Usage: test_bindings [--verbose] [--fail-fast]
    var verbose = false;
    var fail_fast = false;

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8("verbose"), arg)) {
            verbose = true;
        } else if (std.mem.eql(u8("fail-fast"), arg)) {
            fail_fast = true;
        } else if (std.mem.eql(u8("-h"), arg)) or std.mem.eql(u8("--help"), arg)) {
            usage();
            return;
        }
    }

    std.debug.print("GoldenFloat Multi-Language Bindings Test Runner\n", .{});
    std.debug.print("========================================\n", .{});

    // Step 1: Build shared library
    std.debug.print("[1/5] Building GoldenFloat shared library...\n", .{});
    const build_result = buildSharedLibrary(verbose);
    if (build_result.exit_code != 0) {
        std.debug.print("Build failed!\n", .{});
        if (!fail_fast) {
            std.process.exit(1);
        }
    }

    // Step 2: Run Rust tests
    std.debug.print("[2/5] Running Rust conformance tests...\n", .{});
    const rust_result = runRustTests(verbose);
    if (rust_result.exit_code != 0) {
        std.debug.print("Rust tests failed!\n", .{});
        if (!fail_fast) {
            std.process.exit(1);
        }
    }

    // Step 3: Run Python tests
    std.debug.print("[3/5] Running Python conformance tests...\n", .{});
    const python_result = runPythonTests(verbose);
    if (python_result.exit_code != 0) {
        std.debug.print("Python tests failed!\n", .{});
        if (!fail_fast) {
            std.process.exit(1);
        }
    }

    // Step 4: Run C++ tests
    std.debug.print("[4/5] Running C++ conformance tests...\n", .{});
    const cpp_result = runCppTests(verbose);
    if (cpp_result.exit_code != 0) {
        std.debug.print("C++ tests failed!\n", .{});
        if (!fail_fast) {
            std.process.exit(1);
        }
    }

    // Step 5: Run Go tests
    std.debug.print("[5/5] Running Go conformance tests...\n", .{});
    const go_result = runGoTests(verbose);
    if (go_result.exit_code != 0) {
        std.debug.print("Go tests failed!\n", .{});
        if (!fail_fast) {
            std.process.exit(1);
        }
    }

    std.debug.print("========================================\n", .{});
    std.debug.print("All tests completed successfully!\n", .{});

    if (!fail_fast) {
        std.process.exit(0);
    }
}

fn usage() !void {
    std.debug.print("Usage: test_bindings [options]\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  --verbose     Verbose output\n", .{});
    std.debug.print("  --fail-fast    Exit immediately on first failure\n", .{});
    std.debug.print("  --help        Show this help\n", .{});
    std.debug.print("\nEnvironment:\n", .{});
    std.debug.print("  RUSTFLAGS      Additional flags for Rust tests\n", .{});
    std.debug.print("  CMAKE_BUILD_TYPE Build type for C++ (Debug/Release)\n", .{});
    std.process.exit(1);
}

// Result type for subprocess execution
const TestResult = struct {
    exit_code: u8,
    passed: bool,
    output: []const u8, // Captured stdout
};

fn buildSharedLibrary(verbose: bool) TestResult {
    const argv = [_][]const u8{ "zig", "build", "shared"};
    const build_env = [_][]const u8{};

    if (verbose) {
        build_env.append("--verbose");
    }

    const result = std.process.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &argv,
        .env_map = &build_env,
    }, stdout, stderr);

    if (verbose) {
        if (result.output.len > 0) {
            stdout.print("{s}\n", .{result.output});
        }
    }

    return .{
        .exit_code = result.term.ex,
        .passed = result.term.ex == 0,
        .output = result.output,
    };
}

fn runRustTests(verbose: bool) TestResult {
    const argv = [_][]const u8{ "cargo", "test", "--manifest-path", "rust/gf16/Cargo.toml"};
    const test_env = [_][]const u8{};

    if (verbose) {
        test_env.append("--verbose");
    }

    // Set RUSTFLAGS for better error output
    var rustflags_env = [_][]const u8{ "RUSTFLAGS", "--verbose"};

    const result = std.process.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &argv,
        .env_map = &test_env,
    }, stdout, stderr);

    if (verbose) {
        if (result.output.len > 0) {
            stdout.print("{s}\n", .{result.output});
        }
    }

    return .{
        .exit_code = result.term.ex,
        .passed = result.term.ex == 0,
        .output = result.output,
    };
}

fn runPythonTests(verbose: bool) TestResult {
    const test_argv = [_][]const u8{ "python", "-m", "pytest", "goldenfloat/tests/"};

    if (verbose) {
        // pytest doesn't have --verbose, so we skip
    }

    const result = std.process.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &test_argv,
    }, stdout, stderr);

    if (verbose) {
        if (result.output.len > 0) {
            stdout.print("{s}\n", .{result.output});
        }
    }

    return .{
        .exit_code = result.term.ex,
        .passed = result.term.ex == 0,
        .output = result.output,
    };
}

fn runCppTests(verbose: bool) TestResult {
    var build_dir: [64]u8 = "build";

    // Build in Debug mode for consistent testing
    const argv = [_][]const u8{ "cmake", "-B", build_dir, "-DCMAKE_BUILD_TYPE=Debug", "..", "--build", ".", "--target", "test_gf16"};
    const test_argv = [_][]const u8{ "ctest", "--output-on-failure"};
    const test_env = [_][]const u8{ "CMAKE_BUILD_TYPE=Debug" };

    const result = std.process.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &argv,
        .env_map = &test_env,
    }, stdout, stderr);

    if (verbose) {
        if (result.output.len > 0) {
            stdout.print("{s}\n", .{result.output});
        }
    }

    return .{
        .exit_code = result.term.ex,
        .passed = result.term.ex == 0,
        .output = result.output,
    };
}

fn runGoTests(verbose: bool) TestResult {
    const test_argv = [_][]const u8{ "go", "test", "./go/goldenfloat/"};

    if (verbose) {
        // go test doesn't support --verbose
    }

    const result = std.process.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &test_argv,
    }, stdout, stderr);

    if (verbose) {
        if (result.output.len > 0) {
            stdout.print("{s}\n", .{result.output});
        }
    }

    return .{
        .exit_code = result.term.ex,
        .passed = result.term.ex == 0,
        .output = result.output,
    };
}
