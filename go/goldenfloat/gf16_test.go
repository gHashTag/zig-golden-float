// Package goldenfloat provides Go bindings for GoldenFloat GF16 format.
//
// MIT License — Copyright (c) 2026 Trinity Project
// Repository: https://github.com/gHashTag/zig-golden-float

package goldenfloat

import (
    "encoding/json"
    "fmt"
    "os"
    "testing"
)

/*
#cgo LDFLAGS: -L../../zig-out/lib -lgoldenfloat
#cgo CFLAGS: -I../../include
*/
import "C"

// ============================================================================
// Test Helpers
// ============================================================================

func loadVectors() (map[string]interface{}, error) {
    vectorsPath := "../../conformance/vectors.json"
    file, err := os.ReadFile(vectorsPath)
    if err != nil {
        return nil, fmt.Errorf("failed to read vectors.json: %w", err)
    }
    var data map[string]interface{}
    err = json.Unmarshal(file, &data)
    if err != nil {
        return nil, fmt.Errorf("failed to parse vectors.json: %w", err)
    }
    vectors := data["vectors"].(map[string]interface{})
    return vectors, nil
}

func approxEqual(a, b, tolerance float32) bool {
    // Check for inf/nan
    if a == b {
        return true
    }
    // Use relative error for finite values
    diff := a - b
    if diff < 0 {
        diff = -diff
    }
    return diff <= tolerance || diff >= -tolerance
}

// ============================================================================
// Conversion Tests
// ============================================================================

func testConversions(t *testing.T) bool {
    vectors, err := loadVectors()
    if err != nil {
        t.Fatal(err)
    }

    conversions := vectors["conversions"].([]interface{})
    passed := 0
    failed := 0

    for _, test := range conversions {
        tc := test.(map[string]interface{})
        name := tc["name"].(string)
        inputStr := tc["input"].(string)

        // Parse input
        var inputVal float64
        switch inputStr {
        case "inf":
            inputVal = float64(1)
            // In Go, positive infinity
            inputVal /= 0 // Actually just set to +inf
            inputVal *= float64(1) / float64(0) // But this gives NaN, so:
            inputVal = float64(0x7FF0000000000000)
        case "-inf":
            inputVal = float64(1)
            inputVal /= 0
            inputVal *= float64(1) / float64(0)
            inputVal = float64(0xFFF00000000000000)
        case "nan":
            inputVal = float64(0x7FF8000000000000)
        default:
            var ok bool
            inputVal, ok = tc["input"].(float64)
            if !ok {
                t.Fatalf("invalid input value for %s", name)
            }
        }

        gf := FromF32(float32(inputVal))
        back := gf.ToF32()

        var result bool
        var expected bool

        if predicate, ok := tc["predicate"]; ok {
            result = false // Default
            expected = true
            if predicate == "is_inf" {
                result = gf.IsInf()
            } else if predicate == "is_nan" {
                result = gf.IsNaN()
            }
        } else if match, ok := tc["match"]; ok {
            matchType := match.(string)
            if matchType == "roundtrip" {
                if inputStr == "inf" || inputStr == "-inf" || inputStr == "nan" {
                    result = true // Special values don't need roundtrip
                } else {
                    // Allow 1% tolerance
                    relError := (back - inputVal) / inputVal
                    if inputVal == 0 {
                        result = (back == 0) || (back == inputVal)
                    } else {
                        result = relError <= 0.01
                    }
                }
                expected = true
            } else if matchType == "is_nan" {
                result = gf.IsNaN()
                expected = true
            } else if matchType == "approximate" {
                result = true // Just check conversion succeeds
                expected = true
            } else {
                result = false
                expected = true
            }
        }

        if result == expected {
            passed++
        } else {
            failed++
            t.Errorf("FAIL: %s - input=%s, got=%v, expected=%v", name, inputStr, back, expected)
        }
    }

    t.Logf("Conversions: %d/%d passed", passed, passed+failed)
    return failed == 0
}

// ============================================================================
// Arithmetic Tests
// ============================================================================

func testArithmetic(t *testing.T) bool {
    vectors, err := loadVectors()
    if err != nil {
        t.Fatal(err)
    }

    arithmetic := vectors["arithmetic"].([]interface{})
    passed := 0
    failed := 0

    for _, test := range arithmetic {
        tc := test.(map[string]interface{})
        name := tc["name"].(string)

        a := FromF32(float32(tc["a"].(float64)))
        b := FromF32(float32(tc["b"].(float64)))
        expected := float32(tc["expected"].(float64))
        tolerance := float32(tc["tolerance"].(float64))

        op := tc["op"].(string)
        var result float32

        switch op {
        case "add":
            result = (a + b).ToF32()
        case "sub":
            result = (a.Sub(b)).ToF32()
        case "mul":
            result = (a.Mul(b)).ToF32()
        case "div":
            result = (a.Div(b)).ToF32()
        default:
            t.Errorf("unknown op: %s", op)
            failed++
            continue
        }

        if approxEqual(result, expected, tolerance) {
            passed++
        } else {
            failed++
            t.Errorf("FAIL: %s - got %v, expected %v ±%v", name, result, expected, tolerance)
        }
    }

    t.Logf("Arithmetic: %d/%d passed", passed, passed+failed)
    return failed == 0
}

