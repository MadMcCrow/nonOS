// npins-sync
// Initialise or update an npins directory.


#[path = "./npins.rs"]
mod npins;
#[path = "./dir.rs"]
mod dir;


use std::process::{ExitCode};
use std::env;
use crate::npins::sync;
use crate::npins::Source;


const USAGE: &str = "Usage: npins-sync [-f] -d directory (-u url/branch | -c channel)";

struct Args {
    force: bool,
    path: String,
    source: Source,
}

// Parse the command line by hand. Errors are plain strings.
fn parse(mut it: impl Iterator<Item = String>) -> Result<Args, String> {
    let mut force = false;
    let mut path = None;
    let mut url = None;
    let mut channel = None;

    while let Some(arg) = it.next() {
        match arg.as_str() {
            "-f" => force = true,
            "-d" => path = Some(it.next().ok_or("-d needs a value")?),
            "-u" => url = Some(it.next().ok_or("-u needs a value")?),
            "-c" => channel = Some(it.next().ok_or("-c needs a value")?),
            other => return Err(format!("unknown argument {other:?}")),
        }
    }

    let path = path.ok_or("-d is required")?;
    let source = match (url, channel) {
        (Some(u), None) => Source::Git(u),
        (None, Some(c)) => Source::Channel(c),
        _ => return Err("exactly one of -u or -c is required".to_string()),
    };
    Ok(Args { force, path, source })
}



fn main() -> ExitCode {
    let args = match parse(env::args().skip(1)) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("Error: {e}\n{USAGE}");
            return ExitCode::from(2);
        }
    };
    match sync(&args.force, &args.path, &args.source) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{e}");
            ExitCode::FAILURE
        }
    }
}
