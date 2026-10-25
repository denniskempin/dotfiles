//! Load the RON grammar and compile it.

use crate::model::{compile, BindingsFile, Compiled, TargetsFile};
use std::fs;
use std::path::Path;

pub fn load_dir(dir: &Path) -> Result<Compiled, String> {
    let bindings = read_ron::<BindingsFile>(&dir.join("bindings.ron"))?;
    let targets = read_ron::<TargetsFile>(&dir.join("targets.ron"))?;
    Ok(compile(&bindings, &targets))
}

fn read_ron<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T, String> {
    let text = fs::read_to_string(path).map_err(|err| format!("{}: {err}", path.display()))?;
    // Optional fields are written as `"focus"` rather than `Some("focus")`.
    let options =
        ron::Options::default().with_default_extension(ron::extensions::Extensions::IMPLICIT_SOME);
    options
        .from_str(&text)
        .map_err(|err| format!("{}: {err}", path.display()))
}

pub fn repo_config_dir() -> std::path::PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../configs/keyagent")
}
