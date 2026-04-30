//! PhD Comparative Benchmark Suite for GoldenFloat
//!
//! This is the unified benchmark runner that executes all 4 benchmarks:
//! 1. Roundtrip MSE (encode → decode)
//! 2. φ-distance from IEEE fp32
//! 3. Sacred constants preservation
//! 4. Gradient norm distribution
//!
//! Usage: cargo run --bin phd-benchmarks

mod roundtrip_mse;
mod phi_distance;
mod sacred_constants;
mod gradient_norm;

use std::time::Instant;

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║     PhD Comparative Benchmark Suite for GoldenFloat          ║");
    println!("╚═══════════════════════════════════════════════════════════════╝\n");

    let total_start = Instant::now();

    // Benchmark 1: Roundtrip MSE
    println!("\n━━━ BENCHMARK 1 ━━━");
    let start = Instant::now();
    roundtrip_mse::run();
    println!("Completed in: {:?}", start.elapsed());

    // Benchmark 2: φ-distance
    println!("\n━━━ BENCHMARK 2 ━━━");
    let start = Instant::now();
    phi_distance::run();
    println!("Completed in: {:?}", start.elapsed());

    // Benchmark 3: Sacred constants
    println!("\n━━━ BENCHMARK 3 ━━━");
    let start = Instant::now();
    sacred_constants::run();
    println!("Completed in: {:?}", start.elapsed());

    // Benchmark 4: Gradient norms
    println!("\n━━━ BENCHMARK 4 ━━━");
    let start = Instant::now();
    gradient_norm::run();
    println!("Completed in: {:?}", start.elapsed());

    println!("\n━━━ SUMMARY ━━━");
    println!("All benchmarks completed in: {:?}", total_start.elapsed());
    println!("\nCSV files written to: data/");
    println!("  - bench1_roundtrip_mse.csv");
    println!("  - bench2_phi_distance.csv");
    println!("  - bench3_sacred_constants.csv");
    println!("  - bench4_gradient_norm.csv");
    println!("\nTotal data points: 48 (4 benchmarks × 12 formats)");
}
