//! TRI Format Specification Reader
//!
//! Reads .tri spec files (Trinity/GoldenFloat internal format).
//! Zero external dependencies — simple YAML-like parser.

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
    endianness: []const u8,
    underlying: []const u8,
};

pub const Field = struct {
    name: []const u8,
    bits: u8,
    position_msb: u8,
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
    f32: f64,
    raw_hex: []const u8,
};

/// Parser state
const Parser = struct {
    content: []const u8,
    pos: usize,
    line: usize = 1,
    allocator: std.mem.Allocator,

    fn init(content: []const u8, allocator: std.mem.Allocator) Parser {
        return .{
            .content = content,
            .pos = 0,
            .allocator = allocator,
        };
    }

    fn peek(self: *Parser) ?u8 {
        if (self.pos >= self.content.len) return null;
        return self.content[self.pos];
    }

    fn advance(self: *Parser) ?u8 {
        if (self.pos >= self.content.len) return null;
        const ch = self.content[self.pos];
        self.pos += 1;
        if (ch == '\n') self.line += 1;
        return ch;
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.peek()) |ch| {
            if (ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r') {
                _ = self.advance();
            } else {
                break;
            }
        }
    }

    fn skipComment(self: *Parser) void {
        if (self.peek()) |ch| {
            if (ch == '#') {
                while (self.advance()) |line_ch| {
                    if (line_ch == '\n') {
                        self.line += 1;
                        break;
                    }
                }
            }
        }
    }

    fn skipWhitespaceAndComments(self: *Parser) void {
        while (true) {
            self.skipWhitespace();
            if (self.peek()) |ch| {
                if (ch == '#') {
                    self.skipComment();
                } else {
                    break;
                }
            } else {
                break;
            }
        }
    }

    fn readUntil(self: *Parser, delimiter: u8) ![]const u8 {
        const start = self.pos;
        while (self.advance()) |ch| {
            if (ch == delimiter) {
                return self.content[start .. self.pos - 1];
            }
        }
        return error.UnexpectedEndOfFile;
    }

    fn readKey(self: *Parser) !?[]const u8 {
        self.skipWhitespaceAndComments();
        const start = self.pos;

        while (self.peek()) |ch| {
            if (ch == ':' or ch == '\n' or ch == '#') {
                break;
            }
            _ = self.advance();
        }

        if (self.pos == start) return null;

        const key = self.content[start..self.pos];
        // Trim trailing whitespace
        var end = self.pos;
        while (end > start and (self.content[end - 1] == ' ' or self.content[end - 1] == '\t')) {
            end -= 1;
        }

        return self.content[start..end];
    }

    fn readValue(self: *Parser) ![]const u8 {
        self.skipWhitespaceAndComments();
        if (self.peek()) |ch| {
            if (ch == ':') {
                _ = self.advance();
                self.skipWhitespaceAndComments();
            }
        }

        const start = self.pos;

        // Handle quoted strings
        if (self.peek()) |ch| {
            if (ch == '"') {
                _ = self.advance();
                return self.readUntil('"');
            }
        }

        // Read until end of line or comment
        while (self.advance()) |ch| {
            if (ch == '\n' or ch == '#') {
                self.pos -= 1; // Put back the newline
                break;
            }
        }

        if (self.pos == start) return error.EmptyValue;

        // Trim trailing whitespace
        var end = self.pos;
        while (end > start and (self.content[end - 1] == ' ' or self.content[end - 1] == '\t')) {
            end -= 1;
        }

        return self.content[start..end];
    }

    fn expectColon(self: *Parser) !void {
        self.skipWhitespaceAndComments();
        if (self.peek()) |ch| {
            if (ch == ':') {
                _ = self.advance();
                return;
            }
        }
        return error.ExpectedColon;
    }

    fn parseInt(self: *Parser, comptime T: type) !T {
        const str = try self.readValue();
        return std.fmt.parseInt(T, str, 10);
    }

    fn parseFloat(self: *Parser) !f64 {
        const str = try self.readValue();
        return std.fmt.parseFloat(f64, str);
    }
};

/// Load .tri specification from file
pub fn load(allocator: std.mem.Allocator, path: []const u8) !Spec {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 10); // 10KB max
    defer allocator.free(content);

    return parse(allocator, content);
}

