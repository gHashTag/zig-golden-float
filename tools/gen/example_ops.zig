//! GF16 Arithmetic Operations (generated from specs/ops.tri)
//!
//! Level 1: Elementary arithmetic operations on GF16 values

const std = @import("std");

pub usingnamespace @import("gf16.zig");

pub fn add(a: GF16, b: GF16) GF16 {
    const fa = a.toF32();
    const fb = b.toF32();
    return GF16.fromF32(fa + fb);
}

pub fn sub(a: GF16, b: GF16) GF16 {
    const fa = a.toF32();
    const fb = b.toF32();
    return GF16.fromF32(fa - fb);
}

pub fn mul(a: GF16, b: GF16) GF16 {
    const fa = a.toF32();
    const fb = b.toF32();
    return GF16.fromF32(fa * fb);
}

pub fn div(a: GF16, b: GF16) GF16 {
    const fa = a.toF32();
    const fb = b.toF32();
    return GF16.fromF32(fa / fb);
}

pub fn sqrt(a: GF16) GF16 {
    const fa = a.toF32();
    return GF16.fromF32(@sqrt(fa));
}

pub fn abs(a: GF16) GF16 {
    return GF16.fromRaw(a.toRaw() & 0x7FFF);
}

pub fn neg(a: GF16) GF16 {
    return GF16.fromRaw(a.toRaw() ^ 0x8000);
}

pub fn cmp(a: GF16, b: GF16) struct { lt: bool, eq: bool, gt: bool } {
    const fa = a.toF32();
    const fb = b.toF32();
    return .{
        .lt = fa < fb,
        .eq = fa == fb,
        .gt = fa > fb,
    };
}

pub fn min(a: GF16, b: GF16) GF16 {
    return if (cmp(a, b).lt) a else b;
}

pub fn max(a: GF16, b: GF16) GF16 {
    return if (cmp(a, b).gt) a else b;
}
