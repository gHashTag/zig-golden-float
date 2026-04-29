const std = @import("std");

const GF8_MAX: f32 = 1.9375;

test "GF8 encode/decode max value" {
    const max_enc = toGF8(GF8_MAX);
    const back = fromGF8(max_enc);

    // Should be exact (no rounding error at boundary)
    try std.testing.expect(@abs(back - GF8_MAX) < 0.0001);
}

test "GF8 value below max" {
    const below_enc = toGF8(1.0);
    const back = fromGF8(below_enc);

    try std.testing.expect(@abs(back - 1.0) < 0.0001);
}

test "GF8 normal value" {
    const normal_enc = toGF8(1.0);
    const back = fromGF8(normal_enc);

    try std.testing.expect(@abs(back - 1.0) < 0.0001);
}
TEST' && cd /Users/playra/repos/zig-golden-float && zig test tests/gf8_max_value.zig 2>&1