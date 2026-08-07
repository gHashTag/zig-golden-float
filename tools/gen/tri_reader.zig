//! TRI Format Specification Reader
//!
//! Reads .tri spec files (Trinity/GoldenFloat internal format).
//! Supports float (GF16) and ternary (TF3) formats.

const std = @import("std");

pub const Spec = struct {
    format: []const u8,
    version: u8,
    level: u8 = 0,
    storage: Storage,
    fields: []Field,
    exponent: Exponent,
    rounding: Rounding,
    phi: Phi,
    ternary: ?Ternary,
    vsa: ?Vsa,
    abi: Abi,
    conversion: Conversion,
    ops: []const Op,
    composite: ?Composite,
    test_vectors: []TestVector,
    input_path: []const u8 = "unknown.tri",
    // Level 5 (Data Structures) fields:
    spec_type: ?[]const u8 = null,
    types: []const TypeDef = &.{},
    constants: []const ConstDef = &.{},

    // All parsed strings and slices are owned by this arena, so deinit is a
    // single free of the whole arena — no per-field bookkeeping to drift out
    // of sync with the struct.
    arena_state: ?*std.heap.ArenaAllocator = null,

    pub fn deinit(self: *Spec, allocator: std.mem.Allocator) void {
        if (self.arena_state) |arena| {
            arena.deinit();
            allocator.destroy(arena);
            self.arena_state = null;
        }
    }
};

pub const TypeField = struct {
    name: []const u8,
    type: []const u8,
};

pub const TypeDef = struct {
    name: []const u8,
    generic: ?[]const u8 = null,
    variant: enum { struct_type, enum_type } = .struct_type,
    fields: []const TypeField = &.{},
    enum_values: []const []const u8 = &.{},
};

pub const ConstDef = struct {
    name: []const u8,
    value: []const u8, // Stored as string for flexibility (int, float, etc.)
};

pub const Storage = struct {
    bits: u8,
    align_bytes: u8,
    endianness: []const u8,
    underlying: []const u8,
    encoding: []const u8,
};

pub const Field = struct {
    name: []const u8,
    bits: u8,
    position_msb: u8,
    trit_value: bool = false,
    trit_count: u8 = 0,
    encoding: []const u8 = "",
};

pub const Exponent = struct {
    bits: u8,
    bias: u8,
    max: u8,
    min: u8,
    special: Special,
    trits: u8 = 0,
    base: u8 = 2,

    pub const Special = struct {
        zero: SpecialValue,
        subnormal: SpecialValue,
        inf: SpecialValue,
        nan: SpecialValue,
    };

    pub const SpecialValue = struct {
        exponent: u8,
        mantissa: u8,
        mantissa_nonzero: bool = false,
    };
};

pub const Rounding = struct {
    mode: Mode,
    source_type: []const u8,
    overflow_policy: []const u8,
    underflow_policy: []const u8,

    pub const Mode = enum { ties_to_even, ties_to_odd, toward_zero, toward_positive, toward_negative };
};

pub const Phi = struct {
    total_bits: u8,
    exponent_bits: u8,
    mantissa_bits: u8,
    target_ratio: f64,
    ratio: f64,
    distance: f64,
};

pub const Ternary = struct {
    trit_values: []const i8,
    encoding: []const u8,
    bits_per_trit: u8,
    total_trits: u8,
};

pub const Vsa = struct {
    compatible: bool,
    bind_arity: u8,
    bundle_arity: u8,
    similarity: []const u8,
};

pub const Abi = struct {
    c: TypeMapping,
    rust: TypeMapping,
    cpp: TypeMapping,
    zig: TypeMapping,

    pub const TypeMapping = struct {
        typename: []const u8,
    };
};

pub const Conversion = struct {
    from_f32_steps: []const []const u8,
    to_f32_steps: []const []const u8,
};

