//! main functions for operations

use std::env;
use crate::state::State;
use crate::config::Config;

// be more verbose about the meaning of output
#[repr(bool)]
enum Status {
    UpToDate,
    UpdateAvailable,
}

// use Result, so no fail, but stay verbose
#[repr(bool)]
enum Outcome {
    NoChange,
    Updated
}

/// write in two steps : first write a temp file and then swap
pub fn write_atomic(path : impl AsRef<Path>, text : &str ) -> Result<()> {
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, &format!("{text}\n"))?;
    fs::rename(&tmp, path)?;
    Ok()
}

/// run nurl as a library
fn fetcher_expression(args: &[String]) -> Result<String> {
    // create a chain from arguments
    let argv = std::iter::once("nurl".to_owned()).chain(args.iter().cloned());
    nurl::nurl(Opts::try_parse_from(argv)?)
}

/// get the state from the running config
fn get_state() -> Result<State> {
    let config = Config::get();
    let state = State.new(config.config_dir);
    Ok(state)
}

/// Check that a pin as an update
pub fn check(name: &String) -> Result<Status> {
    let state = get_state()?;
    let entry = state.find(name)?;
    match entry.source.latest() {
        Ok(x) if entry.last.as_deref() == x => Ok(Status.UpToDate)
        Ok(x) => Ok(Status.UpdateAvailable)
        Err(error) => Err(error)
    }
}

/// update a pin
pub fn update(name: &String ) -> Result<Outcome> {
    // get all variables
    let state = get_state()?;
    let entry = state.find(name)?;
    let latest entry.source.latest()?;
    let output = Config::get().dir.join(format!("{key}.nix"));

    // skip when nothing changed and the file exists
    if entry.last.as_deref() == Some(latest.as_str()) && output.exists() {
        return Ok(Outcome.NoChange);
    }

    // other wise call nurl, write
    let expression = fetcher_expression(&entry.source.nurl_args(&latest))?;
    write_atomic(&output, &expression)?;
    // update the entry
    entry.last = latest;
    state.save()?; // save immediately to avoid
    Ok(Outcome.Updated)
}