/// Parse .tri format content
pub fn parse(allocator: std.mem.Allocator, content: []const u8) !Spec {
    var parser = Parser.init(content, allocator);

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

    // Parse root-level key-value pairs
    var field_list = std.ArrayList(Field).init(allocator);
    defer field_list.deinit();
    var test_list = std.ArrayList(TestVector).init(allocator);
    defer test_list.deinit();

    var current_section: []const u8 = "";

    while (parser.readKey()) |maybe_key| {
        const key = maybe_key orelse continue;

        if (std.mem.eql(u8, key, "format")) {
            spec.format = try parser.readValue();
        } else if (std.mem.eql(u8, key, "version")) {
            spec.version = try parser.parseInt(u8);
        } else if (std.mem.eql(u8, key, "storage")) {
            try parser.expectColon();
            spec.storage = try parseStorage(&parser);
        } else if (std.mem.eql(u8, key, "fields")) {
            try parser.expectColon();
            spec.fields = try parseFieldList(&parser, allocator);
        } else if (std.mem.eql(u8, key, "exponent")) {
            try parser.expectColon();
            spec.exponent = try parseExponent(&parser);
        } else if (std.mem.eql(u8, key, "rounding")) {
            try parser.expectColon();
            spec.rounding = try parseRounding(&parser);
        } else if (std.mem.eql(u8, key, "phi")) {
            try parser.expectColon();
            spec.phi = try parsePhi(&parser);
        } else if (std.mem.eql(u8, key, "abi")) {
            try parser.expectColon();
            spec.abi = try parseAbi(&parser);
        } else if (std.mem.eql(u8, key, "conversion")) {
            try parser.expectColon();
            spec.conversion = try parseConversion(&parser, allocator);
        } else if (std.mem.eql(u8, key, "test_vectors")) {
            try parser.expectColon();
            spec.test_vectors = try parseTestVectors(&parser, allocator);
        } else {
            // Unknown key, skip value
            _ = parser.readValue() catch {};
        }
    } else |err| {
        if (err == error.EndOfStream) break;
    }

    return spec;
}

fn parseStorage(parser: *Parser) !Storage {
    return .{
        .bits = try parser.parseInt(u8),
        .align_bytes = try parser.parseInt(u8),
        .endianness = try parser.readValue(),
        .underlying = try parser.readValue(),
    };
}

fn parseFieldList(parser: *Parser, allocator: std.mem.Allocator) ![]Field {
    var list = std.ArrayList(Field).init(allocator);
    errdefer list.deinit();

    parser.skipWhitespaceAndComments();

    // Expect list items (lines starting with "- name:")
    while (true) : (parser.skipWhitespaceAndComments()) {
        if (parser.peek()) |ch| {
            if (ch != '-') break;
        } else {
            break;
        }
        _ = parser.advance(); // Skip '-'

        parser.skipWhitespaceAndComments();

        // Read field properties
        var field = Field{
            .name = "",
            .bits = 0,
            .position_msb = 0,
        };

        while (parser.readKey()) |maybe_key| {
            const key = maybe_key orelse continue;

            if (std.mem.eql(u8, key, "name")) {
                field.name = try parser.readValue();
            } else if (std.mem.eql(u8, key, "bits")) {
                field.bits = try parser.parseInt(u8);
            } else if (std.mem.eql(u8, key, "position_msb")) {
                field.position_msb = try parser.parseInt(u8);
            } else {
                _ = parser.readValue() catch {};
            }

            // Check if next line starts new field or section
            parser.skipWhitespaceAndComments();
            if (parser.peek()) |ch| {
                if (ch == '\n' or ch == '-' or ch == '\r') {
                    if (ch == '-') break;
                }
            }
        }

        try list.append(field);
    }

    return list.toOwnedSlice();
}

fn parseExponent(parser: *Parser) !Exponent {
    return .{
        .bits = try parser.parseInt(u8),
        .bias = try parser.parseInt(u8),
        .max = try parser.parseInt(u8),
        .min = try parser.parseInt(u8),
        .special = .{
            .zero = .{ .exponent = 0, .mantissa = 0 },
            .subnormal = .{ .exponent = 0, .mantissa = 0, .mantissa_nonzero = true },
            .inf = .{ .exponent = 63, .mantissa = 0 },
            .nan = .{ .exponent = 63, .mantissa = 0, .mantissa_nonzero = true },
        },
    };
}

