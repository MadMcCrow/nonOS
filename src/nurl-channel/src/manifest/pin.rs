//! How to write a Source in the manifest.

use eyre::Result;
use serde::{Deserialize, Serialize};

use crate::app::AddSource;
use crate::sources::{Channel, Git, Source};


/// A source, as written in the manifest.
/// allows to abstract the sources and de/serialize
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Pin {
    Git(Git),
    Channel(Channel),
}

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

    fn name(&self) -> &str {
        match self {
            Self::Git(s) => s.name(),
            Self::Channel(s) => s.name(),
        }
    }
}
impl From<AddSource> for Pin {
    fn from(source: AddSource) -> Self {
        match source {
            AddSource::Channel { url } => Pin::Channel(Channel { url }),
            AddSource::Git { url, branch } => Pin::Git(Git { url, branch }),
        }
    }
}