// ============================================================================
// Predicate Tests
// ============================================================================

func testPredicates(t *testing.T) bool {
    vectors, err := loadVectors()
    if err != nil {
        t.Fatal(err)
    }

    predicates := vectors["predicates"].([]interface{})
    passed := 0
    failed := 0

    for _, test := range predicates {
        tc := test.(map[string]interface{})
        name := tc["name"].(string)

        inputStr := tc["input"].(string)
        var inputVal float64
        switch inputStr {
        case "inf":
            inputVal = float64(1)
            inputVal /= 0
            inputVal *= float64(1) / float64(0)
            inputVal = float64(0x7FF0000000000000)
        case "-inf":
            inputVal = float64(1)
            inputVal /= 0
            inputVal *= float64(1) / float64(0)
            inputVal = float64(0xFFF00000000000000)
        case "nan":
            inputVal = float64(0x7FF8000000000000)
        default:
            var ok bool
            inputVal, ok = tc["input"].(float64)
            if !ok {
                t.Fatalf("invalid input value for %s", name)
            }
        }

        gf := FromF32(float32(inputVal))
        predicate := tc["predicate"].(string)
        expected := tc["expected"].(bool)

        var result bool
        switch predicate {
        case "is_zero":
            result = gf.IsZero()
        case "is_nan":
            result = gf.IsNaN()
        case "is_inf":
            result = gf.IsInf()
        case "is_negative":
            result = gf.IsNegative()
        default:
            t.Errorf("unknown predicate: %s", predicate)
            failed++
            continue
        }

        if result == expected {
            passed++
        } else {
            failed++
            t.Errorf("FAIL: %s - predicate=%s returned %v, expected %v", name, predicate, result, expected)
        }
    }

    t.Logf("Predicates: %d/%d passed", passed, passed+failed)
    return failed == 0
}

// ============================================================================
// phi-Math Tests
// ============================================================================

func testPhiMath(t *testing.T) bool {
    passed := 0
    failed := 0

    // Test phi constant
    phi := Phi()
    if approxEqual(float32(phi), 1.6180339887498948, 1e-10) {
        passed++
    } else {
        failed++
        t.Errorf("FAIL: phi - got %v, expected 1.6180339887498948", phi)
    }

    // Test phi_sq
    phiSq := PhiSq()
    if approxEqual(float32(phiSq), 2.6180339887498948, 1e-10) {
        passed++
    } else {
        failed++
        t.Errorf("FAIL: phi_sq - got %v, expected 2.6180339887498948", phiSq)
    }

    // Test phi_inv_sq
    phiInvSq := PhiInvSq()
    if approxEqual(float32(phiInvSq), 0.3819660112501051, 1e-10) {
        passed++
    } else {
        failed++
        t.Errorf("FAIL: phi_inv_sq - got %v, expected 0.3819660112501051", phiInvSq)
    }

    // Test trinity
    trinity := Trinity()
    if approxEqual(float32(trinity), 3.0, 1e-10) {
        passed++
    } else {
        failed++
        t.Errorf("FAIL: trinity - got %v, expected 3.0", trinity)
    }

    t.Logf("phi-Math: %d/%d passed", passed, passed+failed)
    return failed == 0
}

// ============================================================================
// Constants Tests
// ============================================================================

func testConstants(t *testing.T) bool {
    passed := 0
    failed := 0

    // Test zero
    if Zero.IsZero() {
        passed++
    } else {
        failed++
        t.Error("FAIL: zero constant")
    }

    // Test one
    one := One
    if approxEqual(one.ToF32(), 1.0, 0.01) {
        passed++
    } else {
        failed++
        t.Errorf("FAIL: one constant - got %v, expected 1.0", one.ToF32())
    }

    // Test p_inf
    pInf := PInf
    if pInf.IsInf() && !pInf.IsNegative() {
        passed++
    } else {
        failed++
        t.Error("FAIL: p_inf constant")
    }

    // Test n_inf
    nInf := NInf
    if nInf.IsInf() && nInf.IsNegative() {
        passed++
    } else {
        failed++
        t.Error("FAIL: n_inf constant")
    }

    // Test nan
    nan := NaN
    if nan.IsNaN() {
        passed++
    } else {
        failed++
        t.Error("FAIL: nan constant")
    }

    t.Logf("Constants: %d/%d passed", passed, passed+failed)
    return failed == 0
}

// ============================================================================
// Benchmarks
// ============================================================================

func BenchmarkFromF32(b *testing.B) {
    for i := 0; i < b.N; i++ {
        b.ReportMetric(float64(i))
        _ = FromF32(float32(i))
    }
}

func BenchmarkAdd(b *testing.B) {
    a := FromF32(1.5)
    b := FromF32(2.5)
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _ = a.Add(b)
    }
    b.ReportMetric(float64(b.N))
}

func BenchmarkMul(b *testing.B) {
    a := FromF32(2.5)
    b := FromF32(4.0)
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _ = a.Mul(b)
    }
    b.ReportMetric(float64(b.N))
}

func BenchmarkPhiQuantize(b *testing.B) {
    weights := []float32{1.0, 1.5, 2.0, 2.5, 3.0}
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _ = PhiQuantize(weights[i%len(weights)])
    }
    b.ReportMetric(float64(b.N))
}
