//! nurl-channel : follow sources, and write the nurl fetcher file for each.

use std::process::ExitCode;

use clap::Parser;
use eyre::Result;
use nurl_channel::config::{Cli, Command, Config};

/// returns true when command succeeded.
fn run() -> Result<bool> {
    let Cli {
        dir,
        notify,
        command,
    } = Cli::parse();
    match command {
        Command::Check { name } => {
            Config::init(Config { notify, dir })?;
            nurl_channel::check(name.as_deref())
        }
        Command::Update { name, no_notify } => {
            Config::init(Config {
                notify: notify && !no_notify,
                dir,
            })?;
            nurl_channel::update(name.as_deref())
        }
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
