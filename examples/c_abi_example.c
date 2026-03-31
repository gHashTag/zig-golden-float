/**
 * C-ABI Example — Using GoldenFloat from C
 *
 * Build:
 *   gcc -Izig-out/include -Lzig-out/lib -o c_example c_abi_example.c -lgoldenfloat
 *
 * Run:
 *   ./c_example
 */

#include <stdio.h>
#include "gf16.h"

int main(void) {
    printf("GoldenFloat C-ABI Example v1.1.0\n");
    printf("==================================\n\n");

    // Test basic conversion
    float pi = 3.14159f;
    gf16_t gf_pi = gf16_from_f32(pi);
    float back = gf16_to_f32(gf_pi);
    printf("Original: %.5f\n", pi);
    printf("GF16:     0x%04X\n", gf_pi);
    printf("Back:     %.5f\n", back);
    printf("Error:    %.2f%%\n\n", (pi - back) / pi * 100.0f);

    // Test arithmetic
    gf16_t a = gf16_from_f32(1.5f);
    gf16_t b = gf16_from_f32(2.5f);
    gf16_t sum = gf16_add(a, b);
    gf16_t prod = gf16_mul(a, b);
    printf("Arithmetic:\n");
    printf("  1.5 + 2.5 = %.2f (expected 4.0)\n", gf16_to_f32(sum));
    printf("  1.5 * 2.5 = %.2f (expected 3.75)\n\n", gf16_to_f32(prod));

    // Test φ-quantization
    float weight = 2.71828f;
    gf16_t quantized = gf16_phi_quantize(weight);
    float dequantized = gf16_phi_dequantize(quantized);
    printf("φ-Quantization:\n");
    printf("  Original:     %.5f\n", weight);
    printf("  Quantized:    0x%04X\n", quantized);
    printf("  Dequantized:  %.5f\n\n", dequantized);

    // Test predicates
    gf16_t zero = gf16_from_f32(0.0f);
    gf16_t inf = gf16_from_f32(__builtin_inff());
    gf16_t neg = gf16_from_f32(-5.0f);
    printf("Predicates:\n");
    printf("  gf16_is_zero(zero):    %s\n", gf16_is_zero(zero) ? "true" : "false");
    printf("  gf16_is_inf(inf):     %s\n", gf16_is_inf(inf) ? "true" : "false");
    printf("  gf16_is_negative(neg): %s\n\n", gf16_is_negative(neg) ? "true" : "false");

    // Test constants
    printf("Constants:\n");
    printf("  GF16_ZERO:  0x%04X\n", GF16_ZERO);
    printf("  GF16_ONE:   0x%04X\n", GF16_ONE);
    printf("  GF16_PINF:  0x%04X\n", GF16_PINF);
    printf("  GF16_NAN:   0x%04X\n", GF16_NAN);
    printf("  GF16_TRINITY: %.1f\n\n", GF16_TRINITY);

    // Test library info
    printf("Library Info:\n");
    printf("  Version: %s\n", "1.1.0");
    printf("  PHI: %.10f\n", GF16_PHI);
    printf("  PHI^2 + 1/PHI^2 = %.1f\n", GF16_PHI_SQ + GF16_PHI_INV_SQ);

    return 0;
}