pub const Op = struct {
    name: []const u8,
    inputs: []const []const u8,
    outputs: []const []const u8,
    output: []const u8 = "",
    description: []const u8 = "",
    intermediate_type: []const u8 = "",
    algorithm: []const u8,
    rounding: []const u8 = "",
    commutative: bool = false,
    associative_approx: bool = false,
    single_rounding: bool = false,
    domain: []const u8 = "",
    table: ?Table,
    element_op: []const u8 = "",
    reduction: []const u8 = "",
    bounds: []const u8 = "",

    pub const Table = struct {
        entries: []const Entry,
        output_type: []const u8 = "",
    };

    pub const Entry = struct {
        key: []const u8,
        value: []const u8 = "",
        value_array: []const []const u8 = &.{},
    };
};

pub const Composite = struct {
    matmul: ?MatMul,
    ternary_conv: ?TernaryConv,

    pub const MatMul = struct {
        A: []const u8,
        B: []const u8,
        output: []const u8,
        accumulator: []const u8,
        inner_op: []const u8,
        tiling: Tiling,
    };

    pub const TernaryConv = struct {
        input: []const u8,
        weights: []const u8,
        output: []const u8,
        algorithm: []const u8,
        sparse: bool,
    };

    pub const Tiling = struct {
        block_m: u8,
        block_n: u8,
        block_k: u8,
    };
};

pub const TestVector = struct {
    name: []const u8,
    f32: f64,
    raw_hex: []const u8,
};

