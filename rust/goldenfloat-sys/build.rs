//! Build script for goldenfloat-sys
//!
//! This script searches for the libgoldenfloat shared library and prints
//! cargo links to link against it.

fn main() {
    // Search for library in various locations
    let lib_dir = find_library_dir();
    
    if let Some(dir) = lib_dir {
        println!("cargo:rustc-link-search={}", dir);
        println!("cargo:rustc-link-lib=goldenfloat");
        println!("cargo:rerun-if-changed={}", dir.display());
    } else {
        println!("cargo:warning=libgoldenfloat not found. Build with 'zig build shared' in zig-golden-float root.");
        println!("cargo:warning=Set GOLDENFLOAT_LIB_DIR environment variable to specify library location.");
    }
}

fn find_library_dir() -> Option<std::path::PathBuf> {
    use std::path::{Path, PathBuf};
    
    // 1. Check environment variable
    if let Ok(dir) = std::env::var("GOLDENFLOAT_LIB_DIR") {
        let path = PathBuf::from(dir);
        if path.exists() {
            return Some(path);
        }
    }
    
    // 2. Check zig-out/lib relative to manifest
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").ok()?;
    let mut zig_out = PathBuf::from(manifest_dir);
    zig_out.push("../../zig-out/lib");
    if zig_out.exists() {
        return Some(zig_out);
    }
    
    // 3. Check system library paths
    for &dir in &["/usr/local/lib", "/usr/lib"] {
        let path = PathBuf::from(dir);
        if path.join("libgoldenfloat.dylib").exists() 
            || path.join("libgoldenfloat.so").exists() 
            || path.join("goldenfloat.dll").exists() {
            return Some(path.into());
        }
    }
    
    None
}
