//! Follow a channel link.
//!
//! A channel url redirects to the real tarball. The version is in that url.
//!
use eyre::Result;
use serde::{Deserialize, Serialize};
use ureq::ResponseExt;

use crate::sources::Source;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Channel {
    /// channel link, e.g. https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz
    pub url: String,
}

impl Source for Channel {
    /// Follow the redirections and return the final url.
    fn latest(&self) -> Result<String> {
        let response = ureq::head(&self.url).call()?;
        Ok(response.get_uri().to_string())
    }

    /// `nurl` picks fetchzip for archives.
    /// We give it the resolved url, so the result is pinned.
    fn nurl_args(&self, latest: &str) -> Vec<String> {
        vec![latest.to_owned()]
    }

    /// default name of the channel is either
    fn name(&self) -> &str {
        if self.url.contains("channels.nixos.org/nixos") {
            return "nixpkgs";
        }
        let filename = self.url
            .split(['?', '#']).next().unwrap_or("") // remove queries
            .split('/').next_back().unwrap_or("");  // get last part
        // remove extensions
        filename.split('.').next().unwrap_or(filename)
    }
}
