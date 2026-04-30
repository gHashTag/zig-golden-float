package goldenfloat

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"testing"
)

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

func parseFloatInput(tc map[string]interface{}) float64 {
	inputStr, ok := tc["input"].(string)
	if !ok {
		if f, ok := tc["input"].(float64); ok {
			return f
		}
		return 0
	}
	switch inputStr {
	case "inf":
		return math.Inf(1)
	case "-inf":
		return math.Inf(-1)
	case "nan":
		return math.NaN()
	default:
		var f float64
		fmt.Sscanf(inputStr, "%f", &f)
		return f
	}
}

func approxEqual(a, b, tolerance float32) bool {
	if a == b {
		return true
	}
	diff := a - b
	if diff < 0 {
		diff = -diff
	}
	return diff <= tolerance
}

func TestConversions(t *testing.T) {
	vectors, err := loadVectors()
	if err != nil {
		t.Fatal(err)
	}

	conversions := vectors["conversions"].([]interface{})
	for _, test := range conversions {
		tc := test.(map[string]interface{})
		name := tc["name"].(string)
		inputVal := parseFloatInput(tc)

		gf := FromF32(float32(inputVal))
		back := gf.ToF32()

		if predicate, ok := tc["predicate"]; ok {
			predStr := predicate.(string)
			var result bool
			switch predStr {
			case "is_inf":
				result = gf.IsInf()
			case "is_nan":
				result = gf.IsNaN()
			}
			if !result {
				t.Errorf("FAIL: %s - predicate %s not satisfied", name, predStr)
			}
		} else if match, ok := tc["match"]; ok {
			matchType := match.(string)
			if matchType == "is_nan" {
				if !gf.IsNaN() {
					t.Errorf("FAIL: %s - expected NaN", name)
				}
			} else if matchType == "roundtrip" {
				if !math.IsInf(float64(inputVal), 0) && !math.IsNaN(float64(inputVal)) {
					if inputVal != 0 {
						relError := (float64(back) - inputVal) / inputVal
						if relError > 0.01 || relError < -0.01 {
							t.Errorf("FAIL: %s - got %v, expected ~%v", name, back, inputVal)
						}
					}
				}
			}
		}
	}
}

func TestArithmetic(t *testing.T) {
	vectors, err := loadVectors()
	if err != nil {
		t.Fatal(err)
	}

	arithmetic := vectors["arithmetic"].([]interface{})
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
			result = a.Add(b).ToF32()
		case "sub":
			result = a.Sub(b).ToF32()
		case "mul":
			result = a.Mul(b).ToF32()
		case "div":
			result = a.Div(b).ToF32()
		default:
			t.Errorf("unknown op: %s", op)
			continue
		}

		if !approxEqual(result, expected, tolerance) {
			t.Errorf("FAIL: %s - got %v, expected %v +/- %v", name, result, expected, tolerance)
		}
	}
}

func TestPredicates(t *testing.T) {
	vectors, err := loadVectors()
	if err != nil {
		t.Fatal(err)
	}

	predicates := vectors["predicates"].([]interface{})
	for _, test := range predicates {
		tc := test.(map[string]interface{})
		name := tc["name"].(string)
		inputVal := parseFloatInput(tc)

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
			continue
		}

		if result != expected {
			t.Errorf("FAIL: %s - %s returned %v, expected %v", name, predicate, result, expected)
		}
	}
}

func TestPhiMath(t *testing.T) {
	phi := Phi()
	if phi < 1.618 || phi > 1.619 {
		t.Errorf("phi: got %v, expected ~1.618", phi)
	}

	trinity := Trinity()
	if trinity < 2.999 || trinity > 3.001 {
		t.Errorf("trinity: got %v, expected 3.0", trinity)
	}
}

func TestConstants(t *testing.T) {
	if !Zero.IsZero() {
		t.Error("Zero constant should be zero")
	}

	one := One
	if !approxEqual(one.ToF32(), 1.0, 0.01) {
		t.Errorf("One constant: got %v", one.ToF32())
	}

	pInf := PInf
	if !pInf.IsInf() || pInf.IsNegative() {
		t.Error("PInf should be positive infinity")
	}

	nInf := NInf
	if !nInf.IsInf() || !nInf.IsNegative() {
		t.Error("NInf should be negative infinity")
	}

	nan := NaN
	if !nan.IsNaN() {
		t.Error("NaN should be NaN")
	}
}

func BenchmarkFromF32(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = FromF32(float32(i))
	}
}

func BenchmarkAdd(b *testing.B) {
	a := FromF32(1.5)
	c := FromF32(2.5)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = a.Add(c)
	}
}

func BenchmarkMul(b *testing.B) {
	a := FromF32(2.5)
	c := FromF32(4.0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = a.Mul(c)
	}
}

func BenchmarkPhiQuantize(b *testing.B) {
	weights := []float32{1.0, 1.5, 2.0, 2.5, 3.0}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = PhiQuantize(weights[i%len(weights)])
	}
}
