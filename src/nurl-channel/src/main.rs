//! nurl-channel : follow sources, and write the nurl fetcher file for each.

mod channel;
mod git;
mod origin;
mod cli;
mod state;

use std::{
    path::{Path, PathBuf},
    process::ExitCode,
};

use nurl::cli::Opts;
use crate::source::Source;


fn run() -> Result<bool> {
    let cli = Cli::parse();
    match cli.command {
        Command::Check { name } => check(&cli.dir, name),
        Command::Update { name, no_notify } => update(&cli.dir, name, no_notify),
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(error) => {
            eprintln!("error: {error:#}");
            ExitCode::FAILURE
        }
    }
}
