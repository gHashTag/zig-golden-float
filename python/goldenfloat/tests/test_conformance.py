"""Cross-language conformance: every binding must reproduce testdata/gf_conformance.csv.

The .csv is the shared source of truth (generated from the C-ABI); this reader asserts the
Python FFI surface encodes each value to the exact same raw bits. The C++ and Rust readers
assert the same file, so all three are pinned to one golden set.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from goldenfloat._binding import _get_lib

# repo_root/python/goldenfloat/tests/test_conformance.py -> repo_root
_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
_CSV = os.path.join(_REPO_ROOT, "testdata", "gf_conformance.csv")


def _rows():
    with open(_CSV) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or line.startswith("rung,"):
                continue
            rung, value, bits = line.split(",")
            yield rung, float(value), int(bits, 16)


def test_conformance():
    lib = _get_lib()
    n = 0
    for rung, value, expected in _rows():
        got = getattr(lib, rung + "_from_f32")(value)
        assert got == expected, f"{rung}({value}): {got:#x} != {expected:#x}"
        n += 1
    assert n >= 40, f"expected the full vector set, got {n} rows"


if __name__ == "__main__":
    test_conformance()
    print("Cross-language conformance (python): ALL PASS")
