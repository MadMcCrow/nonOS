//! Store the sources and the currently applied version in a json file

use std::{collections::BTreeMap, fs, path::PathBuf};

use eyre::{Result, WrapErr, eyre};
use serde::{Deserialize, Serialize};

use crate::{channel::Channel, git::Git, source::Source, write_atomic};

/// A source, as written in the state file.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Pin {
    Git(Git),
    Channel(Channel),
}

/// both kinds of pins are handled the same way
impl Source for Pin {
    fn latest(&self) -> Result<String> {
        match self {
            Self::Git(s) => s.latest(),
            Self::Channel(s) => s.latest(),
        }
    }
    fn nurl_args(&self, latest: &str) -> Vec<String> {
        match self {
            Self::Git(s) => s.nurl_args(latest),
            Self::Channel(s) => s.nurl_args(latest),
        }
    }
}

/// One entry of the state file.
#[derive(Debug, Serialize, Deserialize)]
pub struct Entry {
    #[serde(flatten)]
    pub source: Pin,
    /// what was fetched last
    #[serde(default)]
    pub last: Option<String>,
}

impl Entry {
    pub fn new(source: Pin) -> Self {
        Self { source, last: None }
    }
}

/// the state
pub struct State {
    path: PathBuf,
    map: BTreeMap<String, Entry>,
}

impl State {
    /// read the state file
    pub fn load(path: impl Into<PathBuf>) -> Result<Self> {
        let path = path.into();
        let text = fs::read_to_string(&path)
            .wrap_err_with(|| format!("reading {}", path.display()))?;
        let map = serde_json::from_str(&text)
            .wrap_err_with(|| format!("parsing {}", path.display()))?;
        Ok(Self { path, map })
    }

    /// read the state file, or start empty if it does not exist
    pub fn load_or_default(path: impl Into<PathBuf>) -> Result<Self> {
        let path = path.into();
        if path.exists() {
            Self::load(path)
        } else {
            Ok(Self {
                path,
                map: BTreeMap::new(),
            })
        }
    }

    /// write the state file
    pub fn save(&self) -> Result<()> {
        let text = serde_json::to_string_pretty(&self.map)?;
        write_atomic(&self.path, &text)
            .wrap_err_with(|| format!("writing {}", self.path.display()))
    }

    /// all the source names
    pub fn names(&self) -> Vec<String> {
        self.map.keys().cloned().collect()
    }

    pub fn find(&self, name: &str) -> Result<&Entry> {
        self.map
            .get(name)
            .ok_or_else(|| eyre!("unknown source: {name}"))
    }

    pub fn find_mut(&mut self, name: &str) -> Result<&mut Entry> {
        self.map
            .get_mut(name)
            .ok_or_else(|| eyre!("unknown source: {name}"))
    }

    /// add a new source. fails if the name is taken.
    pub fn add(&mut self, name: &str, source: Pin) -> Result<()> {
        if self.map.contains_key(name) {
            return Err(eyre!("source {name} already exists"));
        }
        self.map.insert(name.to_owned(), Entry::new(source));
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn channel() -> Pin {
        Pin::Channel(Channel {
            url: "https://example.org/nixexprs.tar.xz".into(),
        })
    }

    #[test]
    fn parses_hand_written_file() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("state.json");
        std::fs::write(
            &path,
            r#"{
              "a": {"kind": "channel", "url": "https://example.org/x.tar.xz"},
              "b": {"kind": "git", "url": "https://example.org/r.git", "branch": "main", "last": "abc"}
            }"#,
        )
        .unwrap();
        let state = State::load(&path).unwrap();
        assert_eq!(state.names(), ["a", "b"]);
        assert_eq!(state.find("a").unwrap().last, None);
        assert_eq!(state.find("b").unwrap().last.as_deref(), Some("abc"));
    }

    #[test]
    fn save_and_load_roundtrip() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("state.json");
        let mut state = State::load_or_default(&path).unwrap();
        state.add("a", channel()).unwrap();
        state.find_mut("a").unwrap().last = Some("v1".into());
        state.save().unwrap();
        let again = State::load(&path).unwrap();
        assert_eq!(again.find("a").unwrap().last.as_deref(), Some("v1"));
    }

    #[test]
    fn add_twice_fails() {
        let dir = tempfile::tempdir().unwrap();
        let mut state = State::load_or_default(dir.path().join("state.json")).unwrap();
        state.add("a", channel()).unwrap();
        assert!(state.add("a", channel()).is_err());
    }

    #[test]
    fn unknown_source_fails() {
        let dir = tempfile::tempdir().unwrap();
        let state = State::load_or_default(dir.path().join("state.json")).unwrap();
        assert!(state.find("nope").is_err());
    }

    #[test]
    fn missing_file_is_an_error_for_load() {
        let dir = tempfile::tempdir().unwrap();
        assert!(State::load(dir.path().join("state.json")).is_err());
    }
}
