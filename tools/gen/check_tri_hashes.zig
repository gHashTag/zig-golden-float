//! TRI-HASHES — Verify .tri specification integrity
//!
//! Usage: zig run check_tri_hashes --update|--verify
//!
//! Modes:
//!   --update    : Calculate and store hashes of all .tri specs
//!   --verify    : Verify stored hashes match current files

const std = @import("std");
const reader = @import("tri_reader.zig");

const HashesFile = ".trinity/tri_hashes.json";

pub const Mode = enum {
    update,
    verify,
};

pub const HashRecord = struct {
    gene: []const u8,
    level: u8,
    file: []const u8,
    version: u8,
    sha256: []const u8,
    last_modified: i64,
};

pub const Hashes = struct {
    records: []HashRecord,
    version: u8 = 1,
};

/// Calculate SHA256 hash of a .tri specification file
fn calculateSha256(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    const content = try std.fs.cwd().readFileAlloc(alloc, path, .{});
    defer alloc.free(content);

    const hash_result = std.crypto.hash.sha2(content);

    // Convert to hex string
    var hash_hex: [256]u8 = undefined;
    for (hash_result, 0..) |byte, i| {
        const hex = std.fmt.hexByteLower(byte);
        hash_hex[i * 2] = hex[0];
        hash_hex[i * 2 + 1] = hex[1];
    }

    return try alloc.dupeZ(alloc, &hash_hex);
}

/// Read existing hashes from JSON file
fn readHashes(alloc: std.mem.Allocator) !Hashes {
    const path = try std.fs.cwd().joinAlloc(alloc, HashesFile);
    const file = std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(content);

    if (content.len == 0) {
        return Hashes{ .records = &.{} };
    }

    const parsed = try std.json.parseFromSlice(Hashes, content, alloc);
    return parsed;
}

/// Write hashes to JSON file
fn writeHashes(alloc: std.mem.Allocator, hashes: Hashes) !void {
    const path = try std.fs.cwd().joinAlloc(alloc, HashesFile);
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    const content = try std.json.stringifyAlloc(alloc, hashes, .{ .whitespace = .indent_4 });
    defer alloc.free(content);

    try file.writeAll(content);
}

/// Get SHA256 and last modified time
fn getFileHashAndTime(alloc: std.mem.Allocator, path: []const u8) !struct { sha256: []const u8, modified: i64 } {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(content);

    const sha256 = try calculateSha256(alloc, path);
    return .{ .sha256 = sha256, .modified = stat.mtime };
}

/// Process all .tri specs in specs directory
fn processAllSpecs(alloc: std.mem.Allocator) !void {
    const dir = try std.fs.cwd().openDir("specs", .{});
    defer dir.close();

    var records = std.ArrayList(HashRecord).init(alloc);
    defer {
        records.deinit();
        var it = dir.iterate();
        while (try it.next()) |entry| {
            const ext = std.fs.path.extension(entry.name);
            if (!std.mem.eql(u8, ext, "tri")) continue;

            const file_path = try std.fs.path.join(alloc, &[_]u8{ "specs", "/", entry.name });
            const { sha256, modified } = getFileHashAndTime(alloc, file_path);

            // Extract gene, level, file name
            const last_slash = std.mem.lastIndexOfScalar(u8, entry.name, '/');
            const without_ext = if (last_slash != null)
                entry.name[0..last_slash.?]
            else
                entry.name[0 .. entry.name.len - 4];

            try records.append(.{
                .gene = without_ext,
                .level = 1, // Default level for ops.tri
                .file = entry.name,
                .version = 1,
                .sha256 = sha256,
                .last_modified = modified,
            });
        }
    }

    const hashes = Hashes{ .records = try records.toOwnedSlice() };

    try writeHashes(alloc, hashes);
}

/// Verify stored hashes against current files
fn verifyHashes(alloc: std.mem.Allocator, stored: Hashes) !void {
    var mismatch_count: usize = 0;

    for (stored.records) |record| {
        const file_path = try std.fs.path.join(alloc, &[_]u8{ "specs", "/", record.file });
        const { sha256, modified } = getFileHashAndTime(alloc, file_path);

        const matches = std.mem.eql(u8, sha256, record.sha256);

        if (!matches) {
            std.debug.print("HASH MISMATCH: {s}", .{record.file});
            std.debug.print("  Expected: {s}", .{record.sha256});
            std.debug.print("  Current: {s}", .{sha256});
            mismatch_count += 1;
        }
    }

    if (mismatch_count == 0) {
        std.debug.print("All {d} .tri file hashes verified", .{stored.records.len});
    } else {
        std.debug.print("FAIL: {d} hash mismatches found", .{mismatch_count});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{});
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var mode: Mode = .update;

    // Parse arguments
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--update") or std.mem.eql(u8, arg, "-u")) {
            mode = .update;
        } else if (std.mem.eql(u8, arg, "--verify") or std.mem.eql(u8, arg, "-v")) {
            mode = .verify;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printHelp();
            std.process.exit(0);
        }
    }

    switch (mode) {
        .update => processAllSpecs(alloc),
        .verify => {
            const stored = try readHashes(alloc);
            defer alloc.free(stored.records);
            verifyHashes(alloc, stored);
        },
    }
}

fn printHelp() !void {
    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\TRI-HASHES: Verify .tri specification integrity

Usage:
  zig run check_tri_hashes --update    : Calculate and store hashes
  zig run check_tri_hashes --verify     : Verify stored hashes match current files

Examples:
  # Update hashes after modifying specs
  zig run check_tri_hashes --update

  # Verify before committing
  zig run check_tri_hashes --verify
    \\
    ,
    );
}
