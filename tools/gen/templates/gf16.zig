//! GF16: φ-optimized 16-bit floating point
//! Generated from specs/gf16.tri
//!
//! MIT License — Copyright (c) 2026 Trinity Project

const GF16 = packed struct(u16) {
    sign: u1,
    exponent: u6,
    mantissa: u9,

    pub const PINF: GF16 = @bitCast(@as(u16, 0x7E00));
    pub const NINF: GF16 = @bitCast(@as(u16, 0xFE00));
    pub const NAN: GF16 = @bitCast(@as(u16, 0x7E01));
    pub const ZERO: GF16 = @bitCast(@as(u16, 0x0000));
    pub const NEG_ZERO: GF16 = @bitCast(@as(u16, 0x8000));

    pub inline fn fromRaw(raw: u16) GF16 {
        return @bitCast(raw);
    }

    pub inline fn toRaw(self: GF16) u16 {
        return @bitCast(self);
    }

    pub inline fn signBit(self: GF16) u1 {
        return self.sign;
    }

    pub inline fn expBiased(self: GF16) u6 {
        return self.exponent;
    }

    pub inline fn expUnbiased(self: GF16) i16 {
        return @as(i16, @intCast(self.exponent)) - 31;
    }

    pub inline fn mantissaBits(self: GF16) u9 {
        return self.mantissa;
    }

    pub inline fn isNan(self: GF16) bool {
        return self.exponent == 63 and self.mantissa != 0;
    }

    pub inline fn isInf(self: GF16) bool {
        return self.exponent == 63 and self.mantissa == 0;
    }

    pub inline fn isZero(self: GF16) bool {
        return self.exponent == 0 and self.mantissa == 0;
    }

    pub inline fn abs(self: GF16) GF16 {
        var result = self;
        result.sign = 0;
        return result;
    }

    pub inline fn negate(self: GF16) GF16 {
        var result = self;
        result.sign = ~result.sign;
        return result;
    }
};

comptime {
    std.debug.assert(@bitSizeOf(GF16) == 16);
    std.debug.assert(@alignOf(GF16) >= 2);
}
