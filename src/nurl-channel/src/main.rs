//! nurl-channel : follow sources, and write the nurl fetcher file for each.

use std::process::ExitCode;
use nurl_channel::App;

fn main() -> ExitCode {
    let mut app = App::init().expect("Failed to initialize app");
    match app.run() {
        Ok(code) => code,
        Err(error) => {
            eprintln!("error: {error:#}");
            ExitCode::FAILURE
        }
    }
}
