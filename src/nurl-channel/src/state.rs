//! Store currently applied source to a json file


use std::fs; // for reading an writing
use serde::{Deserialize, Serialize};
use crate::{channel::Channel, git::Git, source::Source};
use crate::lib::write_atomic;

/// A source, as written in the configuration file.
#[derive(Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Pin {
    Git(Git),
    Channel(Channel),
}

/// we convert both types of entries to a PIN class for storage
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
#[derive(Serialize, Deserialize)]
pub struct Entry {
    #[serde(flatten)]
    source: Pin,
    /// what was fetched last
    #[serde(default)]
    last: Option<String>,
};
impl Entry {
    pub fn new(pin : &Pin) -> Self {
        Self {
            pin,
            None // default to "no last"
        }
    }
};

/// the state
pub struct State {
  file : Path,
  map  : std::collections::BTreeMap<String, Entry>,
};


impl State {
    /// CTR like function to create a state
    pub fn new(new_path: impl AsRef<Path>) -> Self {
        Self {
            file : new_path.as_path(),
            map : load(self, file),
        }
    }

    /// turns the JSON into a structured config
    pub fn load(mut &self) -> Result<()> {
        let text = fs::read_to_string(&self.path).wrap_err_with(|| format!("reading {}", self.file.display()))?;
        self.map = serde_json::from_str(&text).wrap_err_with(|| format!("parsing {}", self.file.display()));
        Ok()
    }

    /// opposite of load fn
    pub fn save(&self) -> Result<()> {
        match serde_json::to_string_pretty(self.map) {
            Ok(text) => write_atomic(&self.path, text)
            Err(error) => Err("failed to convert to json : {error}")
        }
    }

    /// search for a key and get a reference
    /// NOTE : enforces lifetime with <'a>
    fn find<'a>(&'a self, name : &'a String) -> Result<&'a Entry> {
        match self.map.get() {
               Some(x) =>  Ok(x),
               None => Err("unknown source: {name}"),
            }
        }

    /// be explicit for add
    fn add(& self, name : &String, pin : &Pin) -> Result<()> {
        match self.map.try_insert(name,  Entry.new(pin)) {
            Err(x) =>  Err("pin {name} already exists")
            _ => Ok()
        }
    }
    /// explicit update pin last
    fn update(& self, name : &String, update : &String) -> Result<()> {
        match self.map.get(name) {
            Some(x) =>  self.map.insert(name, Entry {x.pin , update})?;
            None => Err("Key doesn't exist");
        }
        Ok()
    }
};
