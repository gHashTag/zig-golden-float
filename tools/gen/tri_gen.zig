//! TRI Format Code Generator
//! Reads .tri JSON spec files and generates language implementations.
//!
//! Usage: zig run tri_gen --lang [all|c|rust|zig|cpp] [--dry-run] [--input SPEC]

const std = @import("std");

const tri_reader = @import("tri_reader.zig");

const stdout_file = std.fs.File.stdout();
const stdout = stdout_file.deprecatedWriter();
const stderr_file = std.fs.File.stderr();
const stderr = stderr_file.deprecatedWriter();

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    // Parse arguments
    var lang: []const u8 = "all";
    var input: []const u8 = "specs/gf16.tri";
    var dry_run: bool = false;
    var verbose: bool = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--lang") or std.mem.eql(u8, arg, "-l")) {
            if (i + 1 < args.len) {
                lang = args[i + 1];
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            if (i + 1 < args.len) {
                input = args[i + 1];
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-n")) {
            dry_run = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printHelp();
            std.process.exit(0);
        }
    }

    // Load spec
    var spec = try tri_reader.load(alloc, input);
    defer spec.deinit(alloc);

    if (verbose) {
        try stderr.print("Loaded spec: {s} v{}\n", .{ spec.format, spec.version });
        try stderr.print("  Fields: {d}\n", .{spec.fields.len});
        try stderr.print("  Test vectors: {d}\n", .{spec.test_vectors.len});
    }

    // Generate based on language (stdout only)
    const generate_all = std.mem.eql(u8, lang, "all");

    if (generate_all or std.mem.eql(u8, lang, "c")) {
        try genC(alloc, spec, dry_run, verbose);
    }

    if (generate_all or std.mem.eql(u8, lang, "rust")) {
        try genRust(alloc, spec, dry_run, verbose);
    }

    if (generate_all or std.mem.eql(u8, lang, "zig")) {
        // For data_structure specs, use genStructTypes
        if (spec.spec_type != null and std.mem.eql(u8, spec.spec_type.?, "data_structure")) {
            try genStructTypes(alloc, spec, dry_run, verbose);
        } else {
            try genZig(alloc, spec, dry_run, verbose);
        }
    }

    if (generate_all or std.mem.eql(u8, lang, "cpp")) {
        try genCpp(alloc, spec, dry_run, verbose);
    }

    if (dry_run) {
        try stdout.writeAll("Dry-run complete (no files written)\n");
    }
}

fn printHelp() !void {
    try stdout.writeAll(
        \\TRI Format Code Generator
        \\
        \\Usage: zig run tri_gen [OPTIONS]
        \\
        \\Options:
        \\  --lang, -l      Language to generate (all|c|rust|zig|cpp) [default: all]
        \\  --input, -i     Input spec file [default: specs/gf16.tri]
        \\  --dry-run, -n   Show what would be generated without writing files
        \\  --verbose, -v   Show detailed progress
        \\  --help, -h      Show this help
        \\
        \\Examples:
        \\  zig run tri_gen --lang all
        \\  zig run tri_gen --lang rust
        \\  zig run tri_gen --dry-run --verbose
        \\
    );
}

fn writeFile(
    path: []const u8,
    content: []const u8,
    dry_run: bool,
    verbose: bool,
) !void {
    if (dry_run) {
        try stdout.print("  [DRY] {s} ({d} bytes)\n", .{ path, content.len });
        return;
    }

    try stdout.writeAll(content);

    if (verbose) {
        try stdout.print("  {s} ({d} bytes)\n", .{ path, content.len });
    }
}

fn genC(
    alloc: std.mem.Allocator,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    _ = spec;

    const h_path = "tools/gen/templates/gf16.h";
    const c_path = "tools/gen/templates/gf16.c";

    const h_output = try std.fs.cwd().readFileAlloc(alloc, h_path, .max_file_size);
    defer alloc.free(h_output);
    const c_output = try std.fs.cwd().readFileAlloc(alloc, c_path, .max_file_size);
    defer alloc.free(c_output);

    try writeFile("c/gf16.h", h_output, dry_run, verbose);
    try writeFile("c/gf16.c", c_output, dry_run, verbose);
}

fn genRust(
    alloc: std.mem.Allocator,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    _ = spec;

    const rust_path = "tools/gen/templates/gf16.rs";
    const output = try std.fs.cwd().readFileAlloc(alloc, rust_path, .max_file_size);
    defer alloc.free(output);

    try writeFile("rust/src/lib.rs", output, dry_run, verbose);
}

fn genZig(
    alloc: std.mem.Allocator,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    _ = spec;

    const zig_path = "tools/gen/templates/gf16.zig";
    const output = try std.fs.cwd().readFileAlloc(alloc, zig_path, .max_file_size);
    defer alloc.free(output);

    try writeFile("zig/src/formats/gf16.zig", output, dry_run, verbose);
}

