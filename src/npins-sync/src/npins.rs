// npins-sync/npins.rs
// Initialise or update an npins directory.
//
use std::process::{Command};
use crate::dir::{clear_dir, is_empty};

pub enum Source {
    Channel(String),
    Git(String), // "url/branch"
}

// Set at build time by the Nix derivation (env.NPINS_BIN)
// Fallback: PATH lookup when built by plain cargo
const NPINS: &str = match option_env!("NPINS_BIN") {
    Some(path) => path,
    None => "npins",
};


// "https://host/repo.git/branch" -> ("https://host/repo.git", "branch")
fn split_url(source: &str) -> Result<(&str, &str), String> {
    match source.rsplit_once('/') {
        Some((url, branch)) if !url.is_empty() && !branch.is_empty() => Ok((url, branch)),
        _ => Err(format!("expected url/branch, got {source:?}")),
    }
}

// Run npins. output goes straight to stdout/stderr.
fn run(args: &[&str]) -> Result<(), String> {
    let status = Command::new(NPINS)
        .args(args)
        .status()
        .map_err(|e| format!("cannot start {NPINS}: {e}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("npins {}: {status}", args.join(" ")))
    }
}



// bare npins directory and add nixpkgs
fn init_pins(path: &str, source: &Source) -> Result<(), String> {
    run(&["-d", path, "init", "--bare"])?;
    match source {
        Source::Channel(name) => run(&["-d", path, "add", "channel", name]),
        Source::Git(src) => {
            let (url, branch) = split_url(src)?;
            run(&["-d", path, "add", "git", url, "--branch", branch])
        }
    }
}

pub fn sync(force: &bool, path: &String, source: &Source) -> Result<(), String> {
    let empty = is_empty(&path)
        .map_err(|e| format!("directory {} cannot be read: {e}", path))?;
    if empty {
        init_pins(&path, &source)?;
    }

    if let Err(e) = run(&["-d", &path, "update"]) {
        eprintln!("{e}");
        if !force {
            return Err(format!(
                "npins update failed, check content of {}, or rerun with -f",
                path
            ));
        }
        clear_dir(&path).map_err(|e| format!("cannot clear {}: {e}", path))?;
        init_pins(&path, &source)?;
    }
    Ok(())
}