/// Load .tri specification from file
pub fn load(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Spec {
    // Zig 0.16.0 API: use std.Io.Dir.cwd() with io parameter
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer std.Io.File.close(file, io);

    // Get file size to read exact amount
    const stat_info = try std.Io.File.stat(file, io);
    const file_size = stat_info.size;
    const read_size = @min(file_size, 1024 * 10);

    // Create reader and read all content
    var read_buffer: [4096]u8 = undefined;
    var reader = std.Io.File.reader(file, io, &read_buffer);
    // Use Io.Reader interface for readAlloc
    const content = try std.Io.Reader.readAlloc(&reader.interface, allocator, read_size);
    defer allocator.free(content);

    var spec = try parse(allocator, content);
    spec.input_path = path;
    return spec;
}

/// Parse .tri format content.
///
/// All strings and slices in the returned Spec are owned by an arena stored in
/// `spec.arena_state`; `spec.deinit(allocator)` frees the arena in one shot.
pub fn parse(allocator: std.mem.Allocator, content: []const u8) !Spec {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    var parser = Parser{ .content = content, .a = arena.allocator() };
    var spec = try parser.parseSpec();
    spec.arena_state = arena;
    return spec;
}

/// Indentation-aware `.tri` parser.
///
/// `.tri` is a YAML-ish, whitespace-significant format. The old parser walked
/// the byte stream with per-section functions and had no notion of block scope,
/// so nested keys leaked into the next top-level section and every numeric field
/// came back zero. This implementation works in two phases:
///
///   1. `lex`        — split into significant lines (indent, list-item marker, text).
///   2. `buildNodes` — fold the lines into an indentation tree of `Node`s.
///
/// The tree is then mapped onto the strongly-typed `Spec`. Because scoping is a
/// property of the tree, mapping is just "find my child by key" and cannot
/// over-consume into a sibling section.
const Parser = struct {
    content: []const u8,
    a: std.mem.Allocator,

    /// One significant source line. For a list item (`- ...`) `indent` is the
    /// column of the dash and `text` is everything after `"- "`.
    const RawLine = struct {
        indent: usize,
        is_item: bool,
        text: []const u8,
    };

    /// A node in the indentation tree.
    ///
    /// - A mapping entry has `key`/`value` (a leaf) or `key` + `children` (a block).
    /// - A list item has `is_item = true`; a scalar item keeps its text in `value`,
    ///   a mapping item keeps its entries in `children`.
    const Node = struct {
        key: []const u8 = "",
        value: []const u8 = "",
        is_item: bool = false,
        children: []const Node = &.{},

        /// Find a direct mapping child by key (list items are skipped).
        fn child(self: Node, k: []const u8) ?Node {
            for (self.children) |c| {
                if (!c.is_item and eql(c.key, k)) return c;
            }
            return null;
        }
    };

    fn eql(a: []const u8, b: []const u8) bool {
        return std.mem.eql(u8, a, b);
    }

    // ── Phase 1: lexing ──────────────────────────────────────────────────

    fn lex(self: *Parser) ![]RawLine {
        var lines = try std.ArrayList(RawLine).initCapacity(self.a, 0);
        var it = std.mem.splitScalar(u8, self.content, '\n');
        while (it.next()) |raw0| {
            var raw = raw0;
            if (raw.len > 0 and raw[raw.len - 1] == '\r') raw = raw[0 .. raw.len - 1];

            var indent: usize = 0;
            while (indent < raw.len and raw[indent] == ' ') indent += 1;

            var rest = raw[indent..];
            if (rest.len == 0) continue; // blank line
            if (rest[0] == '#') continue; // full-line comment

            rest = stripInlineComment(rest);
            rest = std.mem.trimEnd(u8, rest, " \t");
            if (rest.len == 0) continue;

            var is_item = false;
            if (std.mem.eql(u8, rest, "-")) {
                is_item = true;
                rest = "";
            } else if (rest.len >= 2 and rest[0] == '-' and rest[1] == ' ') {
                is_item = true;
                rest = std.mem.trimStart(u8, rest[2..], " \t");
            }

            try lines.append(self.a, .{ .indent = indent, .is_item = is_item, .text = rest });
        }
        return lines.toOwnedSlice(self.a);
    }

    /// Strip a trailing `# ...` comment, ignoring `#` inside double quotes and
    /// requiring the `#` to be preceded by whitespace (so `a#b` stays intact).
    fn stripInlineComment(text: []const u8) []const u8 {
        var in_quote = false;
        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            const ch = text[i];
            if (ch == '"') {
                in_quote = !in_quote;
            } else if (ch == '#' and !in_quote and (i == 0 or text[i - 1] == ' ' or text[i - 1] == '\t')) {
                return text[0..i];
            }
        }
        return text;
    }

    // ── Phase 2: build the indentation tree ──────────────────────────────

    /// Consume lines whose indent is >= `min_indent`, building sibling nodes.
    /// Children are lines strictly more indented than their parent.
    fn buildNodes(self: *Parser, lines: []const RawLine, idx: *usize, min_indent: usize) anyerror![]const Node {
        var nodes = try std.ArrayList(Node).initCapacity(self.a, 0);
        while (idx.* < lines.len) {
            const line = lines[idx.*];
            if (line.indent < min_indent) break;
            idx.* += 1;

            if (line.is_item) {
                const kv = splitKV(line.text);
                if (kv.key.len > 0) {
                    // Mapping item: first entry is inline, rest follow at the
                    // content column (dash column + 1 is enough to scope them).
                    var kids = try std.ArrayList(Node).initCapacity(self.a, 0);
                    try kids.append(self.a, .{ .key = kv.key, .value = kv.value });
                    const rest = try self.buildNodes(lines, idx, line.indent + 1);
                    try kids.appendSlice(self.a, rest);
                    try nodes.append(self.a, .{ .is_item = true, .children = try kids.toOwnedSlice(self.a) });
                } else {
                    // Scalar item (`- some_value`) or an empty `-` with a block.
                    if (kv.value.len > 0) {
                        try nodes.append(self.a, .{ .is_item = true, .value = kv.value });
                    } else {
                        const kids = try self.buildNodes(lines, idx, line.indent + 1);
                        try nodes.append(self.a, .{ .is_item = true, .children = kids });
                    }
                }
            } else {
                const kv = splitKV(line.text);
                if (kv.key.len > 0 and kv.value.len == 0) {
                    const kids = try self.buildNodes(lines, idx, line.indent + 1);
                    try nodes.append(self.a, .{ .key = kv.key, .children = kids });
                } else {
                    try nodes.append(self.a, .{ .key = kv.key, .value = kv.value });
                }
            }
        }
        return nodes.toOwnedSlice(self.a);
    }

    const KV = struct { key: []const u8, value: []const u8 };

    /// Split `key: value` on the first colon. No colon → a scalar (`key = ""`).
    fn splitKV(text: []const u8) KV {
        if (std.mem.indexOfScalar(u8, text, ':')) |ci| {
            return .{
                .key = std.mem.trim(u8, text[0..ci], " \t"),
                .value = std.mem.trim(u8, text[ci + 1 ..], " \t"),
            };
        }
        return .{ .key = "", .value = std.mem.trim(u8, text, " \t") };
    }

    // ── Small typed accessors over the tree ──────────────────────────────

    fn intOf(comptime T: type, node: Node, key: []const u8, default: T) T {
        if (node.child(key)) |c| {
            return std.fmt.parseInt(T, c.value, 10) catch default;
        }
        return default;
    }

    fn floatOf(node: Node, key: []const u8, default: f64) f64 {
        if (node.child(key)) |c| {
            return std.fmt.parseFloat(f64, c.value) catch default;
        }
        return default;
    }

    fn boolOf(node: Node, key: []const u8, default: bool) bool {
        if (node.child(key)) |c| return std.mem.eql(u8, c.value, "true");
        return default;
    }

    /// Duplicate a value into the arena, stripping surrounding double quotes.
    fn dupUnquote(self: *Parser, s: []const u8) ![]const u8 {
        var v = s;
        if (v.len >= 2 and v[0] == '"' and v[v.len - 1] == '"') v = v[1 .. v.len - 1];
        return self.a.dupe(u8, v);
    }

    /// Arena-duped copy of a child's (unquoted) value, or `default` when absent.
    fn strOf(self: *Parser, node: Node, key: []const u8, default: []const u8) ![]const u8 {
        if (node.child(key)) |c| return self.dupUnquote(c.value);
        return default;
    }

    /// Parse an inline `[a, b, c]` array into duped strings.
    fn parseInlineArray(self: *Parser, value: []const u8) ![]const []const u8 {
        var inner = std.mem.trim(u8, value, " \t");
        if (inner.len >= 2 and inner[0] == '[' and inner[inner.len - 1] == ']') {
            inner = inner[1 .. inner.len - 1];
        }
        var list = try std.ArrayList([]const u8).initCapacity(self.a, 0);
        var it = std.mem.splitScalar(u8, inner, ',');
        while (it.next()) |elem| {
            const trimmed = std.mem.trim(u8, elem, " \t");
            if (trimmed.len == 0) continue;
            try list.append(self.a, try self.dupUnquote(trimmed));
        }
        return list.toOwnedSlice(self.a);
    }

    /// A child that is either an inline array (`key: [a, b]`) or a block list of
    /// scalar items, returned as duped strings.
    fn listOf(self: *Parser, node: Node, key: []const u8) ![]const []const u8 {
        if (node.child(key)) |c| {
            if (c.value.len > 0 and c.value[0] == '[') return self.parseInlineArray(c.value);
            if (c.children.len > 0) {
                var list = try std.ArrayList([]const u8).initCapacity(self.a, 0);
                for (c.children) |it| {
                    if (it.is_item) try list.append(self.a, try self.dupUnquote(it.value));
                }
                return list.toOwnedSlice(self.a);
            }
        }
        return &.{};
    }

    // ── Mapping the tree onto Spec ───────────────────────────────────────

    fn parseSpec(self: *Parser) !Spec {
        const lines = try self.lex();
        var idx: usize = 0;
        const roots = try self.buildNodes(lines, &idx, 0);

        const zero_special = Exponent.SpecialValue{ .exponent = 0, .mantissa = 0 };
        var spec = Spec{
            .format = "GF16",
            .version = 1,
            .level = 0,
            .storage = .{ .bits = 0, .align_bytes = 1, .endianness = "", .underlying = "", .encoding = "binary" },
            .fields = &.{},
            .exponent = .{
                .bits = 0,
                .bias = 0,
                .max = 0,
                .min = 0,
                .special = .{ .zero = zero_special, .subnormal = zero_special, .inf = zero_special, .nan = zero_special },
            },
            .rounding = .{ .mode = .ties_to_even, .source_type = "", .overflow_policy = "", .underflow_policy = "" },
            .phi = .{ .total_bits = 0, .exponent_bits = 0, .mantissa_bits = 0, .target_ratio = 0, .ratio = 0, .distance = 0 },
            .ternary = null,
            .vsa = null,
            .abi = .{
                .c = .{ .typename = "uint16_t" },
                .rust = .{ .typename = "u16" },
                .cpp = .{ .typename = "uint16_t" },
                .zig = .{ .typename = "u16" },
            },
            .conversion = .{ .from_f32_steps = &.{}, .to_f32_steps = &.{} },
            .ops = &.{},
            .composite = null,
            .test_vectors = &.{},
        };

        for (roots) |node| {
            const k = node.key;
            if (k.len == 0) continue; // stray scalar (e.g. a block-literal description line)
            if (eql(k, "format")) {
                spec.format = try self.dupUnquote(node.value);
            } else if (eql(k, "version")) {
                spec.version = std.fmt.parseInt(u8, node.value, 10) catch spec.version;
            } else if (eql(k, "level")) {
                spec.level = std.fmt.parseInt(u8, node.value, 10) catch spec.level;
            } else if (eql(k, "type")) {
                spec.spec_type = try self.dupUnquote(node.value);
            } else if (eql(k, "storage")) {
                spec.storage = try self.mapStorage(node);
            } else if (eql(k, "fields")) {
                spec.fields = try self.mapFields(node);
            } else if (eql(k, "exponent")) {
                spec.exponent = try self.mapExponent(node);
            } else if (eql(k, "rounding")) {
                spec.rounding = try self.mapRounding(node);
            } else if (eql(k, "phi")) {
                spec.phi = try self.mapPhi(node);
            } else if (eql(k, "ternary")) {
                spec.ternary = try self.mapTernary(node);
            } else if (eql(k, "vsa")) {
                spec.vsa = try self.mapVsa(node);
            } else if (eql(k, "abi")) {
                spec.abi = try self.mapAbi(node);
            } else if (eql(k, "conversion")) {
                spec.conversion = try self.mapConversion(node);
            } else if (eql(k, "ops")) {
                spec.ops = try self.mapOps(node);
            } else if (eql(k, "composite")) {
                spec.composite = try self.mapComposite(node);
            } else if (eql(k, "test_vectors")) {
                spec.test_vectors = try self.mapTestVectors(node);
            } else if (eql(k, "constants")) {
                spec.constants = try self.mapConstants(node);
            } else if (eql(k, "types")) {
                spec.types = try self.mapTypes(node);
            }
        }

        return spec;
    }

    fn mapStorage(self: *Parser, node: Node) !Storage {
        return .{
            .bits = intOf(u8, node, "bits", 0),
            // hash_table.tri spells this "alignment"; accept both.
            .align_bytes = intOf(u8, node, "align_bytes", intOf(u8, node, "alignment", 1)),
            .endianness = try self.strOf(node, "endianness", ""),
            .underlying = try self.strOf(node, "underlying", ""),
            .encoding = try self.strOf(node, "encoding", "binary"),
        };
    }

    fn mapFields(self: *Parser, node: Node) ![]Field {
        var list = try std.ArrayList(Field).initCapacity(self.a, 0);
        for (node.children) |item| {
            if (!item.is_item) continue;
            try list.append(self.a, .{
                .name = try self.strOf(item, "name", ""),
                .bits = intOf(u8, item, "bits", 0),
                .position_msb = intOf(u8, item, "position_msb", 0),
                .trit_value = boolOf(item, "trit_value", false),
                .trit_count = intOf(u8, item, "trit_count", 0),
                .encoding = try self.strOf(item, "encoding", ""),
            });
        }
        return list.toOwnedSlice(self.a);
    }

    fn mapExponent(self: *Parser, node: Node) !Exponent {
        _ = self;
        const zero_special = Exponent.SpecialValue{ .exponent = 0, .mantissa = 0 };
        var special = Exponent.Special{
            .zero = zero_special,
            .subnormal = zero_special,
            .inf = zero_special,
            .nan = zero_special,
        };
        if (node.child("special")) |sp| {
            if (sp.child("zero")) |c| special.zero = mapSpecialValue(c);
            if (sp.child("subnormal")) |c| special.subnormal = mapSpecialValue(c);
            if (sp.child("inf")) |c| special.inf = mapSpecialValue(c);
            if (sp.child("nan")) |c| special.nan = mapSpecialValue(c);
        }
        return .{
            .bits = intOf(u8, node, "bits", 0),
            .bias = intOf(u8, node, "bias", 0),
            .max = intOf(u8, node, "max", 0),
            .min = intOf(u8, node, "min", 0),
            .special = special,
            .trits = intOf(u8, node, "trits", 0),
            .base = intOf(u8, node, "base", 2),
        };
    }

    fn mapSpecialValue(node: Node) Exponent.SpecialValue {
        return .{
            .exponent = intOf(u8, node, "exponent", 0),
            .mantissa = intOf(u8, node, "mantissa", 0),
            .mantissa_nonzero = boolOf(node, "mantissa_nonzero", false),
        };
    }

    fn mapRounding(self: *Parser, node: Node) !Rounding {
        const mode_str = try self.strOf(node, "mode", "ties-to-even");
        const mode: Rounding.Mode = if (eql(mode_str, "ties-to-even"))
            .ties_to_even
        else if (eql(mode_str, "ties-to-odd"))
            .ties_to_odd
        else if (eql(mode_str, "ties-to-zero") or eql(mode_str, "toward-zero"))
            .toward_zero
        else if (eql(mode_str, "toward-positive"))
            .toward_positive
        else if (eql(mode_str, "toward-negative"))
            .toward_negative
        else
            .ties_to_even;

        return .{
            .mode = mode,
            .source_type = try self.strOf(node, "source_type", ""),
            .overflow_policy = try self.strOf(node, "overflow_policy", ""),
            .underflow_policy = try self.strOf(node, "underflow_policy", ""),
        };
    }

    fn mapPhi(self: *Parser, node: Node) !Phi {
        _ = self;
        return .{
            .total_bits = intOf(u8, node, "total_bits", 0),
            .exponent_bits = intOf(u8, node, "exponent_bits", 0),
            .mantissa_bits = intOf(u8, node, "mantissa_bits", 0),
            .target_ratio = floatOf(node, "target_ratio", 0),
            .ratio = floatOf(node, "ratio", 0),
            .distance = floatOf(node, "distance", 0),
        };
    }

    fn mapTernary(self: *Parser, node: Node) !Ternary {
        const trit_values = try self.a.dupe(i8, &[_]i8{ -1, 0, 1 });
        return .{
            .trit_values = trit_values,
            .encoding = try self.strOf(node, "encoding", ""),
            .bits_per_trit = intOf(u8, node, "bits_per_trit", 0),
            .total_trits = intOf(u8, node, "total_trits", 0),
        };
    }

    fn mapVsa(self: *Parser, node: Node) !Vsa {
        return .{
            .compatible = boolOf(node, "compatible", false),
            .bind_arity = intOf(u8, node, "bind_arity", 0),
            .bundle_arity = intOf(u8, node, "bundle_arity", 0),
            .similarity = try self.strOf(node, "similarity", "cosine"),
        };
    }

    fn mapAbi(self: *Parser, node: Node) !Abi {
        return .{
            .c = .{ .typename = try self.typenameOf(node, "c", "uint16_t") },
            .rust = .{ .typename = try self.typenameOf(node, "rust", "u16") },
            .cpp = .{ .typename = try self.typenameOf(node, "cpp", "uint16_t") },
            .zig = .{ .typename = try self.typenameOf(node, "zig", "u16") },
        };
    }

    fn typenameOf(self: *Parser, node: Node, key: []const u8, default: []const u8) ![]const u8 {
        if (node.child(key)) |sub| return self.strOf(sub, "typename", default);
        return default;
    }

    fn mapConversion(self: *Parser, node: Node) !Conversion {
        var from = try self.listOf(node, "from_f32_steps");
        var to = try self.listOf(node, "to_f32_steps");
        if (from.len == 0) {
            from = try self.a.dupe([]const u8, &[_][]const u8{ "decode", "f32_op", "encode" });
        }
        if (to.len == 0) {
            to = try self.a.dupe([]const u8, &[_][]const u8{ "decode", "f32_value" });
        }
        return .{ .from_f32_steps = from, .to_f32_steps = to };
    }

    fn mapOps(self: *Parser, node: Node) ![]const Op {
        var list = try std.ArrayList(Op).initCapacity(self.a, 0);
        for (node.children) |c| {
            // Two spellings: mapping-style (`add:` with nested keys — used by the
            // real specs) or list-style (`- name: add`).
            const op_node = c;
            var name: []const u8 = "";
            if (c.is_item) {
                name = try self.strOf(c, "name", "");
            } else if (c.key.len > 0) {
                name = try self.a.dupe(u8, c.key);
            } else {
                continue;
            }

            try list.append(self.a, .{
                .name = name,
                .inputs = try self.listOf(op_node, "inputs"),
                .outputs = try self.listOf(op_node, "outputs"),
                .output = try self.strOf(op_node, "output", ""),
                .description = try self.strOf(op_node, "description", ""),
                .intermediate_type = try self.strOf(op_node, "intermediate_type", ""),
                .algorithm = try self.strOf(op_node, "algorithm", ""),
                .rounding = try self.strOf(op_node, "rounding", ""),
                .commutative = boolOf(op_node, "commutative", false),
                .associative_approx = boolOf(op_node, "associative_approx", false),
                .single_rounding = boolOf(op_node, "single_rounding", false),
                .domain = try self.strOf(op_node, "domain", ""),
                .table = null,
                .element_op = try self.strOf(op_node, "element_op", ""),
                .reduction = try self.strOf(op_node, "reduction", ""),
                .bounds = try self.strOf(op_node, "bounds", ""),
            });
        }
        return list.toOwnedSlice(self.a);
    }

    fn mapComposite(self: *Parser, node: Node) !Composite {
        var matmul: ?Composite.MatMul = null;
        var ternary_conv: ?Composite.TernaryConv = null;
        if (node.child("matmul")) |mm| {
            matmul = .{
                .A = try self.strOf(mm, "A", ""),
                .B = try self.strOf(mm, "B", ""),
                .output = try self.strOf(mm, "output", ""),
                .accumulator = try self.strOf(mm, "accumulator", "i32"),
                .inner_op = try self.strOf(mm, "inner_op", "dot"),
                .tiling = .{
                    .block_m = intOf(u8, mm, "block_m", 16),
                    .block_n = intOf(u8, mm, "block_n", 16),
                    .block_k = intOf(u8, mm, "block_k", 32),
                },
            };
        }
        if (node.child("ternary_conv")) |cn| {
            ternary_conv = .{
                .input = try self.strOf(cn, "input", ""),
                .weights = try self.strOf(cn, "weights", ""),
                .output = try self.strOf(cn, "output", ""),
                .algorithm = try self.strOf(cn, "algorithm", "im2col_matmul"),
                .sparse = boolOf(cn, "sparse", false),
            };
        }
        return .{ .matmul = matmul, .ternary_conv = ternary_conv };
    }

    fn mapTestVectors(self: *Parser, node: Node) ![]TestVector {
        var list = try std.ArrayList(TestVector).initCapacity(self.a, 0);
        for (node.children) |item| {
            if (!item.is_item) continue;
            try list.append(self.a, .{
                .name = try self.strOf(item, "name", ""),
                .f32 = floatOf(item, "f32", 0),
                .raw_hex = try self.strOf(item, "raw_hex", ""),
            });
        }
        return list.toOwnedSlice(self.a);
    }

    fn mapConstants(self: *Parser, node: Node) ![]const ConstDef {
        var list = try std.ArrayList(ConstDef).initCapacity(self.a, 0);
        for (node.children) |c| {
            if (c.is_item or c.key.len == 0) continue;
            try list.append(self.a, .{
                .name = try self.a.dupe(u8, c.key),
                .value = try self.dupUnquote(c.value),
            });
        }
        return list.toOwnedSlice(self.a);
    }

    fn mapTypes(self: *Parser, node: Node) ![]const TypeDef {
        var list = try std.ArrayList(TypeDef).initCapacity(self.a, 0);
        for (node.children) |t| {
            if (t.is_item or t.key.len == 0) continue;

            var td = TypeDef{
                .name = try self.a.dupe(u8, t.key),
                .variant = .struct_type,
            };

            if (t.child("generic")) |g| td.generic = try self.dupUnquote(g.value);

            if (t.child("enum")) |e| {
                td.variant = .enum_type;
                td.enum_values = try self.parseInlineArray(e.value);
            }

            if (t.child("fields")) |fields_node| {
                var fields = try std.ArrayList(TypeField).initCapacity(self.a, 0);
                for (fields_node.children) |item| {
                    if (!item.is_item) continue;
                    var ftype = try self.strOf(item, "type", "");
                    if (ftype.len == 0) ftype = try self.a.dupe(u8, "auto");
                    try fields.append(self.a, .{
                        .name = try self.strOf(item, "name", ""),
                        .type = ftype,
                    });
                }
                td.fields = try fields.toOwnedSlice(self.a);
            }

            try list.append(self.a, td);
        }
        return list.toOwnedSlice(self.a);
    }
};

