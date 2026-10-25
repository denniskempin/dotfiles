//! US virtual key codes, from `hs.keycodes.map` on a US layout.
//! `padenter` is reported as itself and aliased to `return` before lookup.

use std::collections::HashMap;

pub const F18: u16 = 79;
pub const F19: u16 = 80;
#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
pub const MARK: i64 = 0x4B424C31;

const CODES: &[(u16, &str)] = &[
    (0, "a"),
    (1, "s"),
    (2, "d"),
    (3, "f"),
    (4, "h"),
    (5, "g"),
    (6, "z"),
    (7, "x"),
    (8, "c"),
    (9, "v"),
    (10, "§"),
    (11, "b"),
    (12, "q"),
    (13, "w"),
    (14, "e"),
    (15, "r"),
    (16, "y"),
    (17, "t"),
    (18, "1"),
    (19, "2"),
    (20, "3"),
    (21, "4"),
    (22, "6"),
    (23, "5"),
    (24, "="),
    (25, "9"),
    (26, "7"),
    (27, "-"),
    (28, "8"),
    (29, "0"),
    (30, "]"),
    (31, "o"),
    (32, "u"),
    (33, "["),
    (34, "i"),
    (35, "p"),
    (36, "return"),
    (37, "l"),
    (38, "j"),
    (39, "'"),
    (40, "k"),
    (41, ";"),
    (42, "\\"),
    (43, ","),
    (44, "/"),
    (45, "n"),
    (46, "m"),
    (47, "."),
    (48, "tab"),
    (49, "space"),
    (50, "`"),
    (51, "delete"),
    (53, "escape"),
    (54, "rightcmd"),
    (55, "cmd"),
    (56, "shift"),
    (57, "capslock"),
    (58, "alt"),
    (59, "ctrl"),
    (60, "rightshift"),
    (61, "rightalt"),
    (62, "rightctrl"),
    (63, "fn"),
    (64, "f17"),
    (65, "pad."),
    (67, "pad*"),
    (69, "pad+"),
    (71, "padclear"),
    (75, "pad/"),
    (76, "padenter"),
    (78, "pad-"),
    (79, "f18"),
    (80, "f19"),
    (81, "pad="),
    (82, "pad0"),
    (83, "pad1"),
    (84, "pad2"),
    (85, "pad3"),
    (86, "pad4"),
    (87, "pad5"),
    (88, "pad6"),
    (89, "pad7"),
    (90, "f20"),
    (91, "pad8"),
    (92, "pad9"),
    (93, "yen"),
    (94, "underscore"),
    (95, "pad,"),
    (96, "f5"),
    (97, "f6"),
    (98, "f7"),
    (99, "f3"),
    (100, "f8"),
    (101, "f9"),
    (102, "eisu"),
    (103, "f11"),
    (104, "kana"),
    (105, "f13"),
    (106, "f16"),
    (107, "f14"),
    (109, "f10"),
    (111, "f12"),
    (113, "f15"),
    (114, "help"),
    (115, "home"),
    (116, "pageup"),
    (117, "forwarddelete"),
    (118, "f4"),
    (119, "end"),
    (120, "f2"),
    (121, "pagedown"),
    (122, "f1"),
    (123, "left"),
    (124, "right"),
    (125, "down"),
    (126, "up"),
];

const ALIASES: &[(&str, &str)] = &[
    ("backslash", "\\"),
    ("quote", "'"),
    ("semicolon", ";"),
    ("equal", "="),
    ("minus", "-"),
    ("leftbracket", "["),
    ("rightbracket", "]"),
    ("padenter", "return"),
];

#[derive(Clone)]
pub struct KeyMap {
    code_to_name: HashMap<u16, String>,
    name_to_code: HashMap<String, u16>,
}

impl KeyMap {
    pub fn us() -> Self {
        let mut code_to_name = HashMap::new();
        let mut name_to_code = HashMap::new();
        for (code, name) in CODES {
            code_to_name.insert(*code, (*name).to_string());
            name_to_code.insert((*name).to_string(), *code);
        }
        Self {
            code_to_name,
            name_to_code,
        }
    }

    pub fn name(&self, code: u16) -> Option<&str> {
        self.code_to_name.get(&code).map(String::as_str)
    }

    /// Layout name, then the alias the grammar is indexed by.
    pub fn grammar_name(&self, code: u16) -> Option<&str> {
        let name = self.name(code)?;
        Some(
            ALIASES
                .iter()
                .find(|(from, _)| *from == name)
                .map(|(_, to)| *to)
                .unwrap_or(name),
        )
    }

    pub fn code(&self, name: &str) -> Option<u16> {
        self.name_to_code.get(name).copied()
    }

    pub fn names(&self) -> impl Iterator<Item = &str> {
        self.code_to_name.values().map(String::as_str)
    }
}

pub fn probed_keys(map: &KeyMap) -> Vec<String> {
    const SKIP: &[&str] = &[
        "f18",
        "f19",
        "fn",
        "capslock",
        "cmd",
        "alt",
        "ctrl",
        "shift",
        "rightcmd",
        "rightalt",
        "rightctrl",
        "rightshift",
    ];
    let mut keys: Vec<String> = map
        .names()
        .filter(|name| !SKIP.contains(name))
        .map(str::to_string)
        .collect();
    keys.sort_by(|a, b| sort_key(a).cmp(&sort_key(b)));
    keys
}

fn sort_key(name: &str) -> (u8, SortSecond) {
    const ARROWS: &[(&str, u8)] = &[("left", 1), ("down", 2), ("up", 3), ("right", 4)];
    if let Some((_, n)) = ARROWS.iter().find(|(arrow, _)| *arrow == name) {
        return (1, SortSecond::Num(*n as u32));
    }
    let bytes = name.as_bytes();
    if bytes.len() == 1 && bytes[0].is_ascii_lowercase() {
        return (2, SortSecond::Text(name.to_string()));
    }
    if bytes.len() == 1 && bytes[0].is_ascii_digit() {
        return (3, SortSecond::Text(name.to_string()));
    }
    if name.len() == 1 {
        return (4, SortSecond::Text(name.to_string()));
    }
    if let Some(rest) = name.strip_prefix('f') {
        if !rest.is_empty() && rest.bytes().all(|b| b.is_ascii_digit()) {
            return (6, SortSecond::Num(rest.parse().unwrap_or(0)));
        }
    }
    if name.starts_with("pad") {
        return (7, SortSecond::Text(name.to_string()));
    }
    (5, SortSecond::Text(name.to_string()))
}

#[derive(PartialEq, Eq, PartialOrd, Ord)]
enum SortSecond {
    Num(u32),
    Text(String),
}
