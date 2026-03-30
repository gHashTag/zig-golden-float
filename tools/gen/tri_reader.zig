//! TRI Format Specification Reader
//!
//! Reads .tri spec files (Trinity/GoldenFloat internal format).
//! Supports float (GF16) and ternary (TF3) formats.

const std = @import("std");

pub const Spec = struct {
    format: []const u8,
    version: u8,
    storage: Storage,
    fields: []Field,
    exponent: Exponent,
    rounding: Rounding,
    phi: Phi,
    ternary: ?Ternary,
    vsa: ?Vsa,
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
    encoding: []const u8,  // "binary", "balanced_ternary"
};

pub const Field = struct {
    name: []const u8,
    bits: u8,
    position_msb: u8,
    trit_value: bool = false,  // Is this a ternary sign field?
    trit_count: u8 = 0,       // Number of trits (for ternary)
    encoding: []const u8,     // "balanced_ternary"
};

pub const Exponent = struct {
    bits: u8,
    bias: u8,
    max: u8,
    min: u8,
    special: Special,
    trits: u8 = 0,          // Number of trits for ternary
    base: u8 = 2,            // Base for binary/ternary
    is_trits: bool = false,    // Is this a ternary exponent?

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
    trit_values: []const i8,  // [-1, 0, +1]
    encoding: []const u8,          // "balanced" (-1=10, 0=00, +1=01)
    bits_per_trit: u8,
    total_trits: u8,
};

pub const Vsa = struct {
    compatible: bool,
    bind_arity: u8,
    bundle_arity: u8,
    similarity: []const u8,  // "cosine"
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
    f32: f64,  // Stored as f64 for precision in JSON
    raw_hex: []const u8,
};

