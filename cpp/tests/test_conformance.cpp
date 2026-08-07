/**
 * GoldenFloat — cross-language conformance: assert testdata/gf_conformance.csv.
 *
 * Reads the shared golden vectors and checks the C-ABI encodes each value to the exact
 * same raw bits the Python and Rust readers assert. CSV path is argv[1].
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#include "gf_ladder.h"
#include "gft.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

static uint64_t encode(const std::string& rung, float v) {
    if (rung == "gf8") return gf8_from_f32(v);
    if (rung == "gf12") return gf12_from_f32(v);
    if (rung == "gf20") return gf20_from_f32(v);
    if (rung == "gf24") return gf24_from_f32(v);
    if (rung == "gf32") return gf32_from_f32(v);
    if (rung == "gft8") return gft8_from_f32(v);
    if (rung == "gft16") return gft16_from_f32(v);
    if (rung == "gft32") return gft32_from_f32(v);
    std::fprintf(stderr, "unknown rung: %s\n", rung.c_str());
    std::exit(2);
}

int main(int argc, char** argv) {
    const char* path = (argc > 1) ? argv[1] : "testdata/gf_conformance.csv";
    std::ifstream in(path);
    if (!in) {
        std::fprintf(stderr, "cannot open %s\n", path);
        return 2;
    }

    std::string line;
    int n = 0;
    while (std::getline(in, line)) {
        if (line.empty() || line[0] == '#' || line.rfind("rung,", 0) == 0) continue;
        std::stringstream ss(line);
        std::string rung, value, bits;
        std::getline(ss, rung, ',');
        std::getline(ss, value, ',');
        std::getline(ss, bits, ',');
        float v = std::strtof(value.c_str(), nullptr);
        uint64_t expected = std::strtoull(bits.c_str(), nullptr, 16);
        uint64_t got = encode(rung, v);
        if (got != expected) {
            std::fprintf(stderr, "%s(%s): 0x%llx != 0x%llx\n", rung.c_str(), value.c_str(),
                         (unsigned long long)got, (unsigned long long)expected);
            return 1;
        }
        ++n;
    }
    if (n < 40) {
        std::fprintf(stderr, "expected the full vector set, got %d rows\n", n);
        return 1;
    }
    std::printf("Cross-language conformance (C++): ALL PASS (%d vectors)\n", n);
    return 0;
}
