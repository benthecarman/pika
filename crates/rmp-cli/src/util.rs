use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

use crate::cli::CliError;

pub fn which(bin: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path) {
        let p = dir.join(bin);
        if p.is_file() {
            return Some(p);
        }
        #[cfg(windows)]
        {
            let p = dir.join(format!("{bin}.exe"));
            if p.is_file() {
                return Some(p);
            }
        }
    }
    None
}

pub fn run_capture(mut cmd: Command) -> Result<Output, CliError> {
    let out = cmd
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| CliError::operational(format!("failed to spawn process: {e}")))?;
    Ok(out)
}

pub fn discover_xcode_dev_dir() -> Result<PathBuf, CliError> {
    if let Ok(v) = std::env::var("DEVELOPER_DIR") {
        let p = PathBuf::from(v);
        if p.join("usr/bin/xcrun").exists() || p.join("usr/bin/simctl").exists() {
            return Ok(p);
        }
    }
    let apps = std::fs::read_dir("/Applications")
        .map_err(|e| CliError::operational(format!("failed to read /Applications: {e}")))?;
    let mut candidates: Vec<PathBuf> = vec![];
    for ent in apps.flatten() {
        let name = ent.file_name();
        let name = name.to_string_lossy();
        if !name.starts_with("Xcode") || !name.ends_with(".app") {
            continue;
        }
        let dev = ent.path().join("Contents/Developer");
        if dev.is_dir() {
            candidates.push(dev);
        }
    }
    candidates.sort();
    candidates
        .pop()
        .ok_or_else(|| CliError::operational("Xcode not found under /Applications"))
}

// (reserved) write_file_atomic: will be useful once `rmp init` lands.
