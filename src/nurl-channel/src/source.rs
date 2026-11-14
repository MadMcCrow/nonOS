//! What a tracked source must provide.

/// A source we can follow.
pub trait Source {
    /// Identifier of the newest upstream version.
    /// A commit id for git, the resolved tarball url for a channel
    fn latest(&self) -> Result<String>;

    /// Arguments for `nurl` that fetch the version `latest`
    fn nurl_args(&self, latest: &str) -> Vec<String>;
}
