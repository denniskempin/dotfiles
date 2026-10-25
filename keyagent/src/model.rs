//! Grammar tables and the actions they resolve to.
//!
//! Bindings and targets load from RON so a binding edit does not rebuild the
//! agent. `$` in a template stands for the key's argument.

use crate::keys::KeyMap;
use serde::Deserialize;
use std::collections::{BTreeMap, HashMap, HashSet};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Layer {
    Os,
    App,
}

impl Layer {
    pub fn parse(text: &str) -> Option<Self> {
        match text {
            "os" => Some(Layer::Os),
            "app" => Some(Layer::App),
            _ => None,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Layer::Os => "os",
            Layer::App => "app",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mod {
    Cmd,
    Alt,
    Ctrl,
    Shift,
}

impl Mod {
    pub fn parse(text: &str) -> Option<Self> {
        match text {
            "cmd" => Some(Mod::Cmd),
            "alt" => Some(Mod::Alt),
            "ctrl" => Some(Mod::Ctrl),
            "shift" => Some(Mod::Shift),
            _ => None,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Mod::Cmd => "cmd",
            Mod::Alt => "alt",
            Mod::Ctrl => "ctrl",
            Mod::Shift => "shift",
        }
    }

    /// AppleScript `using` clause, in the order the grammar lists modifiers.
    pub fn applescript(self) -> &'static str {
        match self {
            Mod::Cmd => "command down",
            Mod::Alt => "option down",
            Mod::Ctrl => "control down",
            Mod::Shift => "shift down",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Flags {
    pub cmd: bool,
    pub alt: bool,
    pub ctrl: bool,
    pub shift: bool,
    pub fn_key: bool,
}

impl Flags {
    pub fn empty() -> Self {
        Self {
            cmd: false,
            alt: false,
            ctrl: false,
            shift: false,
            fn_key: false,
        }
    }

    pub fn from_mods(mods: &[Mod]) -> Self {
        let mut flags = Self::empty();
        for m in mods {
            match m {
                Mod::Cmd => flags.cmd = true,
                Mod::Alt => flags.alt = true,
                Mod::Ctrl => flags.ctrl = true,
                Mod::Shift => flags.shift = true,
            }
        }
        flags
    }

    pub fn blocked(&self) -> bool {
        self.cmd || self.alt || self.ctrl
    }

    pub fn has_mod(&self, m: Mod) -> bool {
        match m {
            Mod::Cmd => self.cmd,
            Mod::Alt => self.alt,
            Mod::Ctrl => self.ctrl,
            Mod::Shift => self.shift,
        }
    }
}

/// A key the agent posts, or a System Events keystroke it asked for.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Stroke {
    pub mods: Vec<Mod>,
    pub key: String,
}

#[derive(Clone, Debug)]
pub enum Action {
    Stroke(Stroke),
    Seq(Vec<Stroke>),
    Menu(Vec<Vec<String>>),
    Aero(Vec<String>),
    Launch(String),
    Hotkey { mods: Vec<Mod>, key: String },
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub enum ActionSpec {
    Aero(Vec<String>),
    Stroke {
        mods: Vec<String>,
        key: String,
    },
    Seq(Vec<ActionSpec>),
    Menu(Vec<Vec<String>>),
    Launch(String),
    Hotkey {
        mods: Vec<String>,
        key: String,
    },
    ByArg(BTreeMap<String, ActionSpec>),
    Template(Box<ActionSpec>),
    Digit {
        nine: Box<ActionSpec>,
        other_mods: Vec<String>,
    },
    MenuDir {
        items: BTreeMap<String, String>,
        paths: Vec<Vec<String>>,
    },
}

fn subst(text: &str, arg: &str) -> String {
    if text == "$" {
        arg.to_string()
    } else {
        text.to_string()
    }
}

fn subst_spec(spec: &ActionSpec, arg: &str) -> ActionSpec {
    match spec {
        ActionSpec::Aero(args) => ActionSpec::Aero(args.iter().map(|s| subst(s, arg)).collect()),
        ActionSpec::Stroke { mods, key } => ActionSpec::Stroke {
            mods: mods.clone(),
            key: subst(key, arg),
        },
        ActionSpec::Seq(steps) => {
            ActionSpec::Seq(steps.iter().map(|step| subst_spec(step, arg)).collect())
        }
        ActionSpec::Menu(paths) => ActionSpec::Menu(
            paths
                .iter()
                .map(|path| path.iter().map(|s| subst(s, arg)).collect())
                .collect(),
        ),
        ActionSpec::Launch(bundle) => ActionSpec::Launch(subst(bundle, arg)),
        ActionSpec::Hotkey { mods, key } => ActionSpec::Hotkey {
            mods: mods.clone(),
            key: subst(key, arg),
        },
        ActionSpec::ByArg(map) => ActionSpec::ByArg(
            map.iter()
                .map(|(k, v)| (k.clone(), subst_spec(v, arg)))
                .collect(),
        ),
        ActionSpec::Template(inner) => ActionSpec::Template(Box::new(subst_spec(inner, arg))),
        ActionSpec::Digit { nine, other_mods } => ActionSpec::Digit {
            nine: Box::new(subst_spec(nine, arg)),
            other_mods: other_mods.clone(),
        },
        ActionSpec::MenuDir { items, paths } => ActionSpec::MenuDir {
            items: items.clone(),
            paths: paths
                .iter()
                .map(|path| path.iter().map(|s| subst(s, arg)).collect())
                .collect(),
        },
    }
}

fn parse_mods(mods: &[String], warnings: &mut Vec<String>) -> Vec<Mod> {
    mods.iter()
        .filter_map(|text| {
            Mod::parse(text).or_else(|| {
                warnings.push(format!("unknown modifier {text}"));
                None
            })
        })
        .collect()
}

pub fn resolve(spec: &ActionSpec, arg: &str, warnings: &mut Vec<String>) -> Option<Action> {
    match spec {
        ActionSpec::Aero(args) => Some(Action::Aero(args.clone())),
        ActionSpec::Stroke { mods, key } => Some(Action::Stroke(Stroke {
            mods: parse_mods(mods, warnings),
            key: key.clone(),
        })),
        ActionSpec::Seq(steps) => {
            let mut strokes = Vec::new();
            for step in steps {
                match resolve(step, arg, warnings) {
                    Some(Action::Stroke(stroke)) => strokes.push(stroke),
                    Some(_) => warnings.push("a sequence contains a non-stroke".to_string()),
                    None => warnings.push("a sequence step resolved to nothing".to_string()),
                }
            }
            Some(Action::Seq(strokes))
        }
        ActionSpec::Menu(paths) => Some(Action::Menu(paths.clone())),
        ActionSpec::Launch(bundle) => Some(Action::Launch(bundle.clone())),
        ActionSpec::Hotkey { mods, key } => Some(Action::Hotkey {
            mods: parse_mods(mods, warnings),
            key: key.clone(),
        }),
        ActionSpec::ByArg(map) => map.get(arg).and_then(|cell| resolve(cell, arg, warnings)),
        ActionSpec::Template(inner) => resolve(&subst_spec(inner, arg), arg, warnings),
        ActionSpec::Digit { nine, other_mods } => {
            if arg == "9" {
                resolve(nine, arg, warnings)
            } else {
                Some(Action::Stroke(Stroke {
                    mods: parse_mods(other_mods, warnings),
                    key: arg.to_string(),
                }))
            }
        }
        ActionSpec::MenuDir { items, paths } => {
            let item = items.get(arg)?;
            let paths = paths
                .iter()
                .map(|path| {
                    path.iter()
                        .map(|part| {
                            if part == "$" {
                                item.clone()
                            } else {
                                part.clone()
                            }
                        })
                        .collect()
                })
                .collect();
            Some(Action::Menu(paths))
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Row {
    #[serde(default)]
    pub keys: Vec<String>,
    #[serde(default)]
    pub key_args: BTreeMap<String, String>,
    #[serde(default)]
    pub shift: bool,
    #[serde(default)]
    pub layer: Option<String>,
    #[serde(default)]
    pub verb: Option<String>,
    #[serde(default)]
    pub chord: Option<String>,
    #[serde(default)]
    pub run: Option<String>,
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub hint: Option<String>,
}

impl Row {
    pub fn pairs(&self) -> Vec<(String, String)> {
        if !self.key_args.is_empty() {
            self.key_args
                .iter()
                .map(|(key, arg)| (key.clone(), arg.clone()))
                .collect()
        } else {
            self.keys
                .iter()
                .map(|key| (key.clone(), key.clone()))
                .collect()
        }
    }

    pub fn on_layer(&self, layer: Layer) -> bool {
        match &self.layer {
            None => true,
            Some(text) => Layer::parse(text) == Some(layer),
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Chord {
    pub title: String,
    pub rows: Vec<Row>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BindingsFile {
    pub titles: BTreeMap<String, String>,
    pub columns: Vec<Vec<Row>>,
    pub chords: BTreeMap<String, Chord>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TargetsFile {
    pub system: BTreeMap<String, ActionSpec>,
    pub apps: BTreeMap<String, BTreeMap<String, ActionSpec>>,
}

#[derive(Clone, Debug)]
pub struct Binding {
    pub arg: String,
    pub verb: Option<String>,
    pub chord: Option<String>,
    pub run: Option<String>,
}

#[derive(Clone, Debug)]
#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
pub struct OverlayRow {
    pub label: String,
    pub hint: String,
}

#[derive(Clone, Debug)]
pub struct CompiledChord {
    pub title: String,
    pub rows: Vec<Row>,
    pub index: HashMap<Layer, HashMap<String, Binding>>,
}

#[derive(Clone, Debug)]
pub struct Compiled {
    pub titles: HashMap<Layer, String>,
    pub columns: Vec<Vec<Row>>,
    pub layer_index: HashMap<Layer, HashMap<bool, HashMap<String, Binding>>>,
    pub chords: HashMap<String, CompiledChord>,
    pub system: BTreeMap<String, ActionSpec>,
    pub apps: BTreeMap<String, BTreeMap<String, ActionSpec>>,
    pub warnings: Vec<String>,
}

const COMMANDS: &[&str] = &["forwardDelete"];

pub fn compile(bindings: &BindingsFile, targets: &TargetsFile) -> Compiled {
    let mut warnings = Vec::new();
    let mut seen = HashSet::new();
    let mut warn = |message: String| {
        if seen.insert(message.clone()) {
            warnings.push(message);
        }
    };

    let mut titles = HashMap::new();
    for (name, title) in &bindings.titles {
        match Layer::parse(name) {
            Some(layer) => {
                titles.insert(layer, title.clone());
            }
            None => warn(format!("unknown layer {name}")),
        }
    }
    for layer in [Layer::Os, Layer::App] {
        titles.entry(layer).or_default();
    }

    let mut layer_rows = Vec::new();
    for column in &bindings.columns {
        for row in column {
            layer_rows.push(row.clone());
        }
    }

    let mut layer_index = HashMap::new();
    let mut chord_index: HashMap<String, HashMap<Layer, HashMap<String, Binding>>> = HashMap::new();
    for layer in [Layer::Os, Layer::App] {
        layer_index.insert(layer, index_rows(&layer_rows, layer, false, &mut warn));
        for (name, chord) in &bindings.chords {
            let both = index_rows(&chord.rows, layer, true, &mut warn);
            let plain = both.get(&false).cloned().unwrap_or_default();
            chord_index
                .entry(name.clone())
                .or_default()
                .insert(layer, plain);
        }
    }

    let mut used = HashSet::new();
    for layer in [Layer::Os, Layer::App] {
        for shift_rows in layer_index.get(&layer).into_iter().flat_map(|m| m.values()) {
            for binding in shift_rows.values() {
                check_binding(
                    layer,
                    binding,
                    &bindings.chords,
                    &chord_index,
                    &targets.system,
                    &mut used,
                    &mut warn,
                );
                if let Some(name) = &binding.chord {
                    if let Some(inner) = chord_index.get(name).and_then(|c| c.get(&layer)) {
                        for nested in inner.values() {
                            check_binding(
                                layer,
                                nested,
                                &bindings.chords,
                                &chord_index,
                                &targets.system,
                                &mut used,
                                &mut warn,
                            );
                        }
                    }
                }
            }
        }
    }

    unused("the operating system", &targets.system, &used, &mut warn);
    for (bundle, app) in &targets.apps {
        unused(bundle, app, &used, &mut warn);
    }

    let chords = bindings
        .chords
        .iter()
        .map(|(name, chord)| {
            (
                name.clone(),
                CompiledChord {
                    title: chord.title.clone(),
                    rows: chord.rows.clone(),
                    index: chord_index.remove(name).unwrap_or_default(),
                },
            )
        })
        .collect();

    Compiled {
        titles,
        columns: bindings.columns.clone(),
        layer_index,
        chords,
        system: targets.system.clone(),
        apps: targets.apps.clone(),
        warnings,
    }
}

fn index_rows(
    rows: &[Row],
    layer: Layer,
    chords_only_plain: bool,
    warn: &mut impl FnMut(String),
) -> HashMap<bool, HashMap<String, Binding>> {
    let mut index = HashMap::from([(false, HashMap::new()), (true, HashMap::new())]);
    for row in rows {
        if let Some(text) = &row.layer {
            if Layer::parse(text).is_none() {
                warn(format!("unknown layer {text}"));
            }
        }
        if !row.on_layer(layer) {
            continue;
        }
        if row.keys.is_empty() && row.key_args.is_empty() {
            warn("a row has no keys".to_string());
        }
        if !row.keys.is_empty() && !row.key_args.is_empty() {
            warn("a row sets both keys and key_args".to_string());
        }
        let shift = row.shift;
        if chords_only_plain && shift {
            continue;
        }
        for (key, arg) in row.pairs() {
            let table = index.get_mut(&shift).unwrap();
            if table.contains_key(&key) {
                warn(format!(
                    "{} layer binds {}{} twice",
                    layer.name(),
                    if shift { "shift+" } else { "" },
                    key
                ));
            }
            table.insert(
                key,
                Binding {
                    arg,
                    verb: row.verb.clone(),
                    chord: row.chord.clone(),
                    run: row.run.clone(),
                },
            );
        }
    }
    index
}

fn check_binding(
    layer: Layer,
    binding: &Binding,
    chords: &BTreeMap<String, Chord>,
    chord_index: &HashMap<String, HashMap<Layer, HashMap<String, Binding>>>,
    system: &BTreeMap<String, ActionSpec>,
    used: &mut HashSet<String>,
    warn: &mut impl FnMut(String),
) {
    if let Some(verb) = &binding.verb {
        used.insert(verb.clone());
        if layer == Layer::Os && !system.contains_key(verb) {
            warn(format!("the operating system has no {verb}"));
        }
    }
    if let Some(run) = &binding.run {
        if !COMMANDS.contains(&run.as_str()) {
            warn(format!("no command {run}"));
        }
    }
    if let Some(chord) = &binding.chord {
        if !chords.contains_key(chord) || !chord_index.contains_key(chord) {
            warn(format!("no chord {chord}"));
        }
    }
}

fn unused(
    name: &str,
    target: &BTreeMap<String, ActionSpec>,
    used: &HashSet<String>,
    warn: &mut impl FnMut(String),
) {
    for verb in target.keys() {
        if !used.contains(verb) {
            warn(format!("{name} defines {verb}, which no key runs"));
        }
    }
}

impl Compiled {
    /// Keys that start a chord on `layer`, in Lua string order. Map-shaped
    /// rows are skipped, matching `ipairs` on the bindings table.
    pub fn chord_starters(&self, layer: Layer) -> Vec<(String, String)> {
        let mut starters = Vec::new();
        for column in &self.columns {
            for row in column {
                let Some(name) = &row.chord else {
                    continue;
                };
                if row.shift || !row.on_layer(layer) {
                    continue;
                }
                let Some(chord) = self.chords.get(name) else {
                    continue;
                };
                for key in &row.keys {
                    starters.push((key.clone(), chord.title.clone()));
                }
            }
        }
        starters.sort_by(|a, b| a.0.cmp(&b.0));
        starters
    }
}

pub fn menu_label(path: &[String]) -> String {
    path.join(" > ")
}

pub fn key_label(map: &KeyMap, flags: &Flags, code: u16) -> String {
    let mut parts = Vec::new();
    if flags.cmd {
        parts.push("cmd");
    }
    if flags.alt {
        parts.push("alt");
    }
    if flags.ctrl {
        parts.push("ctrl");
    }
    if flags.shift {
        parts.push("shift");
    }
    if flags.fn_key {
        parts.push("fn");
    }
    let name = map.name(code).unwrap_or("?");
    parts.push(name);
    parts.join("+")
}

/// `tell application "System Events" to key code N using {command down, ...}`
pub fn system_events_script(map: &KeyMap, mods: &[Mod], key: &str) -> Option<(u16, String)> {
    let code = map.code(key)?;
    let using = mods
        .iter()
        .map(|m| m.applescript())
        .collect::<Vec<_>>()
        .join(", ");
    let script = format!("tell application \"System Events\" to key code {code} using {{{using}}}");
    Some((code, script))
}

pub fn parse_system_events(args: &[String]) -> Option<(u16, Flags)> {
    let script = (args.first()?.as_str() == "-e").then_some(args.get(1)?.as_str())?;
    let rest = script.strip_prefix("tell application \"System Events\" to key code ")?;
    let (code_text, using) = rest.split_once(" using {")?;
    let using = using.strip_suffix('}')?;
    let code: u16 = code_text.parse().ok()?;
    let mut flags = Flags::empty();
    if using.is_empty() {
        return Some((code, flags));
    }
    for word in using.split(", ") {
        match word.strip_suffix(" down")? {
            "command" => flags.cmd = true,
            "option" => flags.alt = true,
            "control" => flags.ctrl = true,
            "shift" => flags.shift = true,
            _ => return None,
        }
    }
    Some((code, flags))
}
