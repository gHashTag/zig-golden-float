/**
 * GoldenFloat C++ Demo
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 * Repository: https://github.com/gHashTag/zig-golden-float
 */

#include <goldenfloat/gf16.hpp>
#include <iostream>
#include <iomanip>

int main() {
    std::cout << "GoldenFloat C++ Demo v1.0.0" << std::endl;
    std::cout << "==========================" << std::endl;
    std::cout << std::endl;

    // Basic conversion
    std::cout << "Basic Conversion:" << std::endl;
    Gf16 pi = Gf16::from_f32(3.14159f);
    std::cout << "  pi (f32): 3.14159" << std::endl;
    std::cout << "  pi (GF16): " << pi.to_f32() << std::endl;
    std::cout << std::endl;

    // Arithmetic
    std::cout << "Arithmetic:" << std::endl;
    Gf16 a = Gf16::from_f32(1.5f);
    Gf16 b = Gf16::from_f32(2.5f);

    std::cout << "  1.5 + 2.5 = " << (a + b).to_f32() << " (expected 4.0)" << std::endl;
    std::cout << "  1.5 * 2.5 = " << (a * b).to_f32() << " (expected 3.75)" << std::endl;
    std::cout << "  2.5 - 1.5 = " << (b - a).to_f32() << " (expected 1.0)" << std::endl;
    std::cout << "  1.5 / 2.5 = " << (a / b).to_f32() << " (expected 0.6)" << std::endl;
    std::cout << std::endl;

    // Predicates
    std::cout << "Predicates:" << std::endl;
    Gf16 zero = Gf16::zero();
    std::cout << "  zero.is_zero(): " << std::boolalpha << zero.is_zero() << std::endl;

    Gf16 inf = Gf16::p_inf();
    std::cout << "  inf.is_inf(): " << std::boolalpha << inf.is_inf() << std::endl;

    Gf16 neg = Gf16::from_f32(-5.0f);
    std::cout << "  neg.is_negative(): " << std::boolalpha << neg.is_negative() << std::endl;
    std::cout << std::endl;

    // phi-Math
    std::cout << "phi-Math:" << std::endl;
    std::cout << std::setprecision(10);
    std::cout << "  phi: " << Gf16::phi() << std::endl;
    std::cout << "  phi_sq: " << Gf16::phi_sq() << std::endl;
    std::cout << "  phi_inv_sq: " << Gf16::phi_inv_sq() << std::endl;
    std::cout << "  trinity: " << Gf16::trinity() << std::endl;
    std::cout << std::endl;

    // phi-Quantization
    std::cout << "phi-Quantization:" << std::endl;
    float weight = 2.71828f;
    Gf16 quantized = Gf16::phi_quantize(weight);
    float dequantized = quantized.phi_dequantize();
    std::cout << std::setprecision(6);
    std::cout << "  Original: " << weight << std::endl;
    std::cout << "  Dequantized: " << dequantized << std::endl;
    std::cout << std::endl;

    // FMA (Fused Multiply-Add)
    std::cout << "FMA:" << std::endl;
    Gf16 c = Gf16::from_f32(4.0f);
    Gf16 fma_result = Gf16::fma(a, b, c);
    std::cout << "  1.5 * 2.5 + 4.0 = " << fma_result.to_f32() << " (expected 7.75)" << std::endl;

    return 0;
}
