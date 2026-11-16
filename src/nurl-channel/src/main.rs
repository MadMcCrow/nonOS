//! nurl-channel : follow sources, and write the nurl fetcher file for each.

use std::process::ExitCode;

use clap::Parser;
use eyre::Result;
use nurl_channel::{
    EXIT_UPDATE_AVAILABLE,
    config::{Cli, Command, Config},
};

fn run() -> Result<ExitCode> {
    let Cli { dir, command } = Cli::parse();
    Config::init(Config { dir })?;
    match command {
        Command::Add { name, source } => {
            nurl_channel::add(&name, source.into())?;
            Ok(ExitCode::SUCCESS)
        }
        Command::Check { name, exit_code } => {
            let current = nurl_channel::check(name.as_deref())?;
            if !current && exit_code {
                Ok(ExitCode::from(EXIT_UPDATE_AVAILABLE))
            } else {
                Ok(ExitCode::SUCCESS)
            }
        }
        Command::Update { name } => {
            if nurl_channel::update(name.as_deref())? {
                Ok(ExitCode::SUCCESS)
            } else {
                Ok(ExitCode::FAILURE)
            }
        }
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => code,
        Err(error) => {
            eprintln!("error: {error:#}");
            ExitCode::FAILURE
        }
    }
}
