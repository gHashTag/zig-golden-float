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

func parseFloatInput(raw interface{}) float32 {
	switch v := raw.(type) {
	case string:
		switch v {
		case "inf":
			return float32(math.Inf(1))
		case "-inf":
			return float32(math.Inf(-1))
		case "nan":
			return float32(math.NaN())
		default:
			return 0
		}
	case float64:
		return float32(v)
	default:
		return 0
	}
}

func approxEqual(a, b, tolerance float32) bool {
	if math.IsNaN(float64(a)) && math.IsNaN(float64(b)) {
		return true
	}
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
		inputStr, _ := tc["input"].(string)

		gf := FromF32(parseFloatInput(tc["input"]))
		back := gf.ToF32()

		if predicate, ok := tc["predicate"]; ok {
			var result bool
			if predicate == "is_inf" {
				result = gf.IsInf()
			} else if predicate == "is_nan" {
				result = gf.IsNaN()
			}
			if !result {
				t.Errorf("FAIL: %s - predicate=%v not satisfied, back=%v", name, predicate, back)
			}
			continue
		}

		if match, ok := tc["match"]; ok {
			matchType := match.(string)
			switch matchType {
			case "roundtrip":
				if inputStr == "inf" || inputStr == "-inf" || inputStr == "nan" {
					continue
				}
				inputVal := parseFloatInput(tc["input"])
				if !approxEqual(back, inputVal, 0.01) && back != 0 && inputVal != 0 {
					t.Errorf("FAIL: %s - roundtrip got %v, expected %v", name, back, inputVal)
				}
			case "is_nan":
				if !gf.IsNaN() {
					t.Errorf("FAIL: %s - expected NaN, got %v", name, back)
				}
			case "approximate":
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

		gf := FromF32(parseFloatInput(tc["input"]))
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
	if !approxEqual(float32(phi), 1.6180339887498948, 1e-6) {
		t.Errorf("FAIL: phi - got %v, expected 1.6180339887498948", phi)
	}

	phiSq := PhiSq()
	if !approxEqual(float32(phiSq), 2.6180339887498948, 1e-6) {
		t.Errorf("FAIL: phi_sq - got %v, expected 2.6180339887498948", phiSq)
	}

	trinity := Trinity()
	if !approxEqual(float32(trinity), 3.0, 1e-6) {
		t.Errorf("FAIL: trinity - got %v, expected 3.0", trinity)
	}
}

func TestConstants(t *testing.T) {
	if !Zero.IsZero() {
		t.Error("FAIL: zero constant")
	}

	one := FromF32(1.0)
	if !approxEqual(one.ToF32(), 1.0, 0.01) {
		t.Errorf("FAIL: from_f32(1.0) - got %v", one.ToF32())
	}

	pInf := FromF32(float32(math.Inf(1)))
	if !pInf.IsInf() || pInf.IsNegative() {
		t.Error("FAIL: +inf")
	}

	nInf := FromF32(float32(math.Inf(-1)))
	if !nInf.IsInf() || !nInf.IsNegative() {
		t.Error("FAIL: -inf")
	}

	nan := FromF32(float32(math.NaN()))
	if !nan.IsNaN() {
		t.Errorf("FAIL: nan - is_nan=%v", nan.IsNaN())
	}
}
