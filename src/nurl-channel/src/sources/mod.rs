//! expose our submodules

// use our submodules
mod channel;
mod git;
mod source;
// expose our types direclty ( implicit "as")
pub use channel::Channel;
pub use git::Git;
pub use source::Source;
