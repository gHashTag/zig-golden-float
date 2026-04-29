//! TRI Format Code Generator
//! Reads .tri JSON spec files and generates language implementations.
//!
//! Usage: zig run tri_gen --lang [all|c|rust|zig|cpp] [--dry-run] [--input SPEC]

const std = @import("std");

const tri_reader = @import("tri_reader.zig");

// Writer buffers and io reference for Zig 0.16.0 I/O
var stdout_buffer: [4096]u8 = undefined;
var stderr_buffer: [4096]u8 = undefined;
var stdout_file_writer: std.Io.File.Writer = undefined;
var stderr_file_writer: std.Io.File.Writer = undefined;
var g_io: ?std.Io = null;

fn stdout() *std.Io.Writer {
    return &stdout_file_writer.interface;
}

fn stderr() *std.Io.Writer {
    return &stderr_file_writer.interface;
}

pub fn main(init: std.process.Init) !void {
    // Set global io reference and initialize writers
    g_io = init.io;
    // Create proper file writers for stdout/stderr
    stdout_file_writer = std.Io.File.writer(std.Io.File.stdout(), init.io, &stdout_buffer);
    stderr_file_writer = std.Io.File.writer(std.Io.File.stderr(), init.io, &stderr_buffer);
    defer g_io = null;

    // Zig 0.16.0 API: init.minimal.args contains command line arguments
    const alloc = init.gpa;

    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args_iter.deinit();

    // Skip executable name
    _ = args_iter.skip();

    // Parse arguments
    var lang: []const u8 = "all";
    var input: []const u8 = "specs/gf16.tri";
    var dry_run: bool = false;
    var verbose: bool = false;

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--lang") or std.mem.eql(u8, arg, "-l")) {
            lang = args_iter.next() orelse "all";
        } else if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            input = args_iter.next() orelse "specs/gf16.tri";
        } else if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-n")) {
            dry_run = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printHelp();
            return;
        }
    }

    // Load spec (pass io for Zig 0.16.0 compatibility)
    var spec = try tri_reader.load(alloc, g_io.?, input);
    defer spec.deinit(alloc);

    if (verbose) {
        try stderr().print("Loaded spec: {s} v{}\n", .{ spec.format, spec.version });
        try stderr().print("  Fields: {d}\n", .{spec.fields.len});
        try stderr().print("  Test vectors: {d}\n", .{spec.test_vectors.len});
    }

    // Generate based on language (stdout only)
    const generate_all = std.mem.eql(u8, lang, "all");

    if (generate_all or std.mem.eql(u8, lang, "c")) {
        try genC(alloc, g_io.?, spec, dry_run, verbose);
    }

    if (generate_all or std.mem.eql(u8, lang, "rust")) {
        try genRust(alloc, g_io.?, spec, dry_run, verbose);
    }

    if (generate_all or std.mem.eql(u8, lang, "zig")) {
        // For data_structure specs, use genStructTypes
        if (spec.spec_type != null and std.mem.eql(u8, spec.spec_type.?, "data_structure")) {
            try genStructTypes(alloc, g_io.?, spec, dry_run, verbose);
        } else {
            try genZig(alloc, g_io.?, spec, dry_run, verbose);
        }
    }

    if (generate_all or std.mem.eql(u8, lang, "cpp")) {
        try genCpp(alloc, g_io.?, spec, dry_run, verbose);
    }

    if (dry_run) {
        try stdout().writeAll("Dry-run complete (no files written)\n");
    }
}

fn printHelp() !void {
    try stdout().writeAll(
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
        try stdout().print("  [DRY] {s} ({d} bytes)\n", .{ path, content.len });
        return;
    }

    try stdout().writeAll(content);

    if (verbose) {
        try stdout().print("  {s} ({d} bytes)\n", .{ path, content.len });
    }
}

/// Helper function to read file contents (Zig 0.16.0 compatible)
fn readFileAlloc(allocator: std.mem.Allocator, io: std.Io, path: []const u8, max_bytes: usize) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer std.Io.File.close(file, io);

    // Get file size to read exact amount
    const stat_info = try std.Io.File.stat(file, io);
    const file_size = stat_info.size;

    // Clamp to max_bytes
    const read_size = @min(file_size, max_bytes);

    var read_buffer: [4096]u8 = undefined;
    var reader = std.Io.File.reader(file, io, &read_buffer);
    return try std.Io.Reader.readAlloc(&reader.interface, allocator, read_size);
}

