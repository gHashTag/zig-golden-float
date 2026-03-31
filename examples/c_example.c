/**
 * GoldenFloat C-ABI Example
 *
 * Demonstrates using libgoldenfloat from C/C++
 *
 * **Build:**
 * ```bash
 * gcc -o c_example examples/c_example.c \
 *     -Izig-out/include \
 *     -Lzig-out/lib \
 *     -lgoldenfloat
 * ```
 *
 * **Run:**
 * ```bash
 * DYLD_LIBRARY_PATH=zig-out/lib ./c_example  # macOS
 * LD_LIBRARY_PATH=zig-out/lib ./c_example     # Linux
 * ./c_example.exe                             # Windows (copy DLL to same dir)
 * ```
 */

#include <stdio.h>
#include <stdbool.h>
#include "gf16.h"

int main(void) {
    printf("═══════════════════════════════════════════════════════════════\n");
    printf("GoldenFloat C-ABI Example — v1.1.0\n");
    printf("═══════════════════════════════════════════════════════════════\n\n");

    // ────────────────────────────────────────────────────────────────────────
    // Conversion: f32 ↔ GF16
    // ────────────────────────────────────────────────────────────────────────
    printf("1. Conversion (f32 ↔ GF16):\n");
    printf("───────────────────────────────────────────────────────────────\n");

    float pi = 3.14159f;
    gf16_t gf_pi = gf16_from_f32(pi);
    float back = gf16_to_f32(gf_pi);

    printf("   Original:  %.6f\n", pi);
    printf("   GF16 bits: 0x%04x\n", gf_pi);
    printf("   Converted: %.6f\n", back);
    printf("   Error:     %.4f%%\n\n", 100.0f * (pi - back) / pi);

    // ────────────────────────────────────────────────────────────────────────
    // Bit Layout Inspection
    // ────────────────────────────────────────────────────────────────────────
    printf("2. Bit Layout [sign:1][exp:6][mant:9]:\n");
    printf("───────────────────────────────────────────────────────────────\n");
    printf("   Sign:     %d\n", GF16_SIGN(gf_pi));
    printf("   Exp:      %d (biased)\n", GF16_EXP(gf_pi));
    printf("   Mantissa: %d\n\n", GF16_MANT(gf_pi));

    // ────────────────────────────────────────────────────────────────────────
    // Arithmetic Operations
    // ────────────────────────────────────────────────────────────────────────
    printf("3. Arithmetic Operations:\n");
    printf("───────────────────────────────────────────────────────────────\n");

    gf16_t a = gf16_from_f32(1.5f);
    gf16_t b = gf16_from_f32(2.5f);

    gf16_t sum = gf16_add(a, b);
    gf16_t diff = gf16_sub(b, a);
    gf16_t prod = gf16_mul(a, b);
    gf16_t quot = gf16_div(a, b);

    printf("   1.5 + 2.5 = %.2f\n", gf16_to_f32(sum));
    printf("   2.5 - 1.5 = %.2f\n", gf16_to_f32(diff));
    printf("   1.5 × 2.5 = %.2f\n", gf16_to_f32(prod));
    printf("   1.5 / 2.5 = %.2f\n\n", gf16_to_f32(quot));

    // ────────────────────────────────────────────────────────────────────────
    // Unary Operations
    // ────────────────────────────────────────────────────────────────────────
    printf("4. Unary Operations:\n");
    printf("───────────────────────────────────────────────────────────────\n");

    gf16_t neg_val = gf16_from_f32(-3.14f);
    gf16_t abs_val = gf16_abs(neg_val);
    gf16_t negated = gf16_neg(neg_val);

    printf("   gf16_abs(-3.14)  = %.2f\n", gf16_to_f32(abs_val));
    printf("   gf16_neg(-3.14)  = %.2f\n\n", gf16_to_f32(negated));

    // ────────────────────────────────────────────────────────────────────────
    // Comparison Functions
    // ────────────────────────────────────────────────────────────────────────
    printf("5. Comparison Functions:\n");
    printf("───────────────────────────────────────────────────────────────\n");

    gf16_t x = gf16_from_f32(1.0f);
    gf16_t y = gf16_from_f32(2.0f);
    gf16_t z = gf16_from_f32(1.0f);

    printf("   1.0 == 1.0: %s\n", gf16_eq(x, z) ? "true" : "false");
    printf("   1.0 <  2.0: %s\n", gf16_lt(x, y) ? "true" : "false");
    printf("   1.0 <= 1.0: %s\n", gf16_le(x, z) ? "true" : "false");
    printf("   cmp(1.0, 2.0): %d\n\n", gf16_cmp(x, y));

    // ────────────────────────────────────────────────────────────────────────
    // Predicates
    // ────────────────────────────────────────────────────────────────────────
    printf("6. Predicate Functions:\n");
    printf("───────────────────────────────────────────────────────────────\n");

    gf16_t zero = GF16_ZERO;
    gf16_t one = GF16_ONE;
    gf16_t inf = gf16_from_f32(__builtin_inff());
    gf16_t nan = gf16_from_f32(__builtin_nanf(""));

    printf("   GF16_ZERO is zero:      %s\n", gf16_is_zero(zero) ? "true" : "false");
    printf("   GF16_ONE is negative:   %s\n", gf16_is_negative(one) ? "true" : "false");
    printf("   inf is infinity:       %s\n", gf16_is_inf(inf) ? "true" : "false");
    printf("   nan is NaN:            %s\n\n", gf16_is_nan(nan) ? "true" : "false");

    // ────────────────────────────────────────────────────────────────────────
    // φ-Optimized Quantization
    // ────────────────────────────────────────────────────────────────────────
    printf("7. φ-Optimized Quantization:\n");
    printf("───────────────────────────────────────────────────────────────\n");

    float weight = 0.71828f;  // Typical neural network weight
    gf16_t phi_q = gf16_phi_quantize(weight);
    float phi_dq = gf16_phi_dequantize(phi_q);

    printf("   Original weight:        %.6f\n", weight);
    printf("   φ-quantized (GF16):     0x%04x\n", phi_q);
    printf("   φ-dequantized:          %.6f\n", phi_dq);
    printf("   φ-error:                %.4f%%\n\n",
           100.0f * (weight - phi_dq) / weight);

    // ────────────────────────────────────────────────────────────────────────
    // Utility Functions
    // ────────────────────────────────────────────────────────────────────────
    printf("8. Utility Functions:\n");
    printf("───────────────────────────────────────────────────────────────\n");

    gf16_t m1 = gf16_from_f32(5.0f);
    gf16_t m2 = gf16_from_f32(3.0f);
    gf16_t m3 = gf16_from_f32(2.0f);
    gf16_t fma_result = gf16_fma(m1, m2, m3);  // 5 * 3 + 2 = 17

    printf("   gf16_fma(5, 3, 2) = %.2f\n", gf16_to_f32(fma_result));
    printf("   gf16_min(5, 3)     = %.2f\n", gf16_to_f32(gf16_min(m1, m2)));
    printf("   gf16_max(5, 3)     = %.2f\n\n", gf16_to_f32(gf16_max(m1, m2)));

    // ────────────────────────────────────────────────────────────────────────
    // Constants
    // ────────────────────────────────────────────────────────────────────────
    printf("9. Trinity Constants:\n");
    printf("───────────────────────────────────────────────────────────────\n");
    printf("   φ (PHI)         = %.10f\n", GF16_PHI);
    printf("   φ² (PHI_SQ)     = %.10f\n", GF16_PHI_SQ);
    printf("   1/φ² (INV_SQ)   = %.10f\n", GF16_PHI_INV_SQ);
    printf("   φ² + 1/φ² = 3   = %.1f  (Trinity Identity)\n\n", GF16_TRINITY);

    printf("═══════════════════════════════════════════════════════════════\n");
    printf("Example completed successfully!\n");
    printf("═══════════════════════════════════════════════════════════════\n");

    return 0;
}