fn parseRounding(parser: *Parser) !Rounding {
    const mode_str = try parser.readValue();
    const mode = if (std.mem.eql(u8, mode_str, "ties-to-even"))
        .ties_to_even
    else if (std.mem.eql(u8, mode_str, "ties-to-odd"))
        .ties_to_odd
    else
        .ties_to_even;

    return .{
        .mode = mode,
        .source_type = try parser.readValue(),
        .overflow_policy = try parser.readValue(),
        .underflow_policy = try parser.readValue(),
    };
}

fn parsePhi(parser: *Parser) !Phi {
    return .{
        .total_bits = try parser.parseInt(u8),
        .exponent_bits = try parser.parseInt(u8),
        .mantissa_bits = try parser.parseInt(u8),
        .target_ratio = try parser.parseFloat(),
        .ratio = try parser.parseFloat(),
        .distance = try parser.parseFloat(),
    };
}

fn parseAbi(parser: *Parser) !Abi {
    // Simple: read 4 typename values
    _ = parser.readString(); // c:
    const c_typename = try parser.readValue();
    _ = parser.readString(); // rust:
    const rust_typename = try parser.readValue();
    _ = parser.readString(); // cpp:
    const cpp_typename = try parser.readValue();
    _ = parser.readString(); // zig:
    const zig_typename = try parser.readValue();

    return .{
        .c = .{ .typename = c_typename },
        .rust = .{ .typename = rust_typename },
        .cpp = .{ .typename = cpp_typename },
        .zig = .{ .typename = zig_typename },
    };
}

fn parseConversion(parser: *Parser, allocator: std.mem.Allocator) !Conversion {
    // Skip to from_f32_steps or to_f32_steps
    var from_steps = std.ArrayList([]const u8).init(allocator);
    defer from_steps.deinit();
    var to_steps = std.ArrayList([]const u8).init(allocator);
    defer to_steps.deinit();

    // Simplified: return hardcoded steps for now
    try from_steps.append("extract_sign_exponent_mantissa");
    try from_steps.append("compute_E = e32 - 127");
    try from_steps.append("compute_e16 = E + 31");
    try from_steps.append("handle_overflow_to_inf");
    try from_steps.append("handle_underflow_to_subnormal_or_zero");
    try from_steps.append("round_mantissa_to_9_bits_ties_to_even");

    try to_steps.append("decode_fields");
    try to_steps.append("handle_zero_subnormal_inf_nan");
    try to_steps.append("compute_E = e16 - 31");
    try to_steps.append("compute_e32 = E + 127");
    try to_steps.append("build_f32_bits");

    return .{
        .from_f32_steps = try from_steps.toOwnedSlice(),
        .to_f32_steps = try to_steps.toOwnedSlice(),
    };
}

fn parseTestVectors(parser: *Parser, allocator: std.mem.Allocator) ![]TestVector {
    var list = std.ArrayList(TestVector).init(allocator);
    errdefer list.deinit();

    // Read list items
    while (true) : (parser.skipWhitespaceAndComments()) {
        if (parser.peek()) |ch| {
            if (ch != '-') break;
        } else {
            break;
        }
        _ = parser.advance(); // Skip '-'

        var vec = TestVector{
            .name = "",
            .f32 = 0.0,
            .raw_hex = "",
        };

        while (parser.readKey()) |maybe_key| {
            const key = maybe_key orelse continue;

            if (std.mem.eql(u8, key, "name")) {
                vec.name = try parser.readValue();
            } else if (std.mem.eql(u8, key, "f32")) {
                vec.f32 = try parser.parseFloat();
            } else if (std.mem.eql(u8, key, "raw_hex")) {
                vec.raw_hex = try parser.readValue();
            } else {
                _ = parser.readValue() catch {};
            }

            parser.skipWhitespaceAndComments();
            if (parser.peek()) |ch| {
                if (ch == '\n' or ch == '-' or ch == '\r') {
                    if (ch == '-') break;
                }
            }
        }

        try list.append(vec);
    }

    return list.toOwnedSlice();
}

fn readString(parser: *Parser) ![]const u8 {
    return parser.readValue();
}
