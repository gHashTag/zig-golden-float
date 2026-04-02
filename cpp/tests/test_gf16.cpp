/**
 * GoldenFloat C++ Conformance Tests
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 * Repository: https://github.com/gHashTag/zig-golden-float
 */

#include <goldenfloat/gf16.hpp>
#include <iostream>
#include <cassert>
#include <cmath>
#include <fstream>
#include <nlohmann/json.hpp>

using namespace goldenfloat;

using json = nlohmann::json;

// ============================================================================
// Test Helpers
// ============================================================================

json load_vectors() {
    std::ifstream vectors_file("../../conformance/vectors.json");
    if (!vectors_file.is_open()) {
        std::cerr << "Failed to open conformance/vectors.json" << std::endl;
        exit(1);
    }
    json data;
    vectors_file >> data;
    return data;
}

bool approx_equal(float a, float b, float tolerance = 0.01f) {
    if (std::isnan(a) && std::isnan(b)) return true;
    if (std::isinf(a) && std::isinf(b)) return (a > 0) == (b > 0);
    return std::abs(a - b) <= tolerance;
}

// ============================================================================
// Conversion Tests
// ============================================================================

bool test_conversions() {
    auto vectors = load_vectors();
    int passed = 0, failed = 0;

    for (const auto& test : vectors["vectors"]["conversions"]) {
        std::string name = test["name"];
        std::string input_str = test["input"];

        float input_val;
        if (input_str == "inf") {
            input_val = std::numeric_limits<float>::infinity();
        } else if (input_str == "-inf") {
            input_val = -std::numeric_limits<float>::infinity();
        } else if (input_str == "nan") {
            input_val = std::numeric_limits<float>::quiet_NaN();
        } else {
            input_val = test["input"];
        }

        Gf16 gf = Gf16::from_f32(input_val);
        float back = gf.to_f32();

        bool result = false;
        bool expected = true;

        if (test.contains("predicate")) {
            std::string predicate = test["predicate"];
            if (predicate == "is_inf") {
                result = gf.is_inf();
            } else if (predicate == "is_nan") {
                result = gf.is_nan();
            }
        } else if (test.contains("match")) {
            std::string match = test["match"];
            if (match == "roundtrip") {
                result = approx_equal(back, input_val, 0.01f);
            } else if (match == "is_nan") {
                result = gf.is_nan();
            } else {
                result = true;
            }
        }

        if (result == expected) {
            passed++;
        } else {
            failed++;
            std::cout << "  FAIL: " << name << " - input=" << input_str
                      << ", got=" << back << std::endl;
        }
    }

    std::cout << "Conversions: " << passed << "/" << (passed + failed) << " passed" << std::endl;
    return failed == 0;
}

// ============================================================================
// Arithmetic Tests
// ============================================================================

bool test_arithmetic() {
    auto vectors = load_vectors();
    int passed = 0, failed = 0;

    for (const auto& test : vectors["vectors"]["arithmetic"]) {
        std::string name = test["name"];
        float a_val = test["a"];
        float b_val = test["b"];
        float expected = test["expected"];
        float tolerance = test["tolerance"];

        Gf16 a = Gf16::from_f32(a_val);
        Gf16 b = Gf16::from_f32(b_val);
        std::string op = test["op"];

        float result;
        if (op == "add") {
            result = (a + b).to_f32();
        } else if (op == "sub") {
            result = (a - b).to_f32();
        } else if (op == "mul") {
            result = (a * b).to_f32();
        } else if (op == "div") {
            result = (a / b).to_f32();
        } else {
            failed++;
            std::cout << "  FAIL: " << name << " - unknown op " << op << std::endl;
            continue;
        }

        if (std::abs(result - expected) <= tolerance) {
            passed++;
        } else {
            failed++;
            std::cout << "  FAIL: " << name << " - got " << result
                      << ", expected " << expected << " ±" << tolerance << std::endl;
        }
    }

    std::cout << "Arithmetic: " << passed << "/" << (passed + failed) << " passed" << std::endl;
    return failed == 0;
}

// ============================================================================
// Predicate Tests
// ============================================================================

