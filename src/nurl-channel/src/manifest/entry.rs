//! an entry in the manifest file

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use crate::manifest::Pin;

/// One entry of the sources file.
#[derive(Debug, Serialize, Deserialize)]
pub struct Entry {
    #[serde(flatten)]
    pub source: Pin,
    /// what was fetched last
    #[serde(default)]
    pub fetched: Option<String>,
    //
    #[serde(default)]
    pub last_updated: u64,
    //
    #[serde(default)]
    pub last_notified: u64,
    // where the file is saved
    #[serde(default)]
    pub output: PathBuf,
}

impl Entry {
    pub fn new(source : Pin, output : Option<PathBuf>) -> Self {
        Self {
            source : source,
            fetched : None,
            last_updated : 0, //UNIX_EPOCH -> 1/1/70 -> just like the nix store
            last_notified : 0,
            output : match output {
                Some(x) => x,
                None => PathBuf::from("{source.name()}.nix"),
            }
        }
    }
}
