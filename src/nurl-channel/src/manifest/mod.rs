//! Store the sources and the currently applied version in a json file

mod pin;
mod entry;
mod content;

use crate::write_atomic;
use eyre::{Result, WrapErr, eyre};
use std::{
    fs,
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};

pub use pin::Pin;
pub use entry::Entry;
use content::Content;

/// default name of the manifest file
const MANIFEST_FILE : &str = "sources.json";

/// fix a manifest file path
fn file_path(in_path: impl Into<PathBuf>) -> PathBuf {
    let path = in_path.into();
    if path.is_dir() {
        path.join(MANIFEST_FILE)
    } else {
        path
    }
}

/// generate a string to describe time of update/notify
fn timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Error getting system time")
        .as_secs()
}

/// a representation of a file that contains Sources
pub struct Manifest {
    /// Where it is
    pub path: PathBuf,
    /// what it contains
    pub content: Content,
}
impl Manifest {
    // create new manifest
    pub fn new(in_path : impl Into<PathBuf>) -> Result<Self> {
        let path = file_path(in_path);
        fs::File::create_new(&path)?;
        Ok(Self {
                path : path,
                content : Content::new()
            })
    }

    pub fn load_or_new(in_path : impl Into<PathBuf>) -> Result<Self>
    {
        let pb = file_path(in_path);
        match Self::load(&pb) {
            Ok(x) => Ok(x), // pass
            Err(_) => Self::new(&pb),
        }
    }

    /// read from file, fails if file does not exist
    pub fn load(in_path : impl Into<PathBuf>) -> Result<Self> {
        let pb = file_path(in_path);
        if !pb.exists() {
            return Err(eyre!(
                "path {} is not valid",
                pb.display()
            ));
        }
        let text = fs::read_to_string(&pb)?;
        let manifest = Self {
            path: pb,
            content: Content::import(text)?,
        };
        Ok(manifest)
    }

    /// shortcut
    pub fn find(&self, name :&str) -> Result<&Entry> {
        self.content.find(name)
    }

    /// write the file
    pub fn save(&self) -> Result<()> {
        let text = serde_json::to_string_pretty(&self.content)?;
        write_atomic(&self.path, &text).wrap_err_with(|| format!("writing {}", self.path.display()))
    }

    /// newly fetched pin
    pub fn update(&mut self, name: &str, fetched: Option<String>) -> Result<()> {
        let entry = self.content.find_mut(name)?;
        entry.fetched = fetched;
        entry.last_updated = timestamp();
        self.save()?;
        Ok(())
    }

    /// make sure it has been notified
    pub fn notified(&mut self, name: &str) -> Result<()> {
        let entry = self.content.find_mut(name)?;
        entry.last_notified = timestamp();
        self.save()?;
        Ok(())
    }

    /// add a new source. fails if the name is taken
    pub fn add(&mut self, name: &str, entry: impl Into<Entry>) -> Result<()> {
        self.content.insert(name, entry.into())?;
        self.save()?;
        Ok(())
    }

    /// remove a source. fails if the name doesn't exist. return previous result
    pub fn remove(&mut self, name: &str) -> Result<()> {
        self.content.remove(name)?;
        self.save()?;
        Ok(())
    }

    /// get the list of entry names
    pub fn names(&self) -> Vec<String> {
        self.content.keys()
    }
}
