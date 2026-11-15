//! Immutable config
//!  initialized at start with the arguments or with env-vars

use std::{path::PathBuf, sync::OnceLock};

use clap::{Parser, Subcommand};
use eyre::{Result, eyre};

#[derive(Parser)]
#[command(version, about)]
pub struct Cli {
    /// configuration directory
    #[arg(short, long, env = "NURL_CHANNEL_DIR")]
    pub dir: PathBuf,

    /// Whether to notify through DBUS or not
    #[arg(short, long, env = "NURL_CHANNEL_NOTIFY")]
    pub notify: bool,

    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    /// show which sources have a new version
    Check {
        /// only this source
        name: Option<String>,
    },
    /// fetch new versions and write the `<name>.nix` files
    Update {
        /// only this source
        name: Option<String>,
        /// do not send a desktop notification
        #[arg(long)]
        no_notify: bool,
    },
}

/// What the rest of the program needs to know.
pub struct Config {
    pub notify: bool,
    pub dir: PathBuf,
}

// a singleton
static CONFIG: OnceLock<Config> = OnceLock::new();

impl Config {
    /// set the config. fails if already set.
    pub fn init(config: Config) -> Result<()> {
        CONFIG
            .set(config)
            .map_err(|_| eyre!("config already initialized"))
    }

    /// get the config. panics if `init` was not called.
    pub fn get() -> &'static Config {
        CONFIG.get().expect("Config not initialized")
    }
}
