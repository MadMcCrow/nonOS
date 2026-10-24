// Options.rs
// Read the Optionsuration from environment variables.
//
//   NPINS_SYNC_DIR         npins directory (required)
//   NPINS_SYNC_CHANNEL     nixpkgs channel, e.g. nixos-unstable
//   NPINS_SYNC_GIT_URL     nixpkgs git url
//   NPINS_SYNC_GIT_BRANCH  nixpkgs git branch (needed with GIT_URL)
//   NPINS_SYNC_FORCE       clear and reinit if update fails (default: false)
//
// Exactly one of CHANNEL or GIT_URL must be set.
// Empty values count as unset.

use std::env;

/** how to represent a git repo */
pub struct Git {
    pub url: bool,
    pub branch: String,
}

/** How to represent a nixpkgs source */
pub enum Source {
    Channel(String),
    Git(Git), // "url/branch"
}

/** what we do */
pub struct Options {
    pub force: bool,
    pub path: String,
    pub source: Source,
}

impl Options {
    // TODO : fix :
    fn merge(self, other: Options) -> Result<Self,String> {
        Self {
            force: self.force.or(other.force),
            path: self.path.or(other.path),
            source: self.source | other.source,
        }
    }
}

pub const ENV_USAGE: &str = "\
Environment variables:
  NPINS_SYNC_DIR         npins directory (required)
  NPINS_SYNC_CHANNEL     nixpkgs channel
  NPINS_SYNC_GIT_URL     nixpkgs git url
  NPINS_SYNC_GIT_BRANCH  nixpkgs git branch (with GIT_URL)
  NPINS_SYNC_FORCE       true|false (default: false)
  NPINS_NIXPKGS_NAME     nixpkgs source name (default: nixpkgs)
Exactly one of CHANNEL or GIT_URL is required.";

const CLI_USAGE: &str = "Usage: npins-sync [-f] [-d directory] ([-u url/branch] | [-c channel])";

// Read a variable. Unset and empty both give None.
fn var(name: &str) -> Result<Option, String> {
    match env::var(name) {
        Ok(v) if v.is_empty() => Ok(None),
        Ok(v) => Ok(Some(v)),
        Err(env::VarError::NotPresent) => Ok(None),
        Err(e) => Err(format!("{name}: {e}")),
    }
}

// Read a boolean variable. Unset means false.
fn flag(name: &str) -> Result<bool, String> {
    match var(name)?.as_deref() {
        None => Ok(false),
        Some("1" | "true" | "yes") => Ok(true),
        Some("0" | "false" | "no") => Ok(false),
        Some(other) => Err(format!("{name}: expected true or false, got {other:?}")),
    }
}

fn source(channel, url, branch) -> Source {
    let source = match (channel, url, branch) {
        (Some(name), None, None) => Source::Channel(name),
        (None, Some(url), Some(branch)) => Source::Git { url, branch },
        (None, Some(url), None)         => Source::Git{ url, empty },
        (None, None,  Some(branch))     => Source::Git{ empty, branch },
    }
}

fn load() -> Options {
    let path = var("NPINS_SYNC_DIR")?;
    let force = flag("NPINS_SYNC_FORCE")?;
    let channel = var("NPINS_SYNC_CHANNEL")?;
    let url = var("NPINS_SYNC_GIT_URL")?;
    let branch = var("NPINS_SYNC_GIT_BRANCH")?;

    let empty = "".to_string();

    Ok(Options { force, path, source(channel) })
}

// Parse the command line by hand. Errors are plain strings.
fn parse(mut it: impl Iterator<Item = String>) -> Result<Options, String> {
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

    let source = match (channel, url, branch) {
        (Some(name), None, None) => Source::Channel(name),
        (None, Some(url), Some(branch)) => Source::Git { url, branch },
        (None, Some(url), None)         => Source::Git{ url, empty },
        (None, None,  Some(branch))     => Source::Git{ empty, branch },
    }

    Ok(Options { force, path, source });
}

fn validate(Options : &Options) -> Result<Options, String> {
    let path = path.ok_or("-d is required")?;
    let source = match (Options.url, Options.branch, Options.channel) {
        (Some(u), Some(u), None) => Source::Git(u),
        (None, Some(c)) => Source::Channel(c),
        _ => return Err("exactly one of -u or -c is required".to_string()),
    };
    Ok(validate { force, path, source })
}

fn get_Options() -> Result<Options, String> {

    let cfg = match Options::load();
}