fn genC(
    alloc: std.mem.Allocator,
    io: std.Io,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    _ = spec;

    const h_path = "tools/gen/templates/gf16.h";
    const c_path = "tools/gen/templates/gf16.c";

    const h_output = try readFileAlloc(alloc, io, h_path, 1024 * 1024);
    defer alloc.free(h_output);
    const c_output = try readFileAlloc(alloc, io, c_path, 1024 * 1024);
    defer alloc.free(c_output);

    try writeFile("c/gf16.h", h_output, dry_run, verbose);
    try writeFile("c/gf16.c", c_output, dry_run, verbose);
}

fn genRust(
    alloc: std.mem.Allocator,
    io: std.Io,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    _ = spec;

    const rust_path = "tools/gen/templates/gf16.rs";
    const output = try readFileAlloc(alloc, io, rust_path, 1024 * 1024);
    defer alloc.free(output);

    try writeFile("rust/src/lib.rs", output, dry_run, verbose);
}

fn genZig(
    alloc: std.mem.Allocator,
    io: std.Io,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    _ = spec;

    const zig_path = "tools/gen/templates/gf16.zig";
    const output = try readFileAlloc(alloc, io, zig_path, 1024 * 1024);
    defer alloc.free(output);

    try writeFile("zig/src/formats/gf16.zig", output, dry_run, verbose);
}

fn genCpp(
    alloc: std.mem.Allocator,
    io: std.Io,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    _ = spec;

    const cpp_path = "tools/gen/templates/gf16.hpp";
    const output = try readFileAlloc(alloc, io, cpp_path, 1024 * 1024);
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
    io: std.Io,
    spec: tri_reader.Spec,
    dry_run: bool,
    verbose: bool,
) !void {
    // alloc is used for filename allocation

    var buffer = try std.ArrayList(u8).initCapacity(alloc, 0);
    defer buffer.deinit(alloc);

    // Header
    try buffer.print(alloc,"// Auto-generated from {s} — DO NOT EDIT\n", .{spec.input_path});
    try buffer.print(alloc,"// Level {d} Data Structures\n", .{spec.level});
    try buffer.print(alloc,"\nconst std = @import(\"std\");\n\n", .{});

    // Generate constants
    for (spec.constants) |c| {
        try buffer.print(alloc,"pub const {s} = {s};\n", .{ c.name, c.value });
    }
    if (spec.constants.len > 0) try buffer.print(alloc,"\n", .{});

    // Generate types
    for (spec.types) |td| {
        // Handle enum type definitions (e.g., Color = enum { Red, Black })
        if (td.enum_values.len > 0 and td.variant == .enum_type) {
            try buffer.print(alloc,"pub const {s} = enum {{\n", .{td.name});
            for (td.enum_values, 0..) |val, i| {
                if (i > 0) try buffer.print(alloc,", ", .{});
                try buffer.print(alloc,"{s}", .{val});
            }
            try buffer.print(alloc,"}};\n\n", .{});
        } else if (td.generic) |generic| {
            // Transform generic syntax: [T] -> comptime T: type
            const generic_params = try transformGenericParams(alloc, generic);
            try buffer.print(alloc,"pub fn {s}({s}) type {{\n", .{ td.name, generic_params });
            try buffer.print(alloc,"    return struct {{\n", .{});
            for (td.fields) |f| {
                try buffer.print(alloc,"        {s}: {s},\n", .{ f.name, f.type });
            }
            try buffer.print(alloc,"    }};\n}}\n\n", .{});
        } else {
            try buffer.print(alloc,"pub const {s} = struct {{\n", .{td.name});
            for (td.fields) |f| {
                try buffer.print(alloc,"    {s}: {s},\n", .{ f.name, f.type });
            }
            try buffer.print(alloc,"}};\n\n", .{});
        }
    }

    // Generate ops as stubs
    try buffer.print(alloc,"// Operations\n", .{});
    for (spec.ops) |op| {
        if (op.description.len > 0) {
            try buffer.print(alloc,"/// {s}\n", .{op.description});
        }
        try buffer.print(alloc,"pub fn {s}(", .{op.name});
        for (op.inputs, 0..) |inp, i| {
            if (i > 0) try buffer.print(alloc,", ", .{});
            try buffer.print(alloc,"arg{d}: {s}", .{ i, inp });
        }
        try buffer.print(alloc,") {s} {{\n", .{op.output});
        try buffer.print(alloc,"    @compileError(\"TODO: implement {s}\");\n", .{op.name});
        try buffer.print(alloc,"}}\n\n", .{});
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
    // Zig 0.16.0 API: use std.Io.Dir.cwd().createDirPathOpen
    const out_subdir = try std.Io.Dir.cwd().createDirPathOpen(io, "zig/src/generated", .{});
    defer std.Io.Dir.close(out_subdir, io);
    try writeFile(filename, output, dry_run, verbose);
}
