//! Rust FFI Example — Using GoldenFloat from Rust via goldenfloat-sys
//!
//! Build the library first:
//!     zig build shared
//!
//! Then run:
//!     cargo run --example ffi_example
//!
//! Or with explicit library path:
//!     DYLD_LIBRARY_PATH=../../zig-out/lib cargo run --example ffi_example

use goldenfloat_sys::*;

fn main() {
    println!("GoldenFloat Rust FFI Example v1.1.0");
    println!("===================================\n");

    // Test basic conversion
    unsafe {
        let pi: gf16_t = gf16_from_f32(3.14159);
        let back = gf16_to_f32(pi);
        println!("Conversion:");
        println!("  Original: {:.5}", 3.14159);
        println!("  GF16:     0x{:04X}", pi);
        println!("  Back:     {:.5}", back);
        println!("  Error:    {:.2}%\n", (3.14159 - back) / 3.14159 * 100.0);

        // Test arithmetic
        let a = gf16_from_f32(1.5);
        let b = gf16_from_f32(2.5);
        let sum = gf16_add(a, b);
        let prod = gf16_mul(a, b);
        let diff = gf16_sub(b, a);
        let quot = gf16_div(a, b);

        println!("Arithmetic:");
        println!("  1.5 + 2.5 = {:.2} (expected 4.0)", gf16_to_f32(sum));
        println!("  1.5 * 2.5 = {:.2} (expected 3.75)", gf16_to_f32(prod));
        println!("  2.5 - 1.5 = {:.2} (expected 1.0)", gf16_to_f32(diff));
        println!("  1.5 / 2.5 = {:.2} (expected 0.6)\n", gf16_to_f32(quot));

        // Test φ-quantization
        let weight = 2.71828;
        let quantized = gf16_phi_quantize(weight);
        let dequantized = gf16_phi_dequantize(quantized);

        println!("φ-Quantization:");
        println!("  Original:     {:.5}", weight);
        println!("  Quantized:    0x{:04X}", quantized);
        println!("  Dequantized:  {:.5}\n", dequantized);

        // Test predicates
        let zero = gf16_from_f32(0.0);
        let inf_val = gf16_from_f32(std::f32::INFINITY);
        let neg_val = gf16_from_f32(-5.0);

        println!("Predicates:");
        println!("  gf16_is_zero(zero):     {}", gf16_is_zero(zero));
        println!("  gf16_is_inf(inf):      {}", gf16_is_inf(inf_val));
        println!("  gf16_is_negative(neg): {}", gf16_is_negative(neg_val));
        println!("  gf16_is_nan(GF16_NAN):  {}\n", gf16_is_nan(GF16_NAN));

        // Test comparison
        let x = gf16_from_f32(1.0);
        let y = gf16_from_f32(2.0);
        let z = gf16_from_f32(1.0);

        println!("Comparison:");
        println!("  gf16_eq(1.0, 1.0): {}", gf16_eq(x, z));
        println!("  gf16_lt(1.0, 2.0): {}", gf16_lt(x, y));
        println!("  gf16_cmp(1.0, 2.0): {}", gf16_cmp(x, y));
        println!("  gf16_cmp(2.0, 1.0): {}\n", gf16_cmp(y, x));

        // Test FMA (fused multiply-add)
        let four = gf16_from_f32(4.0);
        let fma_result = gf16_fma(a, b, four);

        println!("FMA:");
        println!("  1.5 * 2.5 + 4.0 = {:.2} (expected 7.75)\n", gf16_to_f32(fma_result));

        // Test bit extraction
        println!("Bit Extraction (GF16_ONE = 0x{:04X}):", GF16_ONE);
        println!("  GF16_SIGN(GF16_ONE):   {}", GF16_SIGN(GF16_ONE));
        println!("  GF16_EXP(GF16_ONE):    {}", GF16_EXP(GF16_ONE));
        println!("  GF16_MANT(GF16_ONE):   {}\n", GF16_MANT(GF16_ONE));

        // Test library info
        let version = std::ffi::CStr::from_ptr(goldenfloat_version() as *const i8);
        let phi = goldenfloat_phi();
        let trinity = goldenfloat_trinity();

        println!("Library Info:");
        println!("  Version: {:?}", version.to_str().unwrap());
        println!("  PHI: {:.10}", phi);
        println!("  Trinity (PHI^2 + 1/PHI^2): {:.1}", trinity);
    }
}
