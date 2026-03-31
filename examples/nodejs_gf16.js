/**
 * GF16 Node.js Wrapper — N-API binding to libgoldenfloat.so
 *
 * **Build:**
 * ```bash
 * # macOS
 * DYLD_LIBRARY_PATH=zig-out/lib node-gcc node-gcc.js
 *
 * # Linux
 * LD_LIBRARY_PATH=zig-out/lib node-gcc node-gcc.js
 *
 *
 * **Publish:**
 * node-gyp configure target_name=node_gcc module_name=gf16
 * node-pre-gyp build
 * npx node-gyp clean
 * npm publish
 */

'use strict';

const dlopen = require('node:dlopen').dlopen;
const os = require('os');

// Find library path
const libPath = os.platform() === 'darwin'
    ? require('path').join(__dirname, '../zig-out/lib')
    : require('path').join(__dirname, '../zig-out/lib');

const libName = os.platform() === 'darwin'
    ? 'libgoldenfloat.dylib'
    : os.platform() === 'win32'
        ? 'goldenfloat.dll'
        : 'libgoldenfloat.so';

const gf16 = dlopen(libPath + '/' + libName);

// Function declarations
const gf16_from_f32 = gf16.symbols.gf16_from_f32;
const gf16_to_f32 = gf16.symbols.gf16_to_f32;
const gf16_add = gf16.symbols.gf16_add;
const gf16_sub = gf16.symbols.gf16_sub;
const gf16_mul = gf16.symbols.gf16_mul;
const gf16_div = gf16.symbols.gf16_div;
const gf16_neg = gf16.symbols.gf16_neg;
const gf16_abs = gf16.symbols.gf16_abs;
const gf16_eq = gf16.symbols.gf16_eq;
const gf16_lt = gf16.symbols.gf16_lt;
const gf16_le = gf16.symbols.gf16_le;
const gf16_is_zero = gf16.symbols.gf16_is_zero;
const gf16_is_inf = gf16.symbols.gf16_is_inf;
const gf16_is_nan = gf16.symbols.gf16_is_nan;
const gf16_phi_quantize = gf16.symbols.gf16_phi_quantize;
const gf16_phi_dequantize = gf16.symbols.gf16_phi_dequantize;
const gf16_copysign = gf16.symbols.gf16_copysign;
const gf16_min = gf16.symbols.gf16_min;
const gf16_max = gf16.symbols.gf16_max;
const gf16_fma = gf16.symbols.gf16_fma;

console.log('GF16 Node.js Wrapper');
console.log('Loaded from:', libPath + '/' + libName);

// ═════════════════════════════════════════════════════════════
// Basic Operations Demo
// ═══════════════════════════════════════════════════════════

console.log('\n=== Arithmetic Demo ===');

const a = gf16_from_f32(1.5);
const b = gf16_from_f32(2.5);

const sum = gf16_add(a, b);
console.log('1.5 + 2.5 =', gf16_to_f32(sum));
console.log('  1.5 - 2.5 =', gf16_to_f32(gf16_sub(a, b)));
console.log(' 1.5 × 2.5 =', gf16_to_f32(gf16_mul(a, b)));

// φ-Quantization
const weight = 2.71828;
const phi_q = gf16_phi_quantize(weight);
const phi_dq = gf16_phi_dequantize(phi_q);

console.log('\n=== φ-Quantization Demo ===');
console.log('Original weight:', weight);
console.log('φ-quantized:', phi_q);
console.log('φ-dequantized:', phi_dq);
console.log('φ-error (%):', ((phi_dq - weight) / weight) * 100);

// ═════════════════════════════════════════════════════════════════════════
// Comparison
console.log('\n=== Predicates Demo ===');

console.log('is_zero(GF16_ZERO):', gf16_is_zero(gf16.ZERO) ? 'true' : 'false');
console.log('is_inf(GF16_PINF):', gf16_is_inf(gf16.PINF) ? 'true' : 'false');
console.log('is_nan(GF16_NAN):', gf16_is_nan(gf16.NAN) ? 'true' : 'false');
console.log('is_negative(GF16_ONE):', gf16_is_negative(gf16.ONE) ? 'true' : 'false');

// FMA
console.log('\n=== FMA Demo ===');

const x = gf16_from_f32(2.0);
const y = gf16_from_f32(3.0);
const z = gf16_from_f32(1.0);

console.log('2.0 × 3.0 + 1.0 =', gf16_to_f32(gf16_fma(x, y, z)));

// ═══════════════════════════════════════════════════════════════════
// Library Info
console.log('\n=== Library Info ===');

const version = gf16.symbols.goldenfloat_version();
console.log('Version:', version);

const phi = gf16.symbols.goldenfloat_phi();
const trinity = gf16.symbols.goldenfloat_trinity();

console.log('φ:', phi);
console.log('φ² + 1/φ² =', phi * phi + 1.0 / phi);

// ═══════════════════════════════════════════════════════════════════════════════════════════
// N-API exports
const addonApi = {
    gf16_from_f32,
    gf16_to_f32,
    gf16_add,
    gf16_sub,
    gf16_mul,
    gf16_div,
    gf16_neg,
    gf16_abs,
    gf16_eq,
    gf16_lt,
    gf16_le,
    gf16_is_zero,
    gf16_is_inf,
    gf16_is_nan,
    gf16_phi_quantize,
    gf16_phi_dequantize,
    gf16_copysign,
    gf16_min,
    gf16_max,
    gf16_fma
};

module.exports = addonApi;
