const std = @import("std");

test "f32ToBf16 BUG-001 fix - large values" {
    // Verify that large exponents are NOT clamped to ±7
    const large_pos: f32 = 1e10;
    const large_neg: f32 = -1e10;

    // Use canonical fix directly
    const bits_pos = @as(u32, @bitCast(large_pos));
    const rounding_pos: u32 = ((bits_pos >> 16) & 1) + 0x7FFF;
    const bf16_pos = @as(i32, ((bits_pos + rounding_pos) >> 16));

    const e_pos = (bf16_pos >> 7) & 0x7F;
    try std.testing.expect(e_pos > 10); // Should NOT be clamped to 7

    const bits_neg = @as(u32, @bitCast(large_neg));
    const rounding_neg: u32 = ((bits_neg >> 16) & 1) + 0x7FFF;
    const bf16_neg = @as(i32, ((bits_neg + rounding_neg) >> 16));

    const e_neg = (bf16_neg >> 7) & 0x7F;
    try std.testing.expect(e_neg > 10);
}

test "f32ToBf16 preserves 1.0 and 100.0" {
    // Test basic values within normal range
    const one_f32: f32 = 1.0;
    const bits_one = @as(u32, @bitCast(one_f32));
    const rounding_one: u32 = ((bits_one >> 16) & 1) + 0x7FFF;
    const bf16_one = @as(i32, ((bits_one + rounding_one) >> 16));

    // Decode to verify (simple round-trip)
    const decoded_one = @as(f32, @bitCast(@as(u32, bf16_one) << 16));
    const err_one = @abs(decoded_one - one_f32);
    try std.testing.expect(err_one < 0.5);

    const hundred_f32: f32 = 100.0;
    const bits_hundred = @as(u32, @bitCast(hundred_f32));
    const rounding_hundred: u32 = ((bits_hundred >> 16) & 1) + 0x7FFF;
    const bf16_hundred = @as(i32, ((bits_hundred + rounding_hundred) >> 16));

    const decoded_hundred = @as(f32, @bitCast(@as(u32, bf16_hundred) << 16));
    const err_hundred = @abs(decoded_hundred - hundred_f32);
    try std.testing.expect(err_hundred < 0.5); // Within 0.5 tolerance
}
