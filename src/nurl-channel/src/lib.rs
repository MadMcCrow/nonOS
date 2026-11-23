//! main functions for operations

mod app;
mod manifest;
mod sources;

use std::{
    fs,
    path::{Path, PathBuf},
};

use clap::Parser;
use eyre::{Result, eyre};
use nurl::cli::Opts;

use crate::{
    app::{Outcome, Status},
    manifest::{Manifest, Entry, Pin},
    sources::Source,
};

// re-export the app
pub use crate::app::App;

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
pub fn fetcher_expression(args: &[String]) -> Result<String> {
    // create a chain from arguments
    let argv = std::iter::once("nurl".to_owned()).chain(args.iter().cloned());
    nurl::nurl(Opts::try_parse_from(argv)?)
}

/// Check that a pin has an update
pub fn check_pin(manifest: &Manifest, name: &str) -> Result<Status> {
    let entry = manifest.find(name)?;
    let latest = entry.source.latest()?;
    let output = &entry.output;
    if entry.fetched.as_deref() == Some(latest.as_str()) && output.exists() {
        Ok(Status::UpToDate)
    } else {
        Ok(Status::UpdateAvailable)
    }
}

/// update a single pin
pub fn update_pin(manifest: &mut Manifest, name: &str) -> Result<Outcome> {
    let entry = manifest.find(name)?;
    let latest = entry.source.latest()?;
    let output = &entry.output;
    // skip when nothing changed and the file exists
    if entry.fetched.as_deref() == Some(latest.as_str()) && output.exists() {
        return Ok(Outcome::NoChange);
    }

    // otherwise call nurl, write
    let expression = fetcher_expression(&entry.source.nurl_args(&latest))?;
    write_atomic(&output, &expression)?;

    // update the entry
    manifest.update(name, Some(latest.clone()))?;
    Ok(Outcome::Updated(latest))
}

/// add a new source to the state file. creates the directory and file if needed.
pub fn add_pin(manifest: &mut Manifest, name: &str, source: Pin, output : impl Into<PathBuf> ) -> Result<()> {
    // the name becomes a file name
    let valid = !name.is_empty()
        && name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'))
        && !name.starts_with('.');
    if !valid {
        return Err(eyre!(
            "invalid source name {name:?} : use letters, digits, '-', '_' and '.'"
        ));
    }
    manifest.add(name, Entry::new(source, Some(output.into())))?;
    println!("{name}: added");
    Ok(())
}