fn genCpp(
    alloc: std.mem.Allocator,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    _ = spec;

    const cpp_path = "tools/gen/templates/gf16.hpp";
    const output = try std.fs.cwd().readFileAlloc(alloc, cpp_path, .max_file_size);
    defer alloc.free(output);

    try writeFile("cpp/gf16.hpp", output, dry_run, verbose);
}

/// Transform generic params from TRI syntax to Zig syntax
/// [T] -> comptime T: type
/// [K, V] -> comptime K: type, comptime V: type
/// [K, V, comptime M: usize] -> comptime K: type, comptime V: type, comptime M: usize
fn transformGenericParams(alloc: std.mem.Allocator, generic: []const u8) ![]const u8 {
    // Strip [ and ]
    if (generic.len < 2 or generic[0] != '[' or generic[generic.len - 1] != ']') {
        return alloc.dupe(u8, generic);
    }

    const params = generic[1 .. generic.len - 1];
    var buf = std.ArrayList(u8).initCapacity(alloc, 0) catch unreachable;
    defer buf.deinit(alloc);

    var iter = std.mem.splitScalar(u8, params, ',');
    var first = true;
    while (iter.next()) |param| {
        const trimmed = std.mem.trim(u8, param, " \t");
        if (trimmed.len == 0) continue;

        if (!first) try buf.appendSlice(alloc, ", ");
        first = false;

        // Check if param already has "comptime " prefix (with space for precise matching)
        if (std.mem.startsWith(u8, trimmed, "comptime ")) {
            try buf.appendSlice(alloc, trimmed);
        } else {
            try buf.appendSlice(alloc, "comptime ");
            try buf.appendSlice(alloc, trimmed);
            try buf.appendSlice(alloc, ": type");
        }
    }

    return buf.toOwnedSlice(alloc);
}

fn genStructTypes(
    alloc: std.mem.Allocator,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    // alloc is used for filename allocation

    var buffer = try std.ArrayList(u8).initCapacity(alloc, 0);
    defer buffer.deinit(alloc);

    const writer = buffer.writer(alloc);

    // Header
    try writer.print("// Auto-generated from {s} — DO NOT EDIT\n", .{spec.input_path});
    try writer.print("// Level {d} Data Structures\n", .{spec.level});
    try writer.print("\nconst std = @import(\"std\");\n\n", .{});

    // Generate constants
    for (spec.constants) |c| {
        try writer.print("pub const {s} = {s};\n", .{ c.name, c.value });
    }
    if (spec.constants.len > 0) try writer.print("\n", .{});

    // Generate types
    for (spec.types) |td| {
        // Handle enum type definitions (e.g., Color = enum { Red, Black })
        if (td.enum_values.len > 0 and td.variant == .enum_type) {
            try writer.print("pub const {s} = enum {{\n", .{td.name});
            for (td.enum_values, 0..) |val, i| {
                if (i > 0) try writer.print(", ", .{});
                try writer.print("{s}", .{val});
            }
            try writer.print("}};\n\n", .{});
        } else if (td.generic) |generic| {
            // Transform generic syntax: [T] -> comptime T: type
            const generic_params = try transformGenericParams(alloc, generic);
            try writer.print("pub fn {s}({s}) type {{\n", .{ td.name, generic_params });
            try writer.print("    return struct {{\n", .{});
            for (td.fields) |f| {
                try writer.print("        {s}: {s},\n", .{ f.name, f.type });
            }
            try writer.print("    }};\n}}\n\n", .{});
        } else {
            try writer.print("pub const {s} = struct {{\n", .{td.name});
            for (td.fields) |f| {
                try writer.print("    {s}: {s},\n", .{ f.name, f.type });
            }
            try writer.print("}};\n\n", .{});
        }
    }

    // Generate ops as stubs
    try writer.print("// Operations\n", .{});
    for (spec.ops) |op| {
        if (op.description.len > 0) {
            try writer.print("/// {s}\n", .{op.description});
        }
        try writer.print("pub fn {s}(", .{op.name});
        for (op.inputs, 0..) |inp, i| {
            if (i > 0) try writer.print(", ", .{});
            try writer.print("arg{d}: {s}", .{ i, inp });
        }
        try writer.print(") {s} {{\n", .{op.output});
        try writer.print("    @compileError(\"TODO: implement {s}\");\n", .{op.name});
        try writer.print("}}\n\n", .{});
    }

    const output = try buffer.toOwnedSlice(alloc);
    defer alloc.free(output);

    // Output filename based on format name (lowercase, replace special chars)
    var format_lower = try std.ArrayList(u8).initCapacity(alloc, spec.format.len);
    for (spec.format) |c| {
        try format_lower.append(alloc, std.ascii.toLower(c));
    }
    defer format_lower.deinit(alloc);
    const filename = try std.fmt.allocPrint(alloc, "zig/src/generated/{s}.zig", .{format_lower.items[0..]});
    defer alloc.free(filename);

    // Ensure directory exists before writing (zig/src/generated/)
    const basename = std.fs.path.basename(filename);
    const out_subdir = try std.fs.cwd().makeOpenPath("zig/src/generated", .{});
    try writeFile(out_subdir, basename, output, dry_run, verbose);
}
