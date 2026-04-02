#!/bin/bash
# test_bindings.sh — Run all language binding tests
#
# MIT License — Copyright (c) 2026 Trinity Project
# Repository: https://github.com/gHashTag/zig-golden-float

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "========================================="
echo "GoldenFloat Multi-Language Bindings Tests"
echo "========================================="
echo ""

# Track failures
FAILURES=0

# Function to run and report test status
run_test() {
    local name="$1"
    local cmd="$2"

    echo "Running $name..."
    if eval "$cmd"; then
        echo "  PASS: $name"
    else
        echo "  FAIL: $name"
        FAILURES=$((FAILURES + 1))
    fi
    echo ""
}

# 1. Build shared library
echo "[1/6] Building shared library..."
if zig build shared 2>&1 | tee /tmp/zig-build.log; then
    echo "  OK: Library built successfully"
else
    echo "  FAIL: Library build failed"
    cat /tmp/zig-build.log
    FAILURES=$((FAILURES + 1))
fi
echo ""

# 2. Rust bindings
echo "[2/6] Testing Rust bindings..."
cd rust/goldenfloat-sys
if cargo test --quiet 2>&1 | tee /tmp/rust-test.log; then
    echo "  OK: Rust tests passed"
else
    echo "  FAIL: Rust tests failed"
    cat /tmp/rust-test.log
    FAILURES=$((FAILURES + 1))
fi
cd "$SCRIPT_DIR/.."
echo ""

# 3. Python bindings
echo "[3/6] Testing Python bindings..."
cd python
if python3 -m goldenfloat.tests.test_gf16 2>&1 | tee /tmp/python-test.log; then
    echo "  OK: Python tests passed"
else
    echo "  FAIL: Python tests failed"
    cat /tmp/python-test.log
    FAILURES=$((FAILURES + 1))
fi
cd "$SCRIPT_DIR/.."
echo ""

# 4. C++ bindings
echo "[4/6] Testing C++ bindings..."
cd scripts
mkdir -p build
if cmake -S ../cpp -B build -DCMAKE_BUILD_TYPE=Release 2>&1 | tee /tmp/cmake-config.log; then
    if cmake --build build --target test_gf16 2>&1 | tee /tmp/cpp-test.log; then
        echo "  OK: C++ tests passed"
    else
        echo "  FAIL: C++ tests failed"
        cat /tmp/cpp-test.log
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "  FAIL: CMake configuration failed"
    cat /tmp/cmake-config.log
    FAILURES=$((FAILURES + 1))
fi
cd "$SCRIPT_DIR/.."
echo ""

# 5. Go bindings
echo "[5/6] Testing Go bindings..."
cd go/goldenfloat
if go test -v ./... 2>&1 | tee /tmp/go-test.log; then
    echo "  OK: Go tests passed"
else
    echo "  FAIL: Go tests failed"
    cat /tmp/go-test.log
    FAILURES=$((FAILURES + 1))
fi
cd "$SCRIPT_DIR/.."
echo ""

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
if [ $FAILURES -eq 0 ]; then
    echo "All tests passed!"
    echo ""
    exit 0
else
    echo "$FAILURES test suite(s) failed!"
    echo ""
    exit 1
fi
