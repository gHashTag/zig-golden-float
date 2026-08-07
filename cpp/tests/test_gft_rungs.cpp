/**
 * GoldenFloat — GF-T8 / GF-T32 C++ binding smoke tests (self-contained, no JSON dep).
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#include <goldenfloat/gft_rungs.hpp>
#include <cassert>
#include <cmath>
#include <cstdio>

using goldenfloat::Gft8;
using goldenfloat::Gft32;

static bool approx(float a, float b, float tol) {
    return std::fabs(a - b) / (std::fabs(b) + 1e-9f) <= tol;
}

int main() {
    // ---- GF-T8 (4-bit mantissa -> ~3%, keep values inside [2^-13, 2^12]) ----
    for (float v : {1.0f, -1.0f, 0.5f, 2.0f, 3.0f, -3.0f, 100.0f, 0.05f}) {
        assert(approx(Gft8::from_f32(v).to_f32(), v, 0.04f));
    }
    {
        auto a = Gft8::from_f32(1.5f);
        auto b = Gft8::from_f32(2.5f);
        assert(approx((a + b).to_f32(), 4.0f, 0.05f));
        assert(approx((b - a).to_f32(), 1.0f, 0.05f));
        assert(approx((a * b).to_f32(), 3.75f, 0.05f));
        assert(approx((b / a).to_f32(), 2.5f / 1.5f, 0.06f));
        assert(approx((-a).to_f32(), -1.5f, 0.05f));
        assert(approx((-a).abs().to_f32(), 1.5f, 0.05f));
        assert(Gft8::from_f32(1.0f).is_finite());
        assert(!Gft8::from_f32(1e30f).is_finite()); // out of range -> Inf
        assert(a.raw() <= 0x3FF);                    // 10-bit
    }

    // ---- GF-T32 (25-bit mantissa -> near-exact, 219 decades) ----
    for (float v : {1.0f, -1.0f, 0.5f, 2.0f, 3.14159f, -3.14159f, 100.0f, 0.001f, 12345.0f, 1e30f}) {
        assert(approx(Gft32::from_f32(v).to_f32(), v, 0.005f));
    }
    {
        auto a = Gft32::from_f32(1.5f);
        auto b = Gft32::from_f32(2.5f);
        assert(approx((a + b).to_f32(), 4.0f, 0.001f));
        assert(approx((b - a).to_f32(), 1.0f, 0.001f));
        assert(approx((a * b).to_f32(), 3.75f, 0.001f));
        assert(approx((b / a).to_f32(), 2.5f / 1.5f, 0.001f));
        assert(approx((-a).to_f32(), -1.5f, 0.001f));
        assert(approx((-a).abs().to_f32(), 1.5f, 0.001f));
        // Every finite f32 is finite in GF-T32; only inf overflows.
        assert(Gft32::from_f32(1e30f).is_finite());
        assert(!Gft32::from_f32(INFINITY).is_finite());
        assert(a.raw() <= 0xFFFFFFFFFULL); // 36-bit
    }

    std::printf("GF-T8/GF-T32 C++ bindings: ALL PASS\n");
    return 0;
}
