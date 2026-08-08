//! TRI-HASHES: seal the .tri specifications against silent drift.
//!
//!   zig run tools/gen/check_tri_hashes.zig -- --update
//!   zig run tools/gen/check_tri_hashes.zig -- --verify
//!
//! --update rewrites specs/TRI-HASHES.md from what is on disk.
//! --verify re-hashes and compares, and EXITS NON-ZERO on any mismatch,
//! any unsealed spec, and any sealed spec that has disappeared. A gate that
//! cannot fail is not a gate.
const std = @import("std");
const Io = std.Io;

const HashesFile = "specs/TRI-HASHES.md";
const SpecsDir = "specs";

pub const Mode = enum { update, verify };

const Record = struct {
    name: []const u8, // e.g. "gft.tri"
    sha256: [64]u8, // lowercase hex
};

fn lessByName(_: void, a: Record, b: Record) bool {
    return std.mem.lessThan(u8, a.name, b.name);
}

fn hashFile(io: Io, alloc: std.mem.Allocator, dir: Io.Dir, name: []const u8) ![64]u8 {
    const file = try dir.openFile(io, name, .{});
    defer file.close(io);

    var buf: [64 * 1024]u8 = undefined;
    var reader = file.readerStreaming(io, &buf);
    const content = try reader.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(content);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(content, &digest, .{});

    var hex: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&hex, "{x}", .{&digest}) catch unreachable;
    return hex;
}

/// Hash every specs/*.tri, sorted by name so the table is deterministic.
fn collect(io: Io, alloc: std.mem.Allocator) ![]Record {
    var dir = try Io.Dir.cwd().openDir(io, SpecsDir, .{ .iterate = true });
    defer dir.close(io);

    var out: std.ArrayList(Record) = .empty;
    errdefer out.deinit(alloc);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".tri")) continue;
        try out.append(alloc, .{
            .name = try alloc.dupe(u8, entry.name),
            .sha256 = try hashFile(io, alloc, dir, entry.name),
        });
    }

    const slice = try out.toOwnedSlice(alloc);
    std.mem.sort(Record, slice, {}, lessByName);
    return slice;
}

/// Parse rows of the form: | **GENE** | L | `specs/x.tri` | V | `<64 hex>` | date |
fn readStored(io: Io, alloc: std.mem.Allocator) ![]Record {
    const file = Io.Dir.cwd().openFile(io, HashesFile, .{}) catch return &[_]Record{};
    defer file.close(io);

    var buf: [64 * 1024]u8 = undefined;
    var reader = file.readerStreaming(io, &buf);
    const text = try reader.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(text);

    var out: std.ArrayList(Record) = .empty;
    errdefer out.deinit(alloc);

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const marker = "`" ++ SpecsDir ++ "/";
        const fstart = std.mem.indexOf(u8, line, marker) orelse continue;
        const nstart = fstart + marker.len;
        const fend = std.mem.indexOfScalarPos(u8, line, nstart, '`') orelse continue;

        const hstart = std.mem.indexOfScalarPos(u8, line, fend + 1, '`') orelse continue;
        const hend = std.mem.indexOfScalarPos(u8, line, hstart + 1, '`') orelse continue;
        if (hend - hstart - 1 != 64) continue;

        var rec = Record{ .name = try alloc.dupe(u8, line[nstart..fend]), .sha256 = undefined };
        @memcpy(&rec.sha256, line[hstart + 1 .. hend]);
        try out.append(alloc, rec);
    }
    return out.toOwnedSlice(alloc);
}

fn update(io: Io, alloc: std.mem.Allocator) !void {
    const recs = try collect(io, alloc);

    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(alloc);

    try body.appendSlice(alloc,
        \\# TRI-HASHES — DNA plombs for .tri specifications
        \\
        \\Regenerate with `zig run tools/gen/check_tri_hashes.zig -- --update`.
        \\Verify with `--verify`; it exits non-zero on drift. Never edit by hand.
        \\
        \\| Gene | Level | File | Version | SHA256 | Last Modified |
        \\|------|-------|------|---------|--------|---------------|
        \\
    );
    for (recs) |r| {
        const stem = r.name[0 .. r.name.len - ".tri".len];
        const row = try std.fmt.allocPrint(alloc, "| **{s}** | 1 | `{s}/{s}` | 1 | `{s}` | 2026-08-09 |\n", .{ stem, SpecsDir, r.name, r.sha256 });
        defer alloc.free(row);
        try body.appendSlice(alloc, row);
    }

    const file = try Io.Dir.cwd().createFile(io, HashesFile, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, body.items);

    std.debug.print("sealed {d} .tri specs -> {s}\n", .{ recs.len, HashesFile });
}

fn verify(io: Io, alloc: std.mem.Allocator) !void {
    const current = try collect(io, alloc);
    const stored = try readStored(io, alloc);

    var bad: usize = 0;
    for (current) |c| {
        var seen = false;
        for (stored) |s| {
            if (!std.mem.eql(u8, s.name, c.name)) continue;
            seen = true;
            if (!std.mem.eql(u8, &s.sha256, &c.sha256)) {
                std.debug.print("MISMATCH  {s}\n  sealed  {s}\n  on disk {s}\n", .{ c.name, s.sha256, c.sha256 });
                bad += 1;
            }
        }
        if (!seen) {
            std.debug.print("UNSEALED  {s} (absent from {s})\n", .{ c.name, HashesFile });
            bad += 1;
        }
    }
    for (stored) |s| {
        var seen = false;
        for (current) |c| {
            if (std.mem.eql(u8, s.name, c.name)) seen = true;
        }
        if (!seen) {
            std.debug.print("VANISHED  {s} (sealed but not on disk)\n", .{s.name});
            bad += 1;
        }
    }

    if (bad != 0) {
        std.debug.print("FAIL: {d} problem(s)\n", .{bad});
        return error.SealBroken;
    }
    std.debug.print("OK: {d} .tri specs verified\n", .{current.len});
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    // Records own duped names for the process lifetime; an arena frees them all
    // at once rather than scattering frees through the walk.
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var mode: ?Mode = null;
    var args = init.minimal.args.iterate();
    _ = args.next(); // argv[0]
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update") or std.mem.eql(u8, arg, "-u")) mode = .update;
        if (std.mem.eql(u8, arg, "--verify") or std.mem.eql(u8, arg, "-v")) mode = .verify;
    }

    switch (mode orelse {
        std.debug.print("usage: check_tri_hashes --update|--verify\n", .{});
        return error.NoMode;
    }) {
        .update => try update(io, alloc),
        .verify => try verify(io, alloc),
    }
}
