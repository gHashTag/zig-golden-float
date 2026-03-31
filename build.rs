use reqwest::blocking::get;
use std::env;
use std::fs;
use std::path::PathBuf;

const GITHUB_RELEASES: &str = "https://github.com/gHashTag/zig-golden-float/releases/download";
const VERSION: &str = "v1.0.0";

fn main() {
    // Skip during docs.rs build
    if env::var("DOCS_RS").is_ok() {
        return;
    }

    let target = env::var("TARGET").unwrap();
    let os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    let arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap();

    let artifact = match (os.as_str(), arch.as_str()) {
        ("linux", "x86_64") => "golden-float-x86_64-linux.tar.gz",
        ("linux", "aarch64") => "golden-float-aarch64-linux.tar.gz",
        ("macos", "x86_64") => "golden-float-x86_64-macos.tar.gz",
        ("macos", "aarch64") => "golden-float-aarch64-macos.tar.gz",
        ("windows", "x86_64") => "golden-float-x86_64-windows.zip",
        _ => {
            eprintln!("Unsupported platform: {}-{}", os, arch);
            std::process::exit(1);
        }
    };

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let binary_name = if os == "windows" { "golden-float.exe" } else { "golden-float" };
    let binary_path = out_dir.join(&binary_name);

    if !binary_path.exists() {
        let url = format!("{}/{}/{}", GITHUB_RELEASES, VERSION, artifact);
        println!("Downloading golden-float binary from: {}", url);

        let response = get(&url).expect("Failed to download binary");
        let bytes = response.bytes().expect("Failed to read response");

        let archive_path = out_dir.join(artifact);
        fs::write(&archive_path, bytes).expect("Failed to write archive");

        // Extract
        if artifact.ends_with(".tar.gz") {
            let mut tar = flate2::read::GzDecoder::new(&bytes[..]);
            let mut archive = tar::Archive::new(&mut tar);
            archive.unpack(&out_dir).expect("Failed to extract tar.gz");
        } else if artifact.ends_with(".zip") {
            let mut archive = zip::ZipArchive::new(&bytes[..]).expect("Failed to open zip");
            archive.extract(&out_dir).expect("Failed to extract zip");
        }

        // Find and copy binary
        for entry in fs::read_dir(&out_dir).unwrap() {
            let entry = entry.unwrap();
            let path = entry.path();
            if path.is_file() {
                let fname = path.file_name().unwrap().to_string_lossy();
                if fname.contains("golden-float") || fname == "golden-float.exe" {
                    fs::copy(&path, &binary_path).expect("Failed to copy binary");
                    break;
                }
            }
        }
    }

    // Copy to bin dir
    let bin_dir = out_dir.join("bin");
    fs::create_dir_all(&bin_dir).unwrap();
    let dest = bin_dir.join(&binary_name);
    fs::copy(&binary_path, &dest).unwrap();

    // Tell cargo where to find the binary
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rustc-env=BINARY={}", dest.display());
}