test "parse gf8.tri populates storage/exponent/phi" {
    const content = @embedFile("spec_gf8");
    var spec = try parse(std.testing.allocator, content);
    defer spec.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("GF8", spec.format);
    try std.testing.expectEqual(@as(u8, 8), spec.storage.bits);
    try std.testing.expectEqual(@as(u8, 3), spec.exponent.bits);
    try std.testing.expectEqual(@as(u8, 3), spec.exponent.bias);
    try std.testing.expectEqual(@as(u8, 7), spec.exponent.max);
    try std.testing.expectEqual(@as(u8, 0), spec.exponent.min);
    try std.testing.expectEqual(@as(u8, 4), spec.phi.mantissa_bits);

    // Field layout and specials must round-trip too, not just the scalars above.
    try std.testing.expectEqual(@as(usize, 3), spec.fields.len);
    try std.testing.expectEqualStrings("sign", spec.fields[0].name);
    try std.testing.expectEqual(@as(u8, 4), spec.fields[2].bits);
    try std.testing.expectEqual(@as(u8, 7), spec.exponent.special.inf.exponent);
    try std.testing.expect(spec.exponent.special.nan.mantissa_nonzero);
}

test "parse gf16.tri populates storage/exponent/phi" {
    const content = @embedFile("spec_gf16");
    var spec = try parse(std.testing.allocator, content);
    defer spec.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("GF16", spec.format);
    try std.testing.expectEqual(@as(u8, 16), spec.storage.bits);
    try std.testing.expectEqual(@as(u8, 6), spec.exponent.bits);
    try std.testing.expectEqual(@as(u8, 31), spec.exponent.bias);
    try std.testing.expectEqual(@as(u8, 63), spec.exponent.max);
    try std.testing.expectEqual(@as(u8, 9), spec.phi.mantissa_bits);
}
