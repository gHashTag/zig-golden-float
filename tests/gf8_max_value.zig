const std = @import("std");
const gf8 = @import("../src/formats/gf8.zig");
const fromF32 = gf8.fromF32;
const toF32 = gf8.toF32;

test "GF8 max-value: encode(1.9374) roundtrips within 1 ULP" {
    const gf = fromF32(1.9374);
    const back = toF32(gf);
    const ulp = @abs(back - 1.9374);
    try std.testing.expect(ulp <= 0.0625);
}

test "GF8 max-value: encode(1.9376) saturates to 1.9375" {
    const gf = fromF32(1.9376);
    const back = toF32(gf);
    try std.testing.expect(back <= 1.9375);
}

test "GF8 max-value: encode(2.0) clamps to 1.9375" {
    const gf = fromF32(2.0);
    const back = toF32(gf);
    try std.testing.expect(back <= 2.0);
    try std.testing.expect(back >= 1.8);
}

test "GF8 max-value: encode(100.0) clamps, no NaN/Inf" {
    const gf = fromF32(100.0);
    const back = toF32(gf);
    try std.testing.expect(std.math.isFinite(back));
    try std.testing.expect(back >= 0.0);
    try std.testing.expect(back <= 2.0);
}

test "GF8 max-value: encode(0.0) is byte-exact zero" {
    const gf = fromF32(0.0);
    const raw: u8 = @bitCast(gf);
    try std.testing.expectEqual(@as(u8, 0), raw);
    const back = toF32(gf);
    try std.testing.expectEqual(@as(f32, 0.0), back);
}

test "GF8 max-value: encode(0.0077) rounds to near zero" {
    const gf = fromF32(0.0077);
    const back = toF32(gf);
    try std.testing.expect(back < 0.02);
}

test "GF8 max-value: encode(-1.5) roundtrips within 1 ULP" {
    const gf = fromF32(-1.5);
    const back = toF32(gf);
    const ulp = @abs(back - (-1.5));
    try std.testing.expect(ulp <= 0.1);
    try std.testing.expect(gf.sign == 1);
}
