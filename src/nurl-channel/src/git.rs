//! Follow a branch of a git repository

use eyre::{Result, eyre};
use git2::{Direction, Remote};
use serde::{Deserialize, Serialize};

use crate::origin::Origin;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Git {
    /// repository url
    pub url: String,
    /// branch to follow
    pub branch: String,
}

impl Origin for Git {
    /// Same as `git ls-remote <url> refs/heads/<branch>`, without git.
    fn latest(&self) -> Result<String> {
        let mut remote = Remote::create_detached(self.url.as_str())?;
        remote.connect(Direction::Fetch)?;
        let wanted = format!("refs/heads/{}", self.branch);
        let rev = remote
            .list()?
            .iter()
            .find(|head| head.name() == wanted)
            .map(|head| head.oid().to_string())
            .ok_or_else(|| eyre!("branch {} not found in {}", self.branch, self.url))?;
        Ok(rev)
    }

    fn nurl_args(&self, latest: &str) -> Vec<String> {
        vec![self.url.clone(), latest.to_owned()]
    }
}
