/**
 * GoldenFloat — Binary GF ladder C++ binding smoke tests (self-contained, no JSON dep).
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#include <goldenfloat/gf_ladder.hpp>
#include <cassert>
#include <cmath>
#include <cstdio>

using namespace goldenfloat;

static bool approx(float a, float b, float tol) {
    return std::fabs(a - b) / (std::fabs(b) + 1e-9f) <= tol;
}

// Values inside every rung's normal range (Gf8 is tightest: ~[0.25, 15.5]).
template <class GF>
static void check_rung(float rt_tol, float op_tol) {
    for (float v : {0.5f, 1.0f, 1.5f, 2.0f, 3.0f, -2.5f, 4.0f}) {
        assert(approx(GF::from_f32(v).to_f32(), v, rt_tol));
    }
    auto a = GF::from_f32(1.5f);
    auto b = GF::from_f32(2.5f);
    assert(approx((a + b).to_f32(), 4.0f, op_tol));
    assert(approx((b - a).to_f32(), 1.0f, op_tol));
    assert(approx((a * b).to_f32(), 3.75f, op_tol));
    assert(approx((b / a).to_f32(), 2.5f / 1.5f, op_tol));
    assert(approx((-a).to_f32(), -1.5f, op_tol));
    assert(approx((-a).abs().to_f32(), 1.5f, op_tol));
    assert(GF::from_f32(1.0f).is_finite());
    assert(!GF::from_f32(INFINITY).is_finite()); // inf overflows on every rung
}

int main() {
    check_rung<Gf8>(0.05f, 0.05f);
    check_rung<Gf12>(0.01f, 0.01f);
    check_rung<Gf20>(0.001f, 0.001f);
    check_rung<Gf24>(0.0005f, 0.0005f);
    check_rung<Gf32>(0.0002f, 0.0002f);

    // carrier widths
    assert(Gf8::from_f32(1.5f).raw() <= 0xFFu);
    assert(Gf12::from_f32(1.5f).raw() <= 0xFFFu);

    std::printf("Binary GF ladder C++ bindings: ALL PASS\n");
    return 0;
}
