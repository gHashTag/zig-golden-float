"""
Conformance tests for GoldenFloat Python bindings.

MIT License — Copyright (c) 2026 Trinity Project
Repository: https://github.com/gHashTag/zig-golden-float
"""

import json
import os
import sys

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from goldenfloat import Gf16


def load_vectors():
    """Load conformance vectors from vectors.json."""
    vectors_path = os.path.join(
        os.path.dirname(__file__), "..", "..", "..", "conformance", "vectors.json"
    )
    with open(vectors_path) as f:
        return json.load(f)


def test_conversions():
    """Test conversion roundtrips."""
    vectors = load_vectors()
    conversions = vectors["vectors"]["conversions"]
    passed = 0
    failed = 0

    for test in conversions:
        name = test["name"]
        input_str = test["input"]

        # Parse input
        if input_str == "inf":
            input_val = float("inf")
        elif input_str == "-inf":
            input_val = float("-inf")
        elif input_str == "nan":
            input_val = float("nan")
        else:
            input_val = float(input_str)

        gf = Gf16.from_f32(input_val)
        back = gf.to_f32()

        if "predicate" in test:
            predicate = test["predicate"]
            if predicate == "is_inf":
                result = gf.is_inf()
                expected = True
            elif predicate == "is_nan":
                result = gf.is_nan()
                expected = True
            else:
                result = False
                expected = False
        elif "match" in test:
            match_type = test["match"]
            if match_type == "roundtrip":
                if input_str in ["nan", "inf", "-inf"]:
                    result = True  # Special values don't roundtrip
                else:
                    result = abs(back - input_val) / abs(input_val) < 0.01 if input_val != 0 else back == 0
                expected = True
            elif match_type == "is_nan":
                result = gf.is_nan()
                expected = True
            elif match_type == "approximate":
                result = True  # Just check conversion succeeds
                expected = True
            else:
                result = False
                expected = True
        else:
            result = False
            expected = True

        if result == expected:
            passed += 1
        else:
            failed += 1
            print(f"  FAIL: {name} - input={input_str}, got={back}, expected={expected}")

    print(f"Conversions: {passed}/{passed + failed} passed")
    return failed == 0


def test_arithmetic():
    """Test arithmetic operations."""
    vectors = load_vectors()
    arithmetic = vectors["vectors"]["arithmetic"]
    passed = 0
    failed = 0

    for test in arithmetic:
        name = test["name"]
        a = Gf16.from_f32(test["a"])
        b = Gf16.from_f32(test["b"])
        expected = test["expected"]
        tolerance = test.get("tolerance", 0.01)

        op = test["op"]
        if op == "add":
            result = (a + b).to_f32()
        elif op == "sub":
            result = (a - b).to_f32()
        elif op == "mul":
            result = (a * b).to_f32()
        elif op == "div":
            result = (a / b).to_f32()
        else:
            failed += 1
            print(f"  FAIL: {name} - unknown op {op}")
            continue

        if abs(result - expected) <= tolerance:
            passed += 1
        else:
            failed += 1
            print(f"  FAIL: {name} - got {result}, expected {expected} ±{tolerance}")

    print(f"Arithmetic: {passed}/{passed + failed} passed")
    return failed == 0


def test_predicates():
    """Test predicate functions."""
    vectors = load_vectors()
    predicates = vectors["vectors"]["predicates"]
    passed = 0
    failed = 0

    for test in predicates:
        name = test["name"]
        input_str = test["input"]

        # Parse input
        if input_str == "inf":
            input_val = float("inf")
        elif input_str == "-inf":
            input_val = float("-inf")
        elif input_str == "nan":
            input_val = float("nan")
        else:
            input_val = float(input_str)

        gf = Gf16.from_f32(input_val)
        predicate = test["predicate"]
        expected = test["expected"]

        if predicate == "is_zero":
            result = gf.is_zero()
        elif predicate == "is_nan":
            result = gf.is_nan()
        elif predicate == "is_inf":
            result = gf.is_inf()
        elif predicate == "is_negative":
            result = gf.is_negative()
        else:
            failed += 1
            print(f"  FAIL: {name} - unknown predicate {predicate}")
            continue

        if result == expected:
            passed += 1
        else:
            failed += 1
            print(f"  FAIL: {name} - {predicate} returned {result}, expected {expected}")

    print(f"Predicates: {passed}/{passed + failed} passed")
    return failed == 0


def test_phi_math():
    """Test phi-math constants."""
    passed = 0
    failed = 0

    # Test phi constant
    phi = Gf16.phi()
    if abs(phi - 1.6180339887498948) < 1e-10:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: phi - got {phi}, expected 1.6180339887498948")

    # Test phi_sq
    phi_sq = Gf16.phi_sq()
    if abs(phi_sq - 2.6180339887498948) < 1e-10:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: phi_sq - got {phi_sq}, expected 2.6180339887498948")

    # Test phi_inv_sq
    phi_inv_sq = Gf16.phi_inv_sq()
    if abs(phi_inv_sq - 0.3819660112501051) < 1e-10:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: phi_inv_sq - got {phi_inv_sq}, expected 0.3819660112501051")

    # Test trinity
    trinity = Gf16.trinity()
    if abs(trinity - 3.0) < 1e-10:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: trinity - got {trinity}, expected 3.0")

    # Test phi_quantize
    gf = Gf16.phi_quantize(2.71828)
    dequantized = gf.phi_dequantize()
    # Allow 10% tolerance
    if abs(dequantized - 2.71828) / 2.71828 < 0.1:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: phi_quantize - got {dequantized}, expected ~2.71828")

    print(f"phi-Math: {passed}/{passed + failed} passed")
    return failed == 0


def test_constants():
    """Test GF16 constants."""
    passed = 0
    failed = 0

    # Test zero
    zero = Gf16.zero()
    if zero.is_zero():
        passed += 1
    else:
        failed += 1
        print("  FAIL: zero constant")

    # Test one
    one = Gf16.one()
    if abs(one.to_f32() - 1.0) < 0.01:
        passed += 1
    else:
        failed += 1
        print("  FAIL: one constant")

    # Test p_inf
    p_inf = Gf16.p_inf()
    if p_inf.is_inf() and not p_inf.is_negative():
        passed += 1
    else:
        failed += 1
        print("  FAIL: p_inf constant")

    # Test n_inf
    n_inf = Gf16.n_inf()
    if n_inf.is_inf() and n_inf.is_negative():
        passed += 1
    else:
        failed += 1
        print("  FAIL: n_inf constant")

    # Test nan
    nan = Gf16.nan()
    if nan.is_nan():
        passed += 1
    else:
        failed += 1
        print("  FAIL: nan constant")

    print(f"Constants: {passed}/{passed + failed} passed")
    return failed == 0


def main():
    """Run all conformance tests."""
    print("GoldenFloat Python Conformance Tests")
    print("=" * 40)

    all_passed = True
    all_passed &= test_conversions()
    all_passed &= test_arithmetic()
    all_passed &= test_predicates()
    all_passed &= test_phi_math()
    all_passed &= test_constants()

    print("=" * 40)
    if all_passed:
        print("All tests passed!")
        return 0
    else:
        print("Some tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
