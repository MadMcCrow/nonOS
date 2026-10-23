// directory management
use std::fs;

pub fn is_empty(path: &str) -> std::io::Result<bool> {
    Ok(fs::read_dir(path)?.next().is_none())
}

// Remove everything inside the directory. Keep the directory.
pub fn clear_dir(path: &str) -> std::io::Result<()> {
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        if entry.file_type()?.is_dir() {
            fs::remove_dir_all(entry.path())?;
        } else {
            fs::remove_file(entry.path())?;
        }
    }
    Ok(())
}
