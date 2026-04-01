#!/usr/bin/env python3
"""
GoldenFloat — PyTorch Integration via C-ABI

**Prerequisites:**
1. Build shared library: zig build shared
2. pip install torch numpy

**Run:**
    DYLD_LIBRARY_PATH=zig-out/lib python examples/pytorch_integration.py
    LD_LIBRARY_PATH=zig-out/lib python examples/pytorch_integration.py  # Linux
"""

import ctypes
import torch
import numpy as np
from pathlib import Path

# ═════════════════════════════════════════════════════════════════════
# Load GoldenFloat shared library
# ═════════════════════════════════════════════════════════════════════

# Find library path
lib_path = Path(__file__).parent.parent / "zig-out" / "lib"
if not lib_path.exists():
    raise RuntimeError(f"Library path not found: {lib_path}")

# Try different platform names
for lib_name in ["libgoldenfloat.dylib", "libgoldenfloat.so", "goldenfloat.dll"]:
    lib_file = lib_path / lib_name
    if lib_file.exists():
        gf_lib = ctypes.CDLL(str(lib_file))
        print(f"✓ Loaded GoldenFloat from: {lib_file}")
        break
else:
    raise RuntimeError(f"Cannot find libgoldenfloat in {lib_path}")

# ═════════════════════════════════════════════════════════════════════
# Define C function signatures
# ═════════════════════════════════════════════════════════════════════

gf16_t = ctypes.c_uint16  # GF16 is uint16_t

# Conversion functions
gf_lib.gf16_from_f32.restype = gf16_t
gf_lib.gf16_from_f32.argtypes = [ctypes.c_float]

gf_lib.gf16_to_f32.restype = ctypes.c_float
gf_lib.gf16_to_f32.argtypes = [gf16_t]

# Arithmetic
gf_lib.gf16_add.restype = gf16_t
gf_lib.gf16_add.argtypes = [gf16_t, gf16_t]

gf_lib.gf16_mul.restype = gf16_t
gf_lib.gf16_mul.argtypes = [gf16_t, gf16_t]

# φ-Quantization
gf_lib.gf16_phi_quantize.restype = gf16_t
gf_lib.gf16_phi_quantize.argtypes = [ctypes.c_float]

gf_lib.gf16_phi_dequantize.restype = ctypes.c_float
gf_lib.gf16_phi_dequantize.argtypes = [gf16_t]

# Library info
gf_lib.goldenfloat_version.restype = ctypes.c_char_p
gf_lib.goldenfloat_version.argtypes = []

# ═════════════════════════════════════════════════════════════════════
# GF16Tensor — PyTorch-compatible wrapper
# ═════════════════════════════════════════════════════════════════════

class GF16Tensor:
    """GF16 tensor storage with PyTorch interop"""

    def __init__(self, data):
        """
        Args:
            data: torch.Tensor, numpy array, or list
        """
        if isinstance(data, torch.Tensor):
            data = data.cpu().numpy().flatten()
        elif isinstance(data, np.ndarray):
            data = data.flatten()
        else:
            data = np.array(data).flatten()

        # Store as uint16 (GF16 bit pattern)
        self._data = np.array([
            gf_lib.gf16_from_f32(float(x)) for x in data
        ], dtype=np.uint16)

    def to_float(self) -> np.ndarray:
        """Convert back to float32"""
        return np.array([
            gf_lib.gf16_to_f32(uint16) for uint16 in self._data
        ], dtype=np.float32)

    def to_torch(self) -> torch.Tensor:
        """Convert to PyTorch tensor"""
        return torch.from_numpy(self.to_float())

    @classmethod
    def phi_quantize(cls, weights: torch.Tensor) -> 'GF16Tensor':
        """φ-optimized quantization for ML weights"""
        flat = weights.cpu().numpy().flatten()
        quantized = np.array([
            gf_lib.gf16_phi_quantize(float(w)) for w in flat
        ], dtype=np.uint16)
        result = cls.__new__(cls)
        result._data = quantized
        return result

    def phi_dequantize(self) -> torch.Tensor:
        """φ-optimized dequantization"""
        dequantized = np.array([
            gf_lib.gf16_phi_dequantize(uint16) for uint16 in self._data
        ], dtype=np.float32)
        return torch.from_numpy(dequantized)

    def __len__(self):
        return len(self._data)

    def __repr__(self):
        return f"GF16Tensor(shape={self._data.shape}, dtype=uint16)"


# ═════════════════════════════════════════════════════════════════════
# Demo 1: Basic Quantization
# ═════════════════════════════════════════════════════════════════════

