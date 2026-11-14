//! Immutable config
//!  initialized at start with the arguments or with env-vars

use std::sync::OnceLock;
use crate::state::State;
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(version, about)]
struct Cli {
    /// configuration directory
    #[arg(short, long, env = "NURL_CHANNEL_DIR")]
    dir: PathBuf,

    /// Whether to notify through DBUS or not
    #[arg(short, long, env = "NURL_CHANNEL_NOTIFY")]
    notify: bool,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
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


pub struct Config {
    pub notify: bool,
    pub dir: impl AsRef<Path>,
}

// a singleton
static CONFIG: OnceLock<Config> = OnceLock::new();

impl Config {
    pub fn init(config: Config) {
        CONFIG
            .set(config)
            .expect("Config already initialized");
    }

    pub fn get() -> &'static Config {
        CONFIG
            .get()
            .expect("Config not initialized")
    }
}

pub fn init(config: Config) -> Result<(), Config> {
    CONFIG.set(config)
}
