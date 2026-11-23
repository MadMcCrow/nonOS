//! the content of the manifest file

use std::collections::BTreeMap;
use serde::{Deserialize, Serialize};
use eyre::{Result, WrapErr, eyre};
use crate::manifest::Entry;

/// The manifest content
#[derive(Debug, Serialize, Deserialize)]
pub struct Content {
    /// each entry, by name
    /// MAYBE: define custom ser-de
    #[serde(default)]
    map: BTreeMap<String, Entry>,

    /// version to use
    /// TODO : not implemented yet
    #[serde(default)]
    schema: String,
}

impl Content {

    pub fn new() -> Self {
        Self {
            map : BTreeMap::new(),
            schema : String::from("0.") // TODO : have real schema matching
        }
    }

    pub fn import(text : String) -> Result<Self> {
        let content = serde_json::from_str(&text)
            .wrap_err_with(|| format!("error parsing {text}"))?;
        Ok(content)
    }

    /// all the source names
    pub fn keys(&self) -> Vec<String> {
        self.map.keys().cloned().collect()
    }

    pub fn remove(&mut self, name :&str) -> Result<Entry> {
        if !self.map.contains_key(name) {
            return Err(eyre!("entry {name} does not exist"));
        }
        self.map.remove(name)
            .ok_or_else(|| eyre::eyre!("could not remove entry {name}"))
    }

    pub fn insert(&mut self, name :&str, entry : Entry) -> Result<()> {
        if self.map.contains_key(name) {
            return Err(eyre!("entry {name} already exists"));
        }
        self.map.insert(name.to_owned(), entry);
        Ok(())
    }

    /// find an entry
    pub fn find(&self, name: &str) -> Result<&Entry> {
        self
            .map
            .get(name)
            .ok_or_else(|| eyre!("unknown source: {name}"))
    }

    /// we do not allow updating manually the entry. this is a helper
    pub fn find_mut(&mut self, name: &str) -> Result<&mut Entry> {
        self
            .map
            .get_mut(name)
            .ok_or_else(|| eyre!("unknown source: {name}"))
    }


}