def demo_basic_quantization():
    print("\n" + "="*60)
    print("DEMO 1: Basic Quantization (PyTorch → GF16 → PyTorch)")
    print("="*60)

    # Create PyTorch tensor
    original = torch.tensor([3.14, 2.71, 1.41, 0.577, -1.62])
    print(f"\nOriginal (PyTorch): {original}")

    # Quantize to GF16
    gf16_tensor = GF16Tensor(original)
    print(f"GF16 bits (hex):    {[hex(x) for x in gf16_tensor._data[:5]]}")

    # Dequantize back
    recovered = gf16_tensor.to_torch()
    print(f"Recovered (PyTorch): {recovered}")

    # Calculate error
    error_pct = torch.abs((original - recovered) / original) * 100
    print(f"Error (%):          {error_pct}")


# ═════════════════════════════════════════════════════════════════════
# Demo 2: Neural Network Weight Quantization
# ═════════════════════════════════════════════════════════════════════

def demo_weight_quantization():
    print("\n" + "="*60)
    print("DEMO 2: Neural Network Weight Quantization")
    print("="*60)

    # Simulated neural network layer weights (normal distribution)
    torch.manual_seed(42)
    layer_weights = torch.randn(128, 64) * 0.1  # Typical: small random weights

    print(f"\nOriginal weights: shape={layer_weights.shape}")
    print(f"  Min: {layer_weights.min().item():.6f}")
    print(f"  Max: {layer_weights.max().item():.6f}")
    print(f"  Mean: {layer_weights.mean().item():.6f}")
    print(f"  Std: {layer_weights.std().item():.6f}")

    # Standard quantization
    gf16_standard = GF16Tensor(layer_weights)
    recovered_standard = gf16_standard.to_torch().reshape(layer_weights.shape)

    # φ-optimized quantization
    gf16_phi = GF16Tensor.phi_quantize(layer_weights)
    recovered_phi = gf16_phi.phi_dequantize().reshape(layer_weights.shape)

    # Compare errors
    error_std = torch.abs(layer_weights - recovered_standard).mean().item()
    error_phi = torch.abs(layer_weights - recovered_phi).mean().item()

    print(f"\nStandard GF16 error:  {error_std:.8f}")
    print(f"φ-optimized GF16 error: {error_phi:.8f}")
    print(f"Improvement:          {(1 - error_phi/error_std)*100:.2f}%")


# ═════════════════════════════════════════════════════════════════════
# Demo 3: Gradient Stability Simulation
# ═════════════════════════════════════════════════════════════════════

def demo_gradient_stability():
    print("\n" + "="*60)
    print("DEMO 3: Gradient Stability (Overflow Resistance)")
    print("="*60)

    # Simulate gradients that might overflow in f16
    gradients = torch.tensor([
        1.0, 10.0, 100.0, 1000.0, 10000.0,
        65000.0, 65504.0, 65535.0, 100000.0  # Beyond f16 max
    ])

    print("\nGradient magnitudes:")
    for i, g in enumerate(gradients):
        print(f"  {i+1}. {g:10.0f}")

    # Quantize gradients
    gf16_gradients = GF16Tensor(gradients)
    recovered = gf16_gradients.to_torch()

    print("\nAfter GF16 roundtrip:")
    for i, (orig, rec) in enumerate(zip(gradients, recovered)):
        if orig.item() > 65504:  # f16 max
            status = "✓ Preserved" if rec.item() > 65000 else "✗ Lost"
        else:
            status = "  OK"
        print(f"  {i+1}. {orig:10.0f} → {rec:10.0f}  {status}")


# ═════════════════════════════════════════════════════════════════════
# Demo 4: Matrix Multiplication with GF16
# ═════════════════════════════════════════════════════════════════════

def demo_matmul():
    print("\n" + "="*60)
    print("DEMO 4: Matrix Multiplication (GF16 + C-ABI)")
    print("="*60)

    # Small matrices for demonstration
    A = torch.randn(4, 4)
    B = torch.randn(4, 4)

    # Reference: float32 matmul
    C_ref = A @ B

    # Quantize inputs
    A_gf16 = GF16Tensor(A)
    B_gf16 = GF16Tensor(B)

    # Dequantize and compute (simulating GF16 matmul)
    A_rec = A_gf16.to_torch().reshape(A.shape)
    B_rec = B_gf16.to_torch().reshape(B.shape)
    C_gf16 = A_rec @ B_rec

    error = torch.abs(C_ref - C_gf16).mean().item()
    max_error = torch.abs(C_ref - C_gf16).max().item()

    print(f"\nMatrix shape: {A.shape}")
    print(f"Mean error:  {error:.8f}")
    print(f"Max error:   {max_error:.8f}")

    print(f"\nReference (first row):")
    print(f"  {C_ref[0, :]}")
    print(f"GF16 approximation:")
    print(f"  {C_gf16[0, :]}")


# ═════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════

def main():
    # Print library version
    version = gf_lib.goldenfloat_version().decode('utf-8')
    print("\n" + "="*60)
    print("GoldenFloat — PyTorch Integration via C-ABI")
    print("="*60)
    print(f"\nLibrary version: {version}")

    # Run demos
    demo_basic_quantization()
    demo_weight_quantization()
    demo_gradient_stability()
    demo_matmul()

    print("\n" + "="*60)
    print("All demos completed successfully!")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
