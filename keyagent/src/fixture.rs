//! The made-up grammar the scenario tests run against.

use crate::model::{compile, ActionSpec, BindingsFile, Chord, Compiled, Row, TargetsFile};
use std::collections::BTreeMap;

pub const APP: &str = "com.example.App";
pub const UNLISTED: &str = "com.example.Unlisted";

pub fn grammar() -> Compiled {
    compile(&bindings(), &targets())
}

fn bindings() -> BindingsFile {
    let arrows = vec!["left".into(), "down".into(), "up".into(), "right".into()];
    BindingsFile {
        titles: BTreeMap::from([("os".into(), "OS".into()), ("app".into(), "App".into())]),
        columns: vec![
            vec![
                row(&arrows, "go", "Go", "arrows"),
                shift_row(&arrows, "carry", "Carry", "⇧ arrows"),
                Row {
                    keys: vec!["s".into()],
                    chord: Some("pick".into()),
                    label: Some("Pick".into()),
                    hint: Some("S then arrow".into()),
                    ..Row::blank()
                },
            ],
            vec![
                Row {
                    keys: vec!["p".into()],
                    layer: Some("os".into()),
                    verb: Some("launch".into()),
                    label: Some("Launch".into()),
                    hint: Some("P".into()),
                    ..Row::blank()
                },
                Row {
                    keys: vec!["o".into()],
                    layer: Some("os".into()),
                    verb: Some("hotkey".into()),
                    label: Some("Hotkey".into()),
                    hint: Some("O".into()),
                    ..Row::blank()
                },
                Row {
                    keys: vec!["k".into()],
                    layer: Some("app".into()),
                    verb: Some("sequence".into()),
                    label: Some("Sequence".into()),
                    hint: Some("K".into()),
                    ..Row::blank()
                },
                Row {
                    keys: vec!["m".into()],
                    layer: Some("app".into()),
                    verb: Some("menu".into()),
                    label: Some("Menu".into()),
                    hint: Some("M".into()),
                    ..Row::blank()
                },
            ],
        ],
        chords: BTreeMap::from([(
            "pick".into(),
            Chord {
                title: "Pick".into(),
                rows: vec![row(&arrows, "pick", "Pick", "arrows")],
            },
        )]),
    }
}

fn row(keys: &[String], verb: &str, label: &str, hint: &str) -> Row {
    Row {
        keys: keys.to_vec(),
        verb: Some(verb.into()),
        label: Some(label.into()),
        hint: Some(hint.into()),
        ..Row::blank()
    }
}

fn shift_row(keys: &[String], verb: &str, label: &str, hint: &str) -> Row {
    Row {
        shift: true,
        ..row(keys, verb, label, hint)
    }
}

fn stroke(mods: &[&str], key: &str) -> ActionSpec {
    ActionSpec::Stroke {
        mods: mods.iter().map(|m| (*m).to_string()).collect(),
        key: key.to_string(),
    }
}

fn targets() -> TargetsFile {
    let mut system = BTreeMap::new();
    system.insert(
        "go".into(),
        ActionSpec::Template(Box::new(ActionSpec::Aero(vec!["go".into(), "$".into()]))),
    );
    system.insert(
        "carry".into(),
        ActionSpec::Template(Box::new(ActionSpec::Aero(vec!["carry".into(), "$".into()]))),
    );
    system.insert(
        "pick".into(),
        ActionSpec::Template(Box::new(ActionSpec::Aero(vec!["pick".into(), "$".into()]))),
    );
    system.insert(
        "launch".into(),
        ActionSpec::Launch("com.example.Launcher".into()),
    );
    system.insert(
        "hotkey".into(),
        ActionSpec::Hotkey {
            mods: vec!["cmd".into(), "alt".into(), "ctrl".into()],
            key: "o".into(),
        },
    );

    let mut app = BTreeMap::new();
    app.insert(
        "go".into(),
        ActionSpec::Template(Box::new(stroke(&["cmd"], "$"))),
    );
    app.insert(
        "carry".into(),
        ActionSpec::Template(Box::new(stroke(&["cmd", "shift"], "$"))),
    );
    app.insert(
        "pick".into(),
        ActionSpec::Template(Box::new(stroke(&["alt"], "$"))),
    );
    app.insert(
        "sequence".into(),
        ActionSpec::Seq(vec![stroke(&["cmd"], "k"), stroke(&["cmd"], "j")]),
    );
    app.insert(
        "menu".into(),
        ActionSpec::Menu(vec![
            vec!["Edit".into(), "First".into()],
            vec!["Edit".into(), "Second".into()],
            vec!["Third".into()],
        ]),
    );

    TargetsFile {
        system,
        apps: BTreeMap::from([(APP.into(), app)]),
    }
}

impl Row {
    pub fn blank() -> Self {
        Self {
            keys: Vec::new(),
            key_args: BTreeMap::new(),
            shift: false,
            layer: None,
            verb: None,
            chord: None,
            run: None,
            label: None,
            hint: None,
        }
    }
}
