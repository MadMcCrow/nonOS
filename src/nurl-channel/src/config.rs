//! Immutable config
//!  initialized at start with the arguments or with env-vars

use std::{path::PathBuf, sync::OnceLock};

use clap::{Parser, Subcommand};
use eyre::{Result, eyre};

use crate::{channel::Channel, git::Git, state::Pin};

#[derive(Parser)]
#[command(version, about)]
pub struct Cli {
    /// configuration directory
    #[arg(short, long, env = "NURL_CHANNEL_DIR")]
    pub dir: PathBuf,

    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    /// add a new source (run `update` to fetch it)
    Add {
        /// name of the source, used for the `<name>.nix` file
        name: String,
        #[command(subcommand)]
        source: AddSource,
    },
    /// show which sources have a new version
    Check {
        /// only this source
        name: Option<String>,
        /// exit with code 3 when an update is available
        #[arg(long)]
        exit_code: bool,
    },
    /// fetch new versions and write the `<name>.nix` files
    Update {
        /// only this source
        name: Option<String>,
    },
}

/// The kind of source to add.
#[derive(Subcommand)]
pub enum AddSource {
    /// follow a channel link, e.g. https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz
    Channel {
        /// channel link
        url: String,
    },
    /// follow a branch of a git repository
    Git {
        /// repository url
        url: String,
        /// branch to follow
        branch: String,
    },
}

impl From<AddSource> for Pin {
    fn from(source: AddSource) -> Self {
        match source {
            AddSource::Channel { url } => Pin::Channel(Channel { url }),
            AddSource::Git { url, branch } => Pin::Git(Git { url, branch }),
        }
    }
}

/// What the rest of the program needs to know.
pub struct Config {
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
