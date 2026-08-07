//! Cross-language conformance: assert the shared testdata/gf_conformance.csv.
//!
//! The same golden file is checked by the Python and C++ readers, so all three bindings
//! are pinned to one source of truth. (Integration tests are a separate std crate, so std
//! is available here even though the lib is #![no_std].)

use goldenfloat_sys::*;
use std::fs;

fn encode(rung: &str, v: f32) -> u64 {
    unsafe {
        match rung {
            "gf8" => gf8_from_f32(v).0 as u64,
            "gf12" => gf12_from_f32(v).0 as u64,
            "gf20" => gf20_from_f32(v).0 as u64,
            "gf24" => gf24_from_f32(v).0 as u64,
            "gf32" => gf32_from_f32(v).0 as u64,
            "gft8" => gft8_from_f32(v).0 as u64,
            "gft16" => gft16_from_f32(v).0 as u64,
            "gft32" => gft32_from_f32(v).0 as u64,
            _ => panic!("unknown rung {rung}"),
        }
    }
}

#[test]
fn conformance() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../testdata/gf_conformance.csv");
    let text = fs::read_to_string(path).expect("read gf_conformance.csv");
    let mut n = 0;
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with("rung,") {
            continue;
        }
        let mut it = line.split(',');
        let rung = it.next().unwrap();
        let value: f32 = it.next().unwrap().parse().unwrap();
        let bits = it.next().unwrap().trim_start_matches("0x");
        let expected = u64::from_str_radix(bits, 16).unwrap();
        assert_eq!(encode(rung, value), expected, "{rung}({value})");
        n += 1;
    }
    assert!(n >= 40, "expected the full vector set, got {n} rows");
}
