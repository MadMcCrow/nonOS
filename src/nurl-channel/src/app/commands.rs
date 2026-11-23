//! the different apps commands

use clap::{Parser, Subcommand};
use std::{path::PathBuf};

#[derive(Parser)]
#[command(version, about)]
pub struct Cli {
    /// export directory
    #[arg(short = 'd', long, env = "NURL_CHANNEL_DIR", default_value=None)]
    pub target_dir: Option<PathBuf>,

    /// manifest, default to "manifest.json" inside the export directory
    #[arg(short = 'c', long, env = "NURL_CHANNEL_MANIFEST", default_value=None)]
    pub manifest: Option<PathBuf>,

    #[command(subcommand)]
    pub command: Command,
}

#[derive(Clone, Subcommand)]
pub enum Command {
    /// add a new source (run `update` to fetch it)
    Add {
        /// name of the source
        name: String,
        /// git, or tarfile channel
        #[command(subcommand)]
        source: AddSource,
        /// default to <name>.nix
        output: Option<PathBuf>,
    },
    /// show which sources have a new version
    Check {
        /// only this source
        name: Option<String>,
        /// exit with code 3 when an update is available
        #[arg(long)]
        exit_code: bool,
    },
    /// fetch new versions and update output
    Update {
        /// only this source
        name: Option<String>,
    },
}

/// The kind of source to add.
#[derive(Clone, Subcommand)]
pub enum AddSource {
    /// follow a channel link (tar file)
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

// defined as From<AddSource> for pin;
// impl Into<Pin> for AddSource;
