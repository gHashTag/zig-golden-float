//! GF-T ladder usage example.
//!
//! Run:  zig run examples/gft_usage.zig
//!
//! Demonstrates the four rungs GF-T4/8/16/32, the generic GFT(E, M) factory,
//! arithmetic, raw-bit round-trips, and Inf/NaN/overflow/underflow behaviour.

const std = @import("std");
const gft = @import("../src/formats/gft.zig");
const print = std.debug.print;

pub fn main() void {
    // --- pick a rung by name -------------------------------------------------
    const a = gft.GFT16.fromF32(3.14159);
    const b = gft.GFT16.fromF32(2.71828);
    print("GF-T16:  3.14159 * 2.71828 = {d:.4}\n", .{a.mul(b).toF32()});
    print("GF-T16:  3.14159 + 2.71828 = {d:.4}\n", .{a.add(b).toF32()});

    // --- the full ladder, same value at four precisions ----------------------
    const v: f32 = 1.0 / 3.0;
    print("\n1/3 encoded at each rung (name / storage bits / decoded):\n", .{});
    inline for (.{ gft.GFT4, gft.GFT8, gft.GFT16, gft.GFT32 }, .{ "GF-T4", "GF-T8", "GF-T16", "GF-T32" }) |T, name| {
        print("  {s:7} {d:>2} bits  ->  {d:.6}\n", .{ name, T.BITS, T.fromF32(v).toF32() });
    }

    // --- raw storage round-trip (FFI / serialization) ------------------------
    const raw = a.bits();
    std.debug.assert(gft.GFT16.fromBits(raw).bits() == raw);
    print("\nGF-T16 raw bits of 3.14159 = 0x{X}\n", .{raw});

    // --- specials ------------------------------------------------------------
    std.debug.assert(!gft.GFT16.fromF32(1e30).isFinite()); // overflow -> Inf
    std.debug.assert(gft.GFT16.fromF32(1e-30).toF32() == 0.0); // underflow -> 0
    print("GF-T32 6.022e23 = {e}  (~219-decade range)\n", .{gft.GFT32.fromF32(6.022e23).toF32()});

    // --- mint a custom rung: 5 exponent trits, 12 mantissa bits --------------
    const MyRung = gft.GFT(5, 12);
    print("custom GFT(5,12): 42.5 -> {d:.3}  ({d} bits)\n", .{ MyRung.fromF32(42.5).toF32(), MyRung.BITS });
}
