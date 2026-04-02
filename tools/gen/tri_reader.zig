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

    pub fn deinit(self: *Spec, allocator: std.mem.Allocator) void {
        // Free field definitions
        allocator.free(self.fields);
        allocator.free(self.test_vectors);

        // Free Level 5 (data structures) fields
        if (self.spec_type) |t| allocator.free(t);
        for (self.types) |td| {
            allocator.free(td.name);
            if (td.generic) |g| allocator.free(g);
            for (td.fields) |f| {
                allocator.free(f.name);
                allocator.free(f.type);
            }
            allocator.free(td.fields);
            if (td.variant == .enum_type) allocator.free(td.enum_values);
        }
        allocator.free(self.types);
        for (self.constants) |c| {
            allocator.free(c.name);
            allocator.free(c.value);
        }
        allocator.free(self.constants);
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
pub fn load(allocator: std.mem.Allocator, path: []const u8) !Spec {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 10);
    defer allocator.free(content);

    var spec = try parse(allocator, content);
    spec.input_path = path;
    return spec;
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

        var end = self.pos;
        while (end > start and (self.content[end - 1] == ' ' or self.content[end - 1] == '\t')) {
            end -= 1;
        }

        const slice = self.content[start..end];
        // Allocate a copy to ensure the key persists after parsing
        const result = try self.allocator.dupe(u8, slice);
        // Convert []u8 to []const u8 by casting
        return @as([]const u8, result);
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

        if (self.peek()) |ch| {
            if (ch == '"') {
                _ = self.advance();
                return self.readUntil('"');
            }
        }

        while (self.advance()) |ch| {
            if (ch == '\n' or ch == '#') {
                self.pos -= 1;
                break;
            }
        }

        if (self.pos == start) return error.EmptyValue;

        var end = self.pos;
        while (end > start and (self.content[end - 1] == ' ' or self.content[end - 1] == '\t')) {
            end -= 1;
        }

        const slice = self.content[start..end];
        // Allocate a copy to ensure the value persists after parsing
        return self.allocator.dupe(u8, slice);
    }

    fn readUntil(self: *Parser, delimiter: u8) ![]const u8 {
        const start = self.pos;
        while (self.advance()) |ch| {
            if (ch == delimiter) {
                const slice = self.content[start .. self.pos - 1];
                return self.allocator.dupe(u8, slice);
            }
        }
        return error.UnexpectedEndOfFile;
    }

    fn parseInt(self: *Parser, comptime T: type) !T {
        const str = try self.readValue();
        defer self.allocator.free(str);
        return std.fmt.parseInt(T, str, 10);
    }

    fn parseFloat(self: *Parser) !f64 {
        const str = try self.readValue();
        defer self.allocator.free(str);
        return std.fmt.parseFloat(f64, str);
    }

    /// Consume a value and free it, for use when value is discarded
    fn consumeValue(self: *Parser) void {
        const value = self.readValue() catch return;
        self.allocator.free(value);
    }

    fn parseSpec(self: *Parser) !Spec {
        var spec = Spec{
            .format = "GF16",
            .version = 1,
            .level = 0,
            .storage = undefined,
            .fields = &.{},
            .exponent = undefined,
            .rounding = undefined,
            .phi = undefined,
            .ternary = null,
            .vsa = null,
            .abi = undefined,
            .conversion = undefined,
            .ops = &.{},
            .composite = null,
            .test_vectors = &.{},
        };

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "format")) {
                self.consumeValue();
            } else if (std.mem.eql(u8, maybe_key, "version")) {
                spec.version = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "level")) {
                spec.level = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "type")) {
                const type_val = try self.readValue();
                spec.spec_type = type_val;
            } else if (std.mem.eql(u8, maybe_key, "storage")) {
                self.consumeValue();
            } else if (std.mem.eql(u8, maybe_key, "version")) {
                spec.version = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "level")) {
                spec.level = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "type")) {
                spec.spec_type = try self.readValue();
            } else if (std.mem.eql(u8, maybe_key, "storage")) {
                spec.storage = try self.parseStorage();
            } else if (std.mem.eql(u8, maybe_key, "fields")) {
                spec.fields = try self.parseFieldList();
            } else if (std.mem.eql(u8, maybe_key, "exponent")) {
                spec.exponent = try self.parseExponent();
            } else if (std.mem.eql(u8, maybe_key, "rounding")) {
                spec.rounding = try self.parseRounding();
            } else if (std.mem.eql(u8, maybe_key, "phi")) {
                spec.phi = try self.parsePhi();
            } else if (std.mem.eql(u8, maybe_key, "ternary")) {
                spec.ternary = try self.parseTernary();
            } else if (std.mem.eql(u8, maybe_key, "vsa")) {
                spec.vsa = try self.parseVsa();
            } else if (std.mem.eql(u8, maybe_key, "abi")) {
                spec.abi = try self.parseAbi();
            } else if (std.mem.eql(u8, maybe_key, "conversion")) {
                _ = try self.parseConversion();
            } else if (std.mem.eql(u8, maybe_key, "ops")) {
                spec.ops = try self.parseOpList();
            } else if (std.mem.eql(u8, maybe_key, "constants")) {
                // constants: is a section header
                self.skipWhitespaceAndComments();
                if (self.peek()) |ch| {
                    if (ch == ':') _ = self.advance();
                }
                spec.constants = try self.parseConstants();
            } else if (std.mem.eql(u8, maybe_key, "types")) {
                // types: is a section header, not a key-value pair
                // Skip to next line for type definitions
                self.skipWhitespaceAndComments();
                if (self.peek()) |ch| {
                    if (ch == ':') _ = self.advance();
                }
                spec.types = try self.parseTypes();
            } else if (std.mem.eql(u8, maybe_key, "composite")) {
                spec.composite = try self.parseComposite();
            } else if (std.mem.eql(u8, maybe_key, "test_vectors")) {
                spec.test_vectors = try self.parseTestVectors();
            } else {
                self.consumeValue();
            }
        }

        return spec;
    }

    fn parseStorage(self: *Parser) !Storage {
        const bits = self.parseInt(u8) catch 0;
        const align_bytes = self.parseInt(u8) catch 1;
        const endianness = self.readValue() catch "";
        const underlying = self.readValue() catch "";
        const encoding = self.readValue() catch "binary";

        return .{
            .bits = bits,
            .align_bytes = align_bytes,
            .endianness = endianness,
            .underlying = underlying,
            .encoding = encoding,
        };
    }

    fn parseFieldList(self: *Parser) ![]Field {
        var list = std.ArrayList(Field).initCapacity(self.allocator, 0) catch unreachable;
        errdefer list.deinit(self.allocator);

        while (true) : (self.skipWhitespaceAndComments()) {
            if (self.peek()) |ch| {
                if (ch != '-') break;
            } else {
                break;
            }
            _ = self.advance(); // Skip '-'

            var field = Field{
                .name = "",
                .bits = 0,
                .position_msb = 0,
            };

            while (try self.readKey()) |maybe_key| {
                if (std.mem.eql(u8, maybe_key, "name")) {
                    field.name = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "bits")) {
                    field.bits = try self.parseInt(u8);
                } else if (std.mem.eql(u8, maybe_key, "position_msb")) {
                    field.position_msb = try self.parseInt(u8);
                } else if (std.mem.eql(u8, maybe_key, "trit_value")) {
                    field.trit_value = true;
                } else if (std.mem.eql(u8, maybe_key, "trit_count")) {
                    field.trit_count = try self.parseInt(u8);
                } else if (std.mem.eql(u8, maybe_key, "encoding")) {
                    field.encoding = try self.readValue();
                } else {
                    self.consumeValue();
                }

                self.skipWhitespaceAndComments();
                if (self.peek()) |ch| {
                    if (ch == '\n' or ch == '-') break;
                }
            }

            try list.append(self.allocator, field);
        }

        return list.toOwnedSlice(self.allocator);
    }

    fn parseExponent(self: *Parser) !Exponent {
        var special = Exponent.Special{
            .zero = undefined,
            .subnormal = undefined,
            .inf = undefined,
            .nan = undefined,
        };

        var trits: u8 = 0;
        var base: u8 = 2;

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "bits")) {
                self.consumeValue();
            } else if (std.mem.eql(u8, maybe_key, "bias")) {
                self.consumeValue();
            } else if (std.mem.eql(u8, maybe_key, "max")) {
                self.consumeValue();
            } else if (std.mem.eql(u8, maybe_key, "min")) {
                self.consumeValue();
            } else if (std.mem.eql(u8, maybe_key, "trits")) {
                trits = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "base")) {
                base = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "special")) {
                special = try self.parseExponentSpecial();
            } else {
                self.consumeValue();
            }
        }

        return .{
            .bits = try self.parseInt(u8),
            .bias = try self.parseInt(u8),
            .max = try self.parseInt(u8),
            .min = try self.parseInt(u8),
            .special = special,
            .trits = trits,
            .base = base,
        };
    }

    fn parseExponentSpecial(self: *Parser) !Exponent.Special {
        var special = Exponent.Special{
            .zero = undefined,
            .subnormal = undefined,
            .inf = undefined,
            .nan = undefined,
        };

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "zero")) {
                special.zero = try self.parseExponentValue();
            } else if (std.mem.eql(u8, maybe_key, "subnormal")) {
                special.subnormal = try self.parseExponentValue();
            } else if (std.mem.eql(u8, maybe_key, "inf")) {
                special.inf = try self.parseExponentValue();
            } else if (std.mem.eql(u8, maybe_key, "nan")) {
                special.nan = try self.parseExponentValue();
            } else {
                self.consumeValue();
            }
        }

        return special;
    }

    fn parseExponentValue(self: *Parser) !Exponent.SpecialValue {
        var value = Exponent.SpecialValue{
            .exponent = 0,
            .mantissa = 0,
        };

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "exponent")) {
                value.exponent = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "mantissa")) {
                value.mantissa = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "mantissa_nonzero")) {
                value.mantissa_nonzero = true;
            } else {
                self.consumeValue();
            }
        }

        return value;
    }

    fn parseRounding(self: *Parser) !Rounding {
        const mode_str = try self.readValue();
        const mode: Rounding.Mode = if (std.mem.eql(u8, mode_str, "ties-to-even"))
            .ties_to_even
        else if (std.mem.eql(u8, mode_str, "ties-to-zero"))
            .toward_zero
        else
            .ties_to_even;

        return .{
            .mode = mode,
            .source_type = try self.readValue(),
            .overflow_policy = try self.readValue(),
            .underflow_policy = try self.readValue(),
        };
    }

    fn parsePhi(self: *Parser) !Phi {
        return .{
            .total_bits = try self.parseInt(u8),
            .exponent_bits = try self.parseInt(u8),
            .mantissa_bits = try self.parseInt(u8),
            .target_ratio = try self.parseFloat(),
            .ratio = try self.parseFloat(),
            .distance = try self.parseFloat(),
        };
    }

    fn parseTernary(self: *Parser) !Ternary {
        const trit_values = [_]i8{ -1, 0, 1 };

        return .{
            .trit_values = &trit_values,
            .encoding = try self.readValue(),
            .bits_per_trit = try self.parseInt(u8),
            .total_trits = try self.parseInt(u8),
        };
    }

    fn parseVsa(self: *Parser) !Vsa {
        var compatible: bool = false;
        var bind_arity: u8 = 0;
        var bundle_arity: u8 = 0;
        var similarity: []const u8 = "cosine";

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "compatible")) {
                const val = try self.readValue();
                compatible = std.mem.eql(u8, val, "true");
            } else if (std.mem.eql(u8, maybe_key, "bind_arity")) {
                bind_arity = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "bundle_arity")) {
                bundle_arity = try self.parseInt(u8);
            } else if (std.mem.eql(u8, maybe_key, "similarity")) {
                similarity = try self.readValue();
            } else {
                self.consumeValue();
            }
        }

        return .{
            .compatible = compatible,
            .bind_arity = bind_arity,
            .bundle_arity = bundle_arity,
            .similarity = similarity,
        };
    }

    fn parseAbi(self: *Parser) !Abi {
        var c_name: []const u8 = "uint16_t";
        var rust_name: []const u8 = "u16";
        var cpp_name: []const u8 = "uint16_t";
        var zig_name: []const u8 = "u16";

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "c")) {
                c_name = try self.readValue();
            } else if (std.mem.eql(u8, maybe_key, "rust")) {
                rust_name = try self.readValue();
            } else if (std.mem.eql(u8, maybe_key, "cpp")) {
                cpp_name = try self.readValue();
            } else if (std.mem.eql(u8, maybe_key, "zig")) {
                zig_name = try self.readValue();
            } else {
                self.consumeValue();
            }
        }

        return .{
            .c = .{ .typename = c_name },
            .rust = .{ .typename = rust_name },
            .cpp = .{ .typename = cpp_name },
            .zig = .{ .typename = zig_name },
        };
    }

    fn parseConversion(self: *Parser) !Conversion {
        var from_steps = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch unreachable;
        defer from_steps.deinit(self.allocator);
        var to_steps = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch unreachable;
        defer to_steps.deinit(self.allocator);

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "from_f32_steps")) {
                while (true) {
                    self.skipWhitespaceAndComments();
                    if (self.peek()) |ch| {
                        if (ch == '-' or ch == '\n') {
                            if (ch == '-') {
                                _ = self.advance();
                                self.skipWhitespaceAndComments();
                            }
                            const step = try self.readValue();
                            try from_steps.append(self.allocator, step);
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }
            } else if (std.mem.eql(u8, maybe_key, "to_f32_steps")) {
                while (true) {
                    self.skipWhitespaceAndComments();
                    if (self.peek()) |ch| {
                        if (ch == '-' or ch == '\n') {
                            if (ch == '-') {
                                _ = self.advance();
                                self.skipWhitespaceAndComments();
                            }
                            const step = try self.readValue();
                            try to_steps.append(self.allocator, step);
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }
            } else {
                self.consumeValue();
            }
        }

        if (from_steps.items.len == 0) {
            try from_steps.append(self.allocator, "decode");
            try from_steps.append(self.allocator, "f32_op");
            try from_steps.append(self.allocator, "encode");
        }

        if (to_steps.items.len == 0) {
            try to_steps.append(self.allocator, "decode");
            try to_steps.append(self.allocator, "f32_value");
        }

        return .{
            .from_f32_steps = try from_steps.toOwnedSlice(self.allocator),
            .to_f32_steps = try to_steps.toOwnedSlice(self.allocator),
        };
    }

    fn parseOpList(self: *Parser) ![]const Op {
        var list = std.ArrayList(Op).initCapacity(self.allocator, 0) catch unreachable;
        errdefer list.deinit(self.allocator);

        while (true) : (self.skipWhitespaceAndComments()) {
            if (self.peek()) |ch| {
                if (ch != '-') break;
            } else {
                break;
            }
            _ = self.advance(); // Skip '-'

            const op_name = try self.readValue();

            var op = Op{
                .name = op_name,
                .inputs = &.{},
                .outputs = &.{},
                .algorithm = "",
                .domain = "",
                .table = null,
            };

            while (try self.readKey()) |maybe_key| {
                if (std.mem.eql(u8, maybe_key, "inputs")) {
                    // Parse list of inputs
                    var inputs = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch unreachable;
                    while (true) : (self.skipWhitespaceAndComments()) {
                        const peek_ch = self.peek() orelse break;
                        if (peek_ch == '-' or peek_ch == '\n') break;
                        if (peek_ch == '-') _ = self.advance();
                        const input = try self.readValue();
                        try inputs.append(self.allocator, input);
                    }
                    op.inputs = try inputs.toOwnedSlice(self.allocator);
                } else if (std.mem.eql(u8, maybe_key, "outputs")) {
                    var outputs = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch unreachable;
                    while (true) : (self.skipWhitespaceAndComments()) {
                        const peek_ch = self.peek() orelse break;
                        if (peek_ch == '-' or peek_ch == '\n') break;
                        if (peek_ch == '-') _ = self.advance();
                        const output = try self.readValue();
                        try outputs.append(self.allocator, output);
                    }
                    op.outputs = try outputs.toOwnedSlice(self.allocator);
                } else if (std.mem.eql(u8, maybe_key, "output")) {
                    op.output = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "description")) {
                    op.description = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "intermediate_type")) {
                    op.intermediate_type = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "algorithm")) {
                    op.algorithm = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "rounding")) {
                    op.rounding = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "commutative")) {
                    const val = try self.readValue();
                    op.commutative = std.mem.eql(u8, val, "true");
                } else if (std.mem.eql(u8, maybe_key, "associative_approx")) {
                    const val = try self.readValue();
                    op.associative_approx = std.mem.eql(u8, val, "true");
                } else if (std.mem.eql(u8, maybe_key, "single_rounding")) {
                    op.single_rounding = true;
                } else if (std.mem.eql(u8, maybe_key, "domain")) {
                    op.domain = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "table")) {
                    op.table = try self.parseOpTable();
                } else if (std.mem.eql(u8, maybe_key, "element_op")) {
                    op.element_op = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "reduction")) {
                    op.reduction = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "bounds")) {
                    op.bounds = try self.readValue();
                } else {
                    self.consumeValue();
                }

                self.skipWhitespaceAndComments();
                if (self.peek()) |ch| {
                    if (ch == '\n' or ch == '-') break;
                }
            }

            try list.append(self.allocator, op);
        }

        return list.toOwnedSlice(self.allocator);
    }

    fn parseOpTable(self: *Parser) !Op.Table {
        var entries = std.ArrayList(Op.Entry).initCapacity(self.allocator, 0) catch unreachable;
        defer entries.deinit(self.allocator);

        while (true) : (self.skipWhitespaceAndComments()) {
            if (self.peek()) |ch| {
                if (ch != '"') break;
            } else {
                break;
            }

            const key = try self.readValue(); // "a,b"
            self.consumeValue(); // ':'

            // Parse value or array
            if (self.peek()) |ch| {
                if (ch == '[') {
                    _ = self.advance();
                    var values = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch unreachable;
                    defer values.deinit(self.allocator);

                    while (true) {
                        const val = try self.readValue();
                        try values.append(self.allocator, val);

                        self.skipWhitespaceAndComments();
                        if (self.peek()) |end_ch| {
                            if (end_ch == ']') {
                                _ = self.advance();
                                break;
                            }
                        } else {
                            break;
                        }
                    }

                    const value_array = try values.toOwnedSlice(self.allocator);
                    try entries.append(self.allocator, .{ .key = key, .value = "", .value_array = value_array });
                } else {
                    const value = try self.readValue();
                    try entries.append(self.allocator, .{ .key = key, .value = value });
                }
            }

            self.skipWhitespaceAndComments();
            if (self.peek()) |ch| {
                if (ch == '\n' or ch == '-') break;
            }
        }

        return .{
            .entries = try entries.toOwnedSlice(self.allocator),
        };
    }

    fn parseComposite(self: *Parser) !Composite {
        var matmul: ?Composite.MatMul = null;
        var ternary_conv: ?Composite.TernaryConv = null;

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "matmul")) {
                matmul = try self.parseMatMul();
            } else if (std.mem.eql(u8, maybe_key, "ternary_conv")) {
                ternary_conv = try self.parseTernaryConv();
            } else {
                self.consumeValue();
            }
        }

        return .{
            .matmul = matmul,
            .ternary_conv = ternary_conv,
        };
    }

    fn parseMatMul(self: *Parser) !Composite.MatMul {
        _ = self;
        return .{
            .A = "TF3[M, K]",
            .B = "TF3[K, N]",
            .output = "TF3[M, N]",
            .accumulator = "i32",
            .inner_op = "dot",
            .tiling = .{ .block_m = 16, .block_n = 16, .block_k = 32 },
        };
    }

    fn parseTernaryConv(self: *Parser) !Composite.TernaryConv {
        var sparse: bool = false;

        while (try self.readKey()) |maybe_key| {
            if (std.mem.eql(u8, maybe_key, "sparse")) {
                const val = try self.readValue();
                sparse = std.mem.eql(u8, val, "true");
            } else {
                self.consumeValue();
            }
        }

        return .{
            .input = "TF3[H, W, C_in]",
            .weights = "TF3[K, K, C_in, C_out]",
            .output = "TF3[H, W, C_out]",
            .algorithm = "im2col_matmul",
            .sparse = sparse,
        };
    }

    fn parseTestVectors(self: *Parser) ![]TestVector {
        var list = std.ArrayList(TestVector).initCapacity(self.allocator, 0) catch unreachable;
        errdefer list.deinit(self.allocator);

        while (true) : (self.skipWhitespaceAndComments()) {
            if (self.peek()) |ch| {
                if (ch != '-') break;
            } else {
                break;
            }
            _ = self.advance(); // Skip '-'

            var vec = TestVector{
                .name = "",
                .f32 = 0.0,
                .raw_hex = "",
            };

            while (try self.readKey()) |maybe_key| {
                if (std.mem.eql(u8, maybe_key, "name")) {
                    vec.name = try self.readValue();
                } else if (std.mem.eql(u8, maybe_key, "f32")) {
                    vec.f32 = try self.parseFloat();
                } else if (std.mem.eql(u8, maybe_key, "raw_hex")) {
                    vec.raw_hex = try self.readValue();
                } else {
                    self.consumeValue();
                }

                self.skipWhitespaceAndComments();
                if (self.peek()) |ch| {
                    if (ch == '\n' or ch == '-') break;
                }
            }

            try list.append(self.allocator, vec);
        }

        return list.toOwnedSlice(self.allocator);
    }

    fn parseConstants(self: *Parser) ![]const ConstDef {
        // Parse constants: section
        // Format: indent 2 (4 spaces): NAME: value
        // Example:
        //   MAX_LEVEL: 16
        //   PROBABILITY: 0.5

        var constants = try std.ArrayList(ConstDef).initCapacity(self.allocator, 0);
        errdefer constants.deinit(self.allocator);

        // Get current position (after "constants:" key)
        const start_pos = self.pos;

        // Split remaining content into lines
        var lines_it = std.mem.splitScalar(u8, self.content[start_pos..], '\n');

        while (lines_it.next()) |raw_line| {
            // Skip empty lines and comments
            const trimmed = std.mem.trimLeft(u8, raw_line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Count indentation (2-space units)
            const indent = countIndent(raw_line);

            // Check for top-level section ending (ops:, composite:, types:, etc.)
            if (indent == 0) {
                if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
                    const key = trimmed[0..colon_idx];
                    if (std.mem.eql(u8, key, "ops") or std.mem.eql(u8, key, "composite") or
                        std.mem.eql(u8, key, "test_vectors") or std.mem.eql(u8, key, "description") or
                        std.mem.eql(u8, key, "storage") or std.mem.eql(u8, key, "level") or
                        std.mem.eql(u8, key, "format") or std.mem.eql(u8, key, "version") or
                        std.mem.eql(u8, key, "type") or std.mem.eql(u8, key, "types"))
                    {
                        break;
                    }
                }
            }

            // Constant definition at indent 1 (2 spaces): "MAX_LEVEL: 16"
            if (indent == 1) {
                if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
                    const const_name = std.mem.trimRight(u8, trimmed[0..colon_idx], " \t");
                    const const_value = std.mem.trim(u8, trimmed[colon_idx + 1 ..], " \t\r");
                    try constants.append(self.allocator, .{
                        .name = try self.allocator.dupe(u8, const_name),
                        .value = try self.allocator.dupe(u8, const_value),
                    });
                }
            }
        }

        return constants.toOwnedSlice(self.allocator);
    }

    fn parseTypes(self: *Parser) ![]const TypeDef {
        // Line-based parser for indentation-based type definitions
        // This handles YAML-like structure where type names are at indent 2
        // and their fields are nested at indent 6

        var types = try std.ArrayList(TypeDef).initCapacity(self.allocator, 0);
        errdefer types.deinit(self.allocator);

        // Get current position (after "types:" key)
        const start_pos = self.pos;

        // Split remaining content into lines
        var lines_it = std.mem.splitScalar(u8, self.content[start_pos..], '\n');

        var current_type: ?TypeDef = null;
        var current_fields: ?std.ArrayList(TypeField) = null;
        var in_fields_section = false;

        while (lines_it.next()) |raw_line| {
            // Skip empty lines and comments
            const trimmed = std.mem.trimLeft(u8, raw_line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Count indentation (2-space units)
            const indent = countIndent(raw_line);

            // Check for top-level section ending (ops:, composite:, etc.)
            if (indent == 0) {
                if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
                    const key = trimmed[0..colon_idx];
                    if (std.mem.eql(u8, key, "ops") or std.mem.eql(u8, key, "composite") or
                        std.mem.eql(u8, key, "test_vectors") or std.mem.eql(u8, key, "description") or
                        std.mem.eql(u8, key, "storage") or std.mem.eql(u8, key, "level") or
                        std.mem.eql(u8, key, "format") or std.mem.eql(u8, key, "version") or
                        std.mem.eql(u8, key, "type"))
                    {
                        // Save current type if exists
                        if (current_type) |*t| {
                            if (current_fields) |*f| {
                                t.fields = try f.toOwnedSlice(self.allocator);
                            }
                            try types.append(self.allocator, t.*);
                            current_type = null;
                            current_fields = null;
                        }
                        break;
                    }
                }
            }

            // Type definition at indent 1 (2 spaces): "Entry:" or "HashTable:"
            if (indent == 1) {
                // Save previous type
                if (current_type) |*t| {
                    if (current_fields) |*f| {
                        t.fields = try f.toOwnedSlice(self.allocator);
                    }
                    try types.append(self.allocator, t.*);
                }

                // Parse new type name (e.g., "Entry:" -> "Entry")
                if (std.mem.lastIndexOfScalar(u8, trimmed, ':')) |colon_idx| {
                    const type_name = std.mem.trimRight(u8, trimmed[0..colon_idx], " \t");
                    current_type = TypeDef{
                        .name = try self.allocator.dupe(u8, type_name),
                        .variant = .struct_type,
                    };
                    current_fields = std.ArrayList(TypeField).initCapacity(self.allocator, 0) catch unreachable;
                    in_fields_section = false;
                }
            }

            // "fields:" property at indent 2 (4 spaces)
            if (indent == 2 and std.mem.startsWith(u8, trimmed, "fields:")) {
                in_fields_section = true;
                continue;
            }

            // "generic:" property at indent 2 (4 spaces)
            if (indent == 2 and std.mem.startsWith(u8, trimmed, "generic:")) {
                if (current_type) |*t| {
                    const generic_val = std.mem.trim(u8, trimmed["generic:".len..], " \t\r");
                    t.generic = try self.allocator.dupe(u8, generic_val);
                }
                continue;
            }

            // "enum:" property at indent 2 (4 spaces)
            if (indent == 2 and std.mem.startsWith(u8, trimmed, "enum:")) {
                if (current_type) |*t| {
                    const enum_line = trimmed["enum:".len..];
                    const enum_val = std.mem.trim(u8, enum_line, " \t\r");
                    // Parse "[Red, Black]" -> ["Red", "Black"]
                    if (enum_val.len > 2 and enum_val[0] == '[' and enum_val[enum_val.len - 1] == ']') {
                        const values_str = enum_val[1 .. enum_val.len - 1];
                        var values = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
                        var iter = std.mem.splitScalar(u8, values_str, ',');
                        while (iter.next()) |v| {
                            const trimmed_val = std.mem.trim(u8, v, " \t");
                            if (trimmed_val.len > 0) {
                                try values.append(self.allocator, try self.allocator.dupe(u8, trimmed_val));
                            }
                        }
                        t.enum_values = try values.toOwnedSlice(self.allocator);
                        t.variant = .enum_type;
                    }
                }
                continue;
            }

            // Field definition at indent 3 (6 spaces): "- name: key"
            if (indent == 3 and in_fields_section and current_fields != null and std.mem.startsWith(u8, trimmed, "-")) {
                var field_line = trimmed[1..]; // Skip "-"
                field_line = std.mem.trimLeft(u8, field_line, " \t");

                // Parse "name: key" part
                if (std.mem.indexOfScalar(u8, field_line, ':')) |name_colon| {
                    const name_value = std.mem.trim(u8, field_line[name_colon + 1 ..], " \t\r");

                    // Look ahead on next line for "type: <type>" (indent 4)
                    var field_type: []const u8 = "";

                    if (lines_it.next()) |next_raw| {
                        const next_trimmed = std.mem.trimLeft(u8, next_raw, " \t\r");
                        const next_indent = countIndent(next_raw);

                        // Check if next line is "- name:" -> end of this field
                        if (next_indent == 3 and std.mem.startsWith(u8, next_trimmed, "-")) {
                            // No type on next line, use default (empty)
                            field_type = "";
                        } else if (next_indent >= 3 and std.mem.startsWith(u8, next_trimmed, "type:")) {
                            // Found "type:" on next line (could be indent 3 or 4)
                            const type_line = next_trimmed["type:".len..];
                            field_type = std.mem.trim(u8, type_line, " \t\r\"");
                        }
                    }

                    if (field_type.len == 0) field_type = "auto";

                    if (current_fields) |*f| {
                        try f.append(self.allocator, .{
                            .name = try self.allocator.dupe(u8, name_value),
                            .type = try self.allocator.dupe(u8, field_type),
                        });
                    }
                }
            }
        }

        // Save last type
        if (current_type) |*t| {
            if (current_fields) |*f| {
                t.fields = try f.toOwnedSlice(self.allocator);
            }
            try types.append(self.allocator, t.*);
        }

        // Update parser position to end of types section
        const end_pos = if (lines_it.index) |idx| start_pos + idx else start_pos;
        self.pos = end_pos;

        return try types.toOwnedSlice(self.allocator);
    }

    /// Count indentation level (2-space units)
    fn countIndent(line: []const u8) usize {
        var count: usize = 0;
        for (line) |ch| {
            if (ch == ' ') {
                count += 1;
            } else {
                break;
            }
        }
        return count / 2;
    }
};
