//! main program
mod enums;
mod commands;

use eyre::Result;
use std::{env, path::PathBuf, process::ExitCode};
use clap::Parser;

pub use commands::{Command, Cli, AddSource};
pub use enums::{Outcome, Status};

use crate::{update_pin, check_pin, add_pin};
use crate::manifest::{Manifest, Pin};
use crate::sources::Source;


/// exit code of `check --exit-code` when an update is available
pub const EXIT_UPDATE_AVAILABLE: u8 = 3;
/// exit code of `update` when we failed to update one of the pins
pub const EXIT_PARTIAL_UPDATE: u8 = 1;

/// The program's data
pub struct App {
    /// export/config directory
    target_dir: PathBuf,

    /// manifest file
    manifest: Option<Manifest>,

    /// task struct, borrowed from CLI
    command : Command,
}


impl App {

    /// parse the CLI. can fail
    pub fn init() -> Result<Self> {
        let Cli {
            target_dir,
            manifest,
            command,
        } = Cli::parse();
        // be smart : pre-fix the paths
        let target_dir =  match target_dir {
            Some(x) => x,
            None => env::current_dir()?,
        };
        let manifest_path = match &manifest {
            Some(x) => x,
            None => &target_dir.clone(),
        };

        let new_app = Self {
           command : command.clone(),
           target_dir : target_dir.clone(),
           manifest : Some(match command {
               Command::Add {..}  => Manifest::load_or_new(manifest_path)?,
               _ => Manifest::load(manifest_path)?,
           }),
        };
        Ok(new_app)
    }

    fn try_get_manifest(&self) -> Result<&Manifest> {
       self.manifest.as_ref()
            .ok_or_else(|| eyre::eyre!("Manifest file not found"))
    }

    fn try_get_manifest_mut(&mut self) -> Result<&mut Manifest> {
       self.manifest.as_mut()
            .ok_or_else(|| eyre::eyre!("Manifest file not found"))
    }

    /// the sources to work on : the named one, or all
    /// TODO : simplify with 'run'
    fn targets(&self, name: Option<&str>) -> Vec<String> {
        match name {
            Some(name) => vec![name.to_owned()],
            None => {
                match self.try_get_manifest() {
                    Ok(x) => x.names(),
                    Err(_) => Vec::new()
                }
            },
        }
    }

    /// run command : check one source or all. true if everything is up to date.
    fn check(&self, name: Option<&str>) -> Result<Status> {
        let mut all_ok = true;
        let manifest = self.try_get_manifest()?;
        for name in self.targets(name) {
            match check_pin(manifest, &name)? {
                Status::UpToDate => println!("{name}: up to date"),
                Status::UpdateAvailable => {
                    println!("{name}: update available");
                    all_ok = false;
                }
            }
        }
        Ok(all_ok.into())
    }

    /// run command : update one source or all
    fn update(&mut self, name: Option<&str>) -> Result<bool> {
        let mut ok = true;
        // /!\ immutable borrow first !
        let targets: Vec<_> = self.targets(name);
        let manifest = self.try_get_manifest_mut()?;
        for name in &targets {
            match update_pin(manifest, &name) {
                Ok(Outcome::NoChange) => println!("{name}: no change"),
                Ok(Outcome::Updated(latest)) => println!("{name}: updated to {latest}"),
                Err(error) => {
                    eprintln!("{name}: {error:#}");
                    ok = false;
                }
            }
        }
        Ok(ok)
    }

    // run command : add a source ( and create manifest if not present)
    fn add(&mut self, name: Option<&str>, pin : impl Into<Pin>, output : Option<impl Into<PathBuf>>) -> Result<()> {
        let source = pin.into().clone();
        let name = name.unwrap_or(source.name());
        let output : PathBuf = output.map(Into::into).unwrap_or(self.target_dir.join("{name}.nix"));
        // mutable borrow happens last :
        let manifest = self.try_get_manifest_mut()?;
        add_pin(manifest, name, source.clone(), output)
    }

    // run command ()
    pub fn run(&mut self) -> Result<ExitCode> {
        match self.command {
            Command::Add { ref name, ref source, ref output } => {
                self.add(Some(&name.clone()), source.clone(), output.clone())?;
                Ok(ExitCode::SUCCESS)
            }
            Command::Check { ref name, ref exit_code } => {
                let current = self.check(name.as_deref())?;
                if (!current).into() && *exit_code {
                    Ok(ExitCode::from(EXIT_UPDATE_AVAILABLE))
                } else {
                    Ok(ExitCode::SUCCESS)
                }
            }
            Command::Update { ref name } => {
                let name = name.clone();
                if self.update(name.as_deref())? {
                    Ok(ExitCode::SUCCESS)
                } else {
                    Ok(ExitCode::from(EXIT_PARTIAL_UPDATE))
                }
            }
        }
    }
}
