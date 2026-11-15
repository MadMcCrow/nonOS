//! main functions for operations

// expose everything
// MAYBE : make some things private
pub mod channel;
pub mod config;
pub mod git;
pub mod notify;
pub mod source;
pub mod state;

use std::{
    fs,
    path::{Path, PathBuf},
};

use clap::Parser;
use eyre::Result;
use nurl::cli::Opts;

use crate::{config::Config, source::Source, state::State};

/// name of the state file, inside the config directory
const STATE_FILE: &str = "state.json";

/// be more verbose about the meaning of output
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    UpToDate,
    UpdateAvailable,
}

/// use Result, so no fail, but stay verbose
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome {
    NoChange,
    /// carries the new version
    Updated(String),
}

/// write in two steps : first write a temp file and then swap
pub fn write_atomic(path: &Path, text: &str) -> Result<()> {
    let mut tmp = path.as_os_str().to_owned();
    tmp.push(".tmp");
    let tmp = PathBuf::from(tmp);
    fs::write(&tmp, format!("{}\n", text.trim_end()))?;
    fs::rename(&tmp, path)?;
    Ok(())
}

/// run nurl as a library
fn fetcher_expression(args: &[String]) -> Result<String> {
    // create a chain from arguments
    let argv = std::iter::once("nurl".to_owned()).chain(args.iter().cloned());
    nurl::nurl(Opts::try_parse_from(argv)?)
}

/// get the state from the running config
fn get_state() -> Result<State> {
    State::load(Config::get().dir.join(STATE_FILE))
}

/// where the fetcher file of a source is written
fn output_path(name: &str) -> PathBuf {
    Config::get().dir.join(format!("{name}.nix"))
}

/// the sources to work on : the named one, or all
fn targets(state: &State, name: Option<&str>) -> Vec<String> {
    match name {
        Some(name) => vec![name.to_owned()],
        None => state.names(),
    }
}

/// Check that a pin has an update
pub fn check_one(state: &State, name: &str) -> Result<Status> {
    let entry = state.find(name)?;
    let latest = entry.source.latest()?;
    if entry.last.as_deref() == Some(latest.as_str()) && output_path(name).exists() {
        Ok(Status::UpToDate)
    } else {
        Ok(Status::UpdateAvailable)
    }
}

/// update a pin
pub fn update_one(state: &mut State, name: &str) -> Result<Outcome> {
    let output = output_path(name);
    let entry = state.find(name)?;
    let latest = entry.source.latest()?;

    // skip when nothing changed and the file exists
    if entry.last.as_deref() == Some(latest.as_str()) && output.exists() {
        return Ok(Outcome::NoChange);
    }

    // otherwise call nurl, write
    let expression = fetcher_expression(&entry.source.nurl_args(&latest))?;
    write_atomic(&output, &expression)?;

    // update the entry, and save immediately
    state.find_mut(name)?.last = Some(latest.clone());
    state.save()?;
    Ok(Outcome::Updated(latest))
}

/// check one source or all. true if everything is up to date.
pub fn check(name: Option<&str>) -> Result<bool> {
    let state = get_state()?;
    let mut current = true;
    for name in targets(&state, name) {
        match check_one(&state, &name)? {
            Status::UpToDate => println!("{name}: up to date"),
            Status::UpdateAvailable => {
                println!("{name}: update available");
                current = false;
            }
        }
    }
    Ok(current)
}

/// update one source or all. true if no source failed.
pub fn update(name: Option<&str>) -> Result<bool> {
    let mut state = get_state()?;
    let config = Config::get();
    let mut ok = true;
    for name in targets(&state, name) {
        match update_one(&mut state, &name) {
            Ok(Outcome::NoChange) => println!("{name}: no change"),
            Ok(Outcome::Updated(latest)) => {
                println!("{name}: updated to {latest}");
                if config.notify {
                    notify::notify(&name, &latest);
                }
            }
            Err(error) => {
                eprintln!("{name}: {error:#}");
                ok = false;
            }
        }
    }
    Ok(ok)
}
