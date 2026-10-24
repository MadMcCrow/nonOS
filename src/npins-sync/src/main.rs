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
