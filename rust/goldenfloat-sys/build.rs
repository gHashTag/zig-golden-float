//! build.rs — Find and link libgoldenfloat
//!
//! This build script searches for libgoldenfloat in several locations:
//! 1. `zig-out/lib/` relative to the workspace root (if built via `zig build shared`)
//! 2. System library paths (if installed globally)
//! 3. Environment variable `GOLDENFLOAT_LIB_DIR`

use std::env;
use std::path::PathBuf;

fn main() {
    // Only link when not building docs
    if env::var("CARGO_DOC_RS").is_ok() {
        return;
    }

    let lib_name = "goldenfloat";

    // Try to find the library in zig-out/lib (relative to workspace)
    let workspace_root = workspace_root();
    let zig_out_lib = workspace_root.join("zig-out/lib");

    if zig_out_lib.exists() {
        println!("cargo:rustc-link-search={}", zig_out_lib.display());
        println!("cargo:rustc-link-lib=dylib={}", lib_name);
        println!("cargo:rerun-if-changed={}", zig_out_lib.display());

        // Also add the include path for users who need it
        let zig_out_include = workspace_root.join("zig-out/include");
        if zig_out_include.exists() {
            println!("cargo:include={}", zig_out_include.display());
        }
        return;
    }

    // Try environment variable
    if let Ok(lib_dir) = env::var("GOLDENFLOAT_LIB_DIR") {
        println!("cargo:rustc-link-search={}", lib_dir);
        println!("cargo:rustc-link-lib=dylib={}", lib_name);
        return;
    }

    // Try system library (may be installed via package manager)
    // This is a fallback; users should build via `zig build shared`
    println!("cargo:rustc-link-lib=dylib={}", lib_name);
    println!("cargo:warning=libgoldenfloat not found in zig-out/lib");
    println!("cargo:warning=Run 'zig build shared' from the workspace root first");

    // On macOS, also check Homebrew
    #[cfg(target_os = "macos")]
    {
        let homebrew_lib = PathBuf::from("/usr/local/lib");
        if homebrew_lib.exists() {
            println!("cargo:rustc-link-search={}", homebrew_lib.display());
        }
    }
}

/// Find the workspace root by searching for `build.zig`
fn workspace_root() -> PathBuf {
    let path = env::var("CARGO_MANIFEST_DIR").unwrap();
    let mut current = PathBuf::from(&path);

    loop {
        if current.join("build.zig").exists() {
            return current;
        }

        match current.parent() {
            Some(parent) => {
                current = parent.to_path_buf();
            }
            None => {
                // Fallback to manifest directory
                return PathBuf::from(path);
            }
        }
    }
}
