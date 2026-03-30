//! TRI Format Specification Reader
//!
//! Reads .tri YAML spec files and provides structured data for code generation.

const std = @import("std");

pub const Spec = struct {
    format: []const u8,
    version: u8,
    storage: Storage,
    fields: []Field,
    exponent: Exponent,
    rounding: Rounding,
    phi: Phi,
    abi: Abi,
    conversion: Conversion,
    test_vectors: []TestVector,

    pub fn deinit(self: *Spec, allocator: std.mem.Allocator) void {
        allocator.free(self.fields);
        allocator.free(self.test_vectors);
    }
};

pub const Storage = struct {
    bits: u8,
    align_bytes: u8,
    endianness: Endianness,
    underlying: []const u8,

    pub const Endianness = enum { little, big };
};

pub const Field = struct {
    name: []const u8,
    bits: u8,
    position_msb: u8,  // Most significant bit position
};

pub const Exponent = struct {
    bits: u8,
    bias: u8,
    max: u8,
    min: u8,
    special: Special,

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

    pub const Mode = enum {
        ties_to_even,
        ties_to_odd,
        toward_zero,
        toward_positive,
        toward_negative,
    };
};

pub const Phi = struct {
    total_bits: u8,
    exponent_bits: u8,
    mantissa_bits: u8,
    target_ratio: f64,
    ratio: f64,
    distance: f64,
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

pub const TestVector = struct {
    name: []const u8,
    f32: f64,  // Stored as f64 for precision in YAML
    raw_hex: []const u8,
};

/// Load .tri specification from file
pub fn load(allocator: std.mem.Allocator, path: []const u8) !Spec {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 100); // Max 100KB
    defer allocator.free(content);

    return parse(allocator, content);
}

/// Parse YAML content into Spec
/// Minimal YAML parser for our specific format
pub fn parse(allocator: std.mem.Allocator, content: []const u8) !Spec {
    var lines = std.mem.splitScalar(u8, content, '\n');

    var spec = Spec{
        .format = "GF16",
        .version = 1,
        .storage = undefined,
        .fields = undefined,
        .exponent = undefined,
        .rounding = undefined,
        .phi = undefined,
        .abi = undefined,
        .conversion = undefined,
        .test_vectors = undefined,
    };

    // Parse with simple line-by-line scanner
    // For now, return hardcoded GF16 spec
    // TODO: Implement proper YAML parsing

    var field_list = std.ArrayList(Field).init(allocator);
    defer field_list.deinit();

    try field_list.append(.{ .name = "sign", .bits = 1, .position_msb = 15 });
    try field_list.append(.{ .name = "exponent", .bits = 6, .position_msb = 14 });
    try field_list.append(.{ .name = "mantissa", .bits = 9, .position_msb = 8 });

    var test_list = std.ArrayList(TestVector).init(allocator);
    defer test_list.deinit();

    try test_list.append(.{ .name = "zero", .f32 = 0.0, .raw_hex = "0000" });
    try test_list.append(.{ .name = "one", .f32 = 1.0, .raw_hex = "3c00" });
    try test_list.append(.{ .name = "minus_one", .f32 = -1.0, .raw_hex = "bc00" });
    try test_list.append(.{ .name = "pi", .f32 = 3.1415927, .raw_hex = "4248" });
    try test_list.append(.{ .name = "max_pos", .f32 = 4.3e9, .raw_hex = "7bff" });

    spec.fields = try field_list.toOwnedSlice();
    spec.test_vectors = try test_list.toOwnedSlice();

    spec.storage = .{
        .bits = 16,
        .align_bytes = 2,
        .endianness = .little,
        .underlying = "u16",
    };

    spec.exponent = .{
        .bits = 6,
        .bias = 31,
        .max = 63,
        .min = 0,
        .special = .{
            .zero = .{ .exponent = 0, .mantissa = 0 },
            .subnormal = .{ .exponent = 0, .mantissa = 0, .mantissa_nonzero = true },
            .inf = .{ .exponent = 63, .mantissa = 0 },
            .nan = .{ .exponent = 63, .mantissa = 0, .mantissa_nonzero = true },
        },
    };

    spec.rounding = .{
        .mode = .ties_to_even,
        .source_type = "f32",
        .overflow_policy = "saturate_to_inf",
        .underflow_policy = "subnormal_then_zero",
    };

    spec.phi = .{
        .total_bits = 15,
        .exponent_bits = 6,
        .mantissa_bits = 9,
        .target_ratio = 0.6180339,
        .ratio = 0.6666667,
        .distance = 0.0486328,
    };

    spec.abi = .{
        .c = .{ .typename = "uint16_t" },
        .rust = .{ .typename = "u16" },
        .cpp = .{ .typename = "uint16_t" },
        .zig = .{ .typename = "u16" },
    };

    spec.conversion = .{
        .from_f32_steps = &.{
            "extract_sign_exponent_mantissa",
            "compute_E = e32 - 127",
            "compute_e16 = E + 31",
            "handle_overflow_to_inf",
            "handle_underflow_to_subnormal_or_zero",
            "round_mantissa_to_9_bits_ties_to_even",
        },
        .to_f32_steps = &.{
            "decode_fields",
            "handle_zero_subnormal_inf_nan",
            "compute_E = e16 - 31",
            "compute_e32 = E + 127",
            "build_f32_bits",
        },
    };

    return spec;
}

/// Parse hex string to u16
pub fn parseHex(hex: []const u8) !u16 {
    _ = hex;
    // TODO: Implement hex parsing
    return 0;
}