/// Load .tri JSON specification from file
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
    defer parser.deinit();

    return parser.parseSpec();
}

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

    fn deinit(self: *Parser) void {
        _ = self;
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

    fn skipWhitespace(self: *Parser) void {
        while (self.peek()) |ch| {
            if (ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r') {
                _ = self.advance();
            } else {
                break;
            }
        }
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
                self.pos -= 1;
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

    fn parseInt(self: *Parser, comptime T: type) !T {
        const str = try self.readValue();
        return std.fmt.parseInt(T, str, 10);
    }

    fn parseFloat(self: *Parser) !f64 {
        const str = try self.readValue();
        return std.fmt.parseFloat(f64, str);
    }

    fn parseSpec(self: *Parser) !Spec {
        var spec = Spec{
            .format = "unknown",
            .version = 1,
            .storage = undefined,
            .fields = undefined,
            .exponent = undefined,
            .rounding = undefined,
            .phi = undefined,
            .ternary = null,
            .vsa = null,
            .abi = undefined,
            .conversion = undefined,
            .test_vectors = undefined,
        };

        // Detect format from first key
        var is_float_spec = true;  // Default to GF16-like

        while (self.readKey()) |maybe_key| {
            const key = maybe_key orelse continue;

            if (std.mem.eql(u8, key, "trits") or std.mem.eql(u8, key, "vsa")) {
                is_float_spec = false;
            } else if (std.mem.eql(u8, key, "format")) {
                spec.format = try self.readValue();
            } else if (std.mem.eql(u8, key, "version")) {
                spec.version = try self.parseInt(u8);
            } else if (std.mem.eql(u8, key, "storage")) {
                spec.storage = try parseStorage(self);
            } else if (std.mem.eql(u8, key, "fields")) {
                spec.fields = try parseFieldList(self);
            } else if (std.mem.eql(u8, key, "exponent")) {
                spec.exponent = try parseExponent(self);
            } else if (std.mem.eql(u8, key, "rounding")) {
                spec.rounding = try parseRounding(self);
            } else if (std.mem.eql(u8, key, "phi")) {
                spec.phi = try parsePhi(self);
            } else if (std.mem.eql(u8, key, "ternary")) {
                spec.ternary = try parseTernary(self);
            } else if (std.mem.eql(u8, key, "vsa")) {
                spec.vsa = try parseVsa(self);
            } else if (std.mem.eql(u8, key, "abi")) {
                spec.abi = try parseAbi(self);
            } else if (std.mem.eql(u8, key, "conversion")) {
                spec.conversion = try parseConversion(self, self);
            } else if (std.mem.eql(u8, key, "test_vectors")) {
                spec.test_vectors = try parseTestVectors(self);
            } else {
                // Unknown key, skip value
                _ = self.readValue() catch {};
            }

            self.skipWhitespaceAndComments();
        }

        return spec;
    }

    fn parseStorage(parser: *Parser) !Storage {
        return .{
            .bits = try parser.parseInt(u8),
            .align_bytes = try parser.parseInt(u8),
            .endianness = try parser.readValue(),
            .underlying = try parser.readValue(),
            .encoding = try parser.readValue() orelse "binary",
        };
    }

    fn parseFieldList(parser: *Parser) ![]Field {
        var list = std.ArrayList(Field).init(parser.allocator);
        errdefer list.deinit();

        // Skip list marker
        _ = parser.advance(); // Skip '-'

        parser.skipWhitespaceAndComments();

        // Read field properties (name, bits, position_msb, optional trit fields)
        while (true) : (parser.skipWhitespaceAndComments()) {
            // Check if new section or list item starts
            if (parser.peek()) |ch| {
                if (ch == '-' or ch == '\n' or ch == '#') break;
            }

            const key = parser.readKey() orelse continue;
            const val = try parser.readValue();

            if (std.mem.eql(u8, key, "name")) {
                if (list.items.len == 0) break;
                list.items[list.items.len - 1].name = val;
            } else if (std.mem.eql(u8, key, "bits")) {
                list.items[list.items.len - 1].bits = try parser.parseInt(u8);
            } else if (std.mem.eql(u8, key, "position_msb")) {
                list.items[list.items.len - 1].position_msb = try parser.parseInt(u8);
            } else if (std.mem.eql(u8, key, "trit_value")) {
                list.items[list.items.len - 1].trit_value = true;
            } else if (std.mem.eql(u8, key, "trit_count")) {
                list.items[list.items.len - 1].trit_count = try parser.parseInt(u8);
            } else if (std.mem.eql(u8, key, "encoding")) {
                list.items[list.items.len - 1].encoding = try parser.readValue();
            }
        }

        return list.toOwnedSlice();
    }

    fn parseExponent(parser: *Parser) !Exponent {
        // Check for ternary fields
        var trits: u8 = 0;
        var is_trits: bool = false;
        var base: u8 = 2;

        while (parser.readKey()) |maybe_key| {
            const key = maybe_key orelse continue;

            if (std.mem.eql(u8, key, "bits")) {
                parser.skipWhitespaceAndComments();
                const bits_val = try parser.readValue();
                if (std.mem.eql(u8, bits_val, "3") or std.mem.eql(u8, bits_val, "6")) {
                    // OK for ternary
                }
            } else if (std.mem.eql(u8, key, "trits")) {
                parser.skipWhitespaceAndComments();
                trits = try parser.parseInt(u8);
                is_trits = true;
            } else if (std.mem.eql(u8, key, "base")) {
                parser.skipWhitespaceAndComments();
                base = try parser.parseInt(u8);
            } else {
                _ = parser.readValue() catch {};
            }

            parser.skipWhitespaceAndComments();
        }

        return parseExponentSpecial(parser);
    }

    fn parseExponentSpecial(parser: *Parser) !Exponent.Special {
        var special = Exponent.Special{
            .zero = undefined,
            .subnormal = undefined,
            .inf = undefined,
            .nan = undefined,
        };

        while (parser.readKey()) |maybe_key| {
            const key = maybe_key orelse continue;

            if (std.mem.eql(u8, key, "zero")) {
                special.zero = try parseExponentValue(parser);
            } else if (std.mem.eql(u8, key, "subnormal")) {
                special.subnormal = try parseExponentValue(parser);
            } else if (std.mem.eql(u8, key, "inf")) {
                special.inf = try parseExponentValue(parser);
            } else if (std.mem.eql(u8, key, "nan")) {
                special.nan = try parseExponentValue(parser);
            } else {
                _ = parser.readValue() catch {};
            }

            parser.skipWhitespaceAndComments();
        }

        return special;
    }

    fn parseExponentValue(parser: *Parser) !Exponent.SpecialValue {
        return .{
            .exponent = try parser.parseInt(u8),
            .mantissa = try parser.parseInt(u8),
        };
    }

    fn parseRounding(parser: *Parser) !Rounding {
        const mode_str = try parser.readValue();
        const mode = if (std.mem.eql(u8, mode_str, "ties-to-even"))
            .ties_to_even
        else if (std.mem.eql(u8, mode_str, "ties-to-zero"))
            .toward_zero
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

    fn parseTernary(parser: *Parser) !Ternary {
        const trit_values = [_]i8{ -1, 0, +1 };
        var bits_per_trit: u8 = 2;
        var encoding: []const u8 = "balanced";

        while (parser.readKey()) |maybe_key| {
            const key = maybe_key orelse continue;

            if (std.mem.eql(u8, key, "trit_values")) {
                encoding = try parser.readValue();
            } else if (std.mem.eql(u8, key, "bits_per_trit")) {
                bits_per_trit = try parser.parseInt(u8);
            } else if (std.mem.eql(u8, key, "total_trits")) {
                // Just for validation
                _ = parser.readInt(u8);
            } else {
                _ = parser.readValue() catch {};
            }

            parser.skipWhitespaceAndComments();
        }

        return .{
            .trit_values = &trit_values,
            .encoding = encoding,
            .bits_per_trit = bits_per_trit,
            .total_trits = 13,
        };
    }

    fn parseVsa(parser: *Parser) !Vsa {
        var compatible: bool = false;
        var bind_arity: u8 = 0;
        var bundle_arity: u8 = 0;
        var similarity: []const u8 = "cosine";

        while (parser.readKey()) |maybe_key| {
            const key = maybe_key orelse continue;

            if (std.mem.eql(u8, key, "compatible")) {
                const val = try parser.readValue();
                compatible = std.mem.eql(u8, val, "true");
            } else if (std.mem.eql(u8, key, "bind_arity")) {
                bind_arity = try parser.parseInt(u8);
            } else if (std.mem.eql(u8, key, "bundle_arity")) {
                bundle_arity = try parser.parseInt(u8);
            } else if (std.mem.eql(u8, key, "similarity")) {
                similarity = try parser.readValue();
            } else {
                _ = parser.readValue() catch {};
            }

            parser.skipWhitespaceAndComments();
        }

        return .{
            .compatible = compatible,
            .bind_arity = bind_arity,
            .bundle_arity = bundle_arity,
            .similarity = similarity,
        };
    }

    fn parseAbi(parser: *Parser) !Abi {
        var c_name: []const u8 = "uint16_t";
        var rust_name: []const u8 = "u16";
        var cpp_name: []const u8 = "uint16_t";
        var zig_name: []const u8 = "u16";

        while (parser.readKey()) |maybe_key| {
            const key = maybe_key orelse continue;

            if (std.mem.eql(u8, key, "c")) {
                c_name = try parser.readValue();
            } else if (std.mem.eql(u8, key, "rust")) {
                rust_name = try parser.readValue();
            } else if (std.mem.eql(u8, key, "cpp")) {
                cpp_name = try parser.readValue();
            } else if (std.mem.eql(u8, key, "zig")) {
                zig_name = try parser.readValue();
            } else {
                _ = parser.readValue() catch {};
            }

            parser.skipWhitespaceAndComments();
        }

        return .{
            .c = .{ .typename = c_name },
            .rust = .{ .typename = rust_name },
            .cpp = .{ .typename = cpp_name },
            .zig = .{ .typename = zig_name },
        };
    }

    fn parseConversion(parser: *Parser) !Conversion {
        var from_steps = std.ArrayList([]const u8).init(parser.allocator);
        defer from_steps.deinit();
        var to_steps = std.ArrayList([]const u8).init(parser.allocator);
        defer to_steps.deinit();

        if (parser.peek()) |ch| {
            if (ch == 'f' or ch == 't') {
                // Found from_f32_steps or to_f32_steps
                _ = parser.advance();
                const section_name = if (ch == 'f') "from" else "to";
                const section_start = parser.pos;

                parser.skipWhitespaceAndComments();

                // Read steps
                while (true) : (parser.skipWhitespaceAndComments()) {
                    if (parser.peek()) |step_ch| {
                        if (step_ch == '\n' or step_ch == '#' or step_ch == '-' or step_ch == '\r') break;
                    }

                    const step = try parser.readValue();
                    if (section_start < parser.pos) {
                        if (ch == 'f') {
                            try from_steps.append(step);
                        } else {
                            try to_steps.append(step);
                        }
                    }
                } else {
                    break;
                }
            }
        }
    } else {
        // No conversion steps, use defaults
        const defaults = &[_][]const u8{
            "extract_sign_exponent_mantissa",
            "compute_E = e32 - 127",
            "compute_e16 = E + 31",
            "handle_overflow_to_inf",
            "handle_underflow_to_subnormal_or_zero",
            "round_mantissa_to_bits_ties_to_even",
            "decode_fields",
            "handle_zero_subnormal_inf_nan",
            "compute_E = e16 - 31",
            "compute_e32 = E + 127",
            "build_f32_bits",
        };

        for (defaults) |step| {
            try from_steps.append(step);
            try to_steps.append(step);
        }
    }

    fn parseTestVectors(parser: *Parser) ![]TestVector {
        var list = std.ArrayList(TestVector).init(parser.allocator);
        defer list.deinit();

        // Read list items
        while (true) : (parser.skipWhitespaceAndComments()) {
            if (parser.peek()) |ch| {
                if (ch != '-') break;
            } else {
                break;
            }
        }

        if (parser.advance()) == null) break; // EOF
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
                if (ch == '\n' or ch == '#') break;
            }

            // New vector
            try list.append(vec);
            vec = .{
                .name = "",
                .f32 = 0.0,
                .raw_hex = "",
            };
        }

        return list.toOwnedSlice();
    }
};