bool test_predicates() {
    auto vectors = load_vectors();
    int passed = 0, failed = 0;

    for (const auto& test : vectors["vectors"]["predicates"]) {
        std::string name = test["name"];
        std::string input_str = test["input"];

        float input_val;
        if (input_str == "inf") {
            input_val = std::numeric_limits<float>::infinity();
        } else if (input_str == "-inf") {
            input_val = -std::numeric_limits<float>::infinity();
        } else if (input_str == "nan") {
            input_val = std::numeric_limits<float>::quiet_NaN();
        } else {
            input_val = test["input"];
        }

        Gf16 gf = Gf16::from_f32(input_val);
        std::string predicate = test["predicate"];
        bool expected = test["expected"];

        bool result = false;
        if (predicate == "is_zero") {
            result = gf.is_zero();
        } else if (predicate == "is_nan") {
            result = gf.is_nan();
        } else if (predicate == "is_inf") {
            result = gf.is_inf();
        } else if (predicate == "is_negative") {
            result = gf.is_negative();
        }

        if (result == expected) {
            passed++;
        } else {
            failed++;
            std::cout << "  FAIL: " << name << " - " << predicate
                      << " returned " << result << ", expected " << expected << std::endl;
        }
    }

    std::cout << "Predicates: " << passed << "/" << (passed + failed) << " passed" << std::endl;
    return failed == 0;
}

// ============================================================================
// phi-Math Tests
// ============================================================================

bool test_phi_math() {
    int passed = 0, failed = 0;

    // Test phi constant
    if (std::abs(Gf16::phi() - 1.6180339887498948) < 1e-10) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: phi - got " << Gf16::phi()
                  << ", expected 1.6180339887498948" << std::endl;
    }

    // Test phi_sq
    if (std::abs(Gf16::phi_sq() - 2.6180339887498948) < 1e-10) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: phi_sq - got " << Gf16::phi_sq()
                  << ", expected 2.6180339887498948" << std::endl;
    }

    // Test phi_inv_sq
    if (std::abs(Gf16::phi_inv_sq() - 0.3819660112501051) < 1e-10) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: phi_inv_sq - got " << Gf16::phi_inv_sq()
                  << ", expected 0.3819660112501051" << std::endl;
    }

    // Test trinity
    if (std::abs(Gf16::trinity() - 3.0) < 1e-10) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: trinity - got " << Gf16::trinity()
                  << ", expected 3.0" << std::endl;
    }

    // Test phi_quantize
    Gf16 gf = Gf16::phi_quantize(2.71828f);
    float dequantized = gf.phi_dequantize();
    if (std::abs(dequantized - 2.71828f) / 2.71828f < 0.1) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: phi_quantize - got " << dequantized
                  << ", expected ~2.71828" << std::endl;
    }

    std::cout << "phi-Math: " << passed << "/" << (passed + failed) << " passed" << std::endl;
    return failed == 0;
}

// ============================================================================
// Constants Tests
// ============================================================================

bool test_constants() {
    int passed = 0, failed = 0;

    // Test zero
    Gf16 zero = Gf16::zero();
    if (zero.is_zero()) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: zero constant" << std::endl;
    }

    // Test one
    Gf16 one = Gf16::one();
    if (std::abs(one.to_f32() - 1.0f) < 0.01f) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: one constant" << std::endl;
    }

    // Test p_inf
    Gf16 p_inf = Gf16::p_inf();
    if (p_inf.is_inf() && !p_inf.is_negative()) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: p_inf constant" << std::endl;
    }

    // Test n_inf
    Gf16 n_inf = Gf16::n_inf();
    if (n_inf.is_inf() && n_inf.is_negative()) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: n_inf constant" << std::endl;
    }

    // Test nan
    Gf16 nan = Gf16::nan();
    if (nan.is_nan()) {
        passed++;
    } else {
        failed++;
        std::cout << "  FAIL: nan constant" << std::endl;
    }

    std::cout << "Constants: " << passed << "/" << (passed + failed) << " passed" << std::endl;
    return failed == 0;
}

// ============================================================================
// Main
// ============================================================================

int main() {
    std::cout << "GoldenFloat C++ Conformance Tests" << std::endl;
    std::cout << "===================================" << std::endl;

    bool all_passed = true;
    all_passed &= test_conversions();
    all_passed &= test_arithmetic();
    all_passed &= test_predicates();
    all_passed &= test_phi_math();
    all_passed &= test_constants();

    std::cout << "===================================" << std::endl;
    if (all_passed) {
        std::cout << "All tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "Some tests failed!" << std::endl;
        return 1;
    }
}
