// GoldenFloat Rust Wrapper
//
// Provides FFI bindings to Zig-compiled golden-float binary
// Downloads the appropriate binary from GitHub releases

use std::process::Command;

pub const VERSION: &str = "1.0.0";
pub const GITHUB_RELEASES: &str = "https://github.com/gHashTag/zig-golden-float/releases/download";

/// Get binary path for current platform
pub fn get_binary_path() -> std::path::PathBuf {
    let bin_name = "golden-float";
    let mut path = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    path.push_str(".golden-float");
    path.push_str(bin_name);

    #[cfg(target_os = "windows")]
    {
        path.push_str(".exe");
    }

    std::path::PathBuf::from(path)
}

/// Launch golden-float binary
pub fn run_golden_float(args: &[&str]) -> std::process::Child {
    let binary = get_binary_path();

    Command::new(&binary)
        .args(args)
        .spawn()
        .expect("Failed to spawn golden-float binary")
}

fn main() {
    println!("GoldenFloat v{}", VERSION);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_binary_path() {
        let path = get_binary_path();
        assert!(path.to_str().unwrap().contains("golden-float"));
    }
}
