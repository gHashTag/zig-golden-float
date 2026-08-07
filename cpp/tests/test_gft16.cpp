/**
 * GoldenFloat — GF-T16 C++ binding smoke tests (self-contained, no JSON dep).
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#include <goldenfloat/gft16.hpp>
#include <cassert>
#include <cmath>
#include <cstdio>

using goldenfloat::Gft16;

static bool approx(float a, float b, float tol) {
    return std::fabs(a - b) / (std::fabs(b) + 1e-9f) <= tol;
}

int main() {
    // round-trip (9-bit mantissa -> < 0.5%)
    const float vals[] = {1.0f, -1.0f, 0.5f, 2.0f, 3.14159f, -3.14159f, 100.0f, 0.001f, 12345.0f};
    for (float v : vals) {
        float q = Gft16::from_f32(v).to_f32();
        assert(approx(q, v, 0.005f));
    }

    // arithmetic
    auto a = Gft16::from_f32(1.5f);
    auto b = Gft16::from_f32(2.5f);
    assert(approx((a + b).to_f32(), 4.0f, 0.02f));
    assert(approx((b - a).to_f32(), 1.0f, 0.02f));
    assert(approx((a * b).to_f32(), 3.75f, 0.02f));
    assert(approx((a / b).to_f32(), 0.6f, 0.02f));

    // neg / abs / is_finite
    auto x = Gft16::from_f32(3.5f);
    assert(approx((-x).to_f32(), -3.5f, 0.02f));
    assert(approx((-x).abs().to_f32(), 3.5f, 0.02f));
    assert(Gft16::from_f32(1.0f).is_finite());
    assert(!Gft16::from_f32(1e30f).is_finite()); // overflow -> Inf

    // raw is a 17-bit value
    assert(Gft16::from_f32(3.14159f).raw() <= 0x1FFFF);

    std::printf("GF-T16 C++ binding: ALL PASS\n");
    return 0;
}
