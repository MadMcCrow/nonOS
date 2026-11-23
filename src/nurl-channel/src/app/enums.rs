//! result of different commands

use std::ops::Not;

/// The status that you check
/// be more verbose about the meaning of output
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    UpToDate,
    UpdateAvailable,
}
impl Into<bool> for Status {
    fn into(self) -> bool {
        match self {
            Status::UpToDate => true,
            Status::UpdateAvailable => false
        }
    }
}
impl From<bool> for Status {
    fn from(value : bool) -> Self {
        match value {
            true => Status::UpToDate ,
            false => Status::UpdateAvailable
        }
    }
}
impl Not for Status {
    type Output = Self;
    fn not(self) -> Self {
        let as_bool : bool = self.into();
        (!as_bool).into()
    }
}

/// What append when you update
/// more verbose that a simple bool
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome {
    NoChange,
    /// carries the new version
    Updated(String),
}
