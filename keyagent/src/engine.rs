//! The layer state machine. It never blocks: processes and menu presses are
//! handed to the host, and timers come back as [`Wake`]s.

use crate::keys::{KeyMap, F18, F19};
use crate::model::{
    key_label, resolve, system_events_script, Action, ActionSpec, Binding, Compiled, Flags, Layer,
    Mod, OverlayRow, Stroke,
};
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;

pub const OVERLAY_DELAY: f64 = 0.25;
pub const CHORD_GAP: f64 = 0.02;
pub const HOTKEY_WAIT: f64 = 2.0;
pub const AERO_TIMEOUT: f64 = 5.0;

#[derive(Clone, Debug)]
pub enum Wake {
    Overlay(OverlayWake),
    ChordGap { rest: Vec<Stroke> },
    Menu { paths: Vec<Vec<String>> },
    AeroTimeout { proc: u64 },
    ProcDone { proc: u64, code: i32 },
}

#[derive(Clone, Copy, Debug)]
pub enum OverlayWake {
    Layer,
    Chord,
}

#[derive(Clone, Debug)]
pub struct HotkeyDelivery {
    pub code: u16,
    pub flags: Flags,
}

#[derive(Clone, Debug)]
pub struct Command {
    pub path: String,
    pub args: Vec<String>,
}

#[derive(Clone, Debug)]
#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
pub struct OverlaySpec {
    pub layer: Layer,
    pub title: String,
    pub columns: Vec<Vec<OverlayRow>>,
    pub rows: Vec<OverlayRow>,
    pub footer: String,
}

pub trait Host {
    fn now(&self) -> f64;
    fn schedule(&mut self, delay: f64, wake: Wake) -> u64;
    fn cancel(&mut self, id: u64);
    fn spawn(&mut self, proc: u64, cmd: &Command) -> bool;
    fn terminate(&mut self, proc: u64);
    fn front_bundle(&self) -> Option<String>;
    /// Records the attempt. True when that path exists and the press landed.
    fn press_menu(&mut self, path: &[String]) -> bool;
    fn show_overlay(&mut self, spec: &OverlaySpec);
    fn hide_overlay(&mut self);
    fn warn(&mut self, message: &str);
    fn aerospace_path(&self) -> Option<String>;
    fn deliver_hotkeys(&self) -> bool {
        true
    }
    fn problem(&mut self, _message: &str) {}
    fn record_posted(&mut self, _label: &str, _down_passed: bool, _up_passed: bool) {}
    /// The host posts into the live tap, which re-enters on marked events.
    fn posts_into_tap(&self) -> bool {
        false
    }
    fn emit_stroke(&mut self, _stroke: &Stroke) {}
}

#[derive(Clone, Debug)]
pub struct Event {
    pub code: u16,
    pub down: bool,
    pub flags: Flags,
    pub repeat: bool,
    pub marked: bool,
}

struct ActiveChord {
    layer: Layer,
    name: String,
}

struct Expected {
    mods: Vec<Mod>,
    pending: u32,
    deadline: f64,
}

struct AeroJob {
    proc: u64,
    timeout: Option<u64>,
}

struct ProcMeta {
    aero: bool,
    hotkey: Option<HotkeyDelivery>,
    warn: String,
}

pub struct Engine {
    pub keys: KeyMap,
    grammar: Arc<Compiled>,
    os_down: bool,
    app_down: bool,
    last_held: Option<Layer>,
    locked: Option<Layer>,
    chord: Option<ActiveChord>,
    swallowed: HashMap<u16, ()>,
    expected: HashMap<u16, Expected>,
    overlay_timer: Option<u64>,
    aerospace: Option<String>,
    queue: VecDeque<Vec<String>>,
    running: Option<AeroJob>,
    procs: HashMap<u64, ProcMeta>,
    next_proc: u64,
    pending_posts: VecDeque<Stroke>,
}

impl Engine {
    pub fn new(grammar: Arc<Compiled>, keys: KeyMap, host: &mut dyn Host) -> Self {
        Self {
            keys,
            grammar,
            os_down: false,
            app_down: false,
            last_held: None,
            locked: None,
            chord: None,
            swallowed: HashMap::new(),
            expected: HashMap::new(),
            overlay_timer: None,
            aerospace: host.aerospace_path(),
            queue: VecDeque::new(),
            running: None,
            procs: HashMap::new(),
            next_proc: 1,
            pending_posts: VecDeque::new(),
        }
    }

    pub fn grammar(&self) -> &Compiled {
        &self.grammar
    }

    #[cfg_attr(not(target_os = "macos"), allow(dead_code))]
    pub fn reload(&mut self, grammar: Arc<Compiled>, host: &mut dyn Host) {
        self.grammar = grammar;
        self.os_down = false;
        self.app_down = false;
        self.last_held = None;
        self.locked = None;
        self.chord = None;
        self.swallowed.clear();
        self.hide_overlay(host);
    }

    /// True when the event is swallowed.
    pub fn handle(&mut self, event: &Event, host: &mut dyn Host) -> bool {
        if event.marked {
            return false;
        }
        if self.is_expected(event, host) {
            return false;
        }
        if event.code == F18 || event.code == F19 {
            if event.repeat {
                return true;
            }
            let which = if event.code == F18 {
                Layer::Os
            } else {
                Layer::App
            };
            if event.down {
                self.arm(which, host);
            } else {
                self.release(which, host);
            }
            self.swallowed.remove(&event.code);
            return true;
        }
        if !event.down {
            return self.swallowed.remove(&event.code).is_some();
        }
        if self.active_layer().is_none() && self.chord.is_none() {
            return false;
        }
        self.swallowed.insert(event.code, ());
        let Some(name) = self.keys.grammar_name(event.code) else {
            return true;
        };
        let name = name.to_string();
        if event.repeat {
            return true;
        }
        let shift = event.flags.shift;
        if self.chord.is_some() {
            self.handle_chord(&name, shift, &event.flags, host);
        } else {
            self.handle_layer(&name, shift, &event.flags, host);
        }
        true
    }

    pub fn on_wake(&mut self, wake: Wake, host: &mut dyn Host) -> Option<HotkeyDelivery> {
        match wake {
            Wake::Overlay(which) => {
                self.overlay_timer = None;
                self.show_scheduled(which, host);
                None
            }
            Wake::ChordGap { rest } => {
                self.post_sequence(&rest, host);
                None
            }
            Wake::Menu { paths } => {
                if host.front_bundle().is_some() {
                    for path in &paths {
                        if host.press_menu(path) {
                            break;
                        }
                    }
                }
                None
            }
            Wake::AeroTimeout { proc } => {
                if self.running.as_ref().is_some_and(|job| job.proc == proc) {
                    if let Some(job) = self.running.as_mut() {
                        job.timeout = None;
                    }
                    host.terminate(proc);
                }
                None
            }
            Wake::ProcDone { proc, code } => self.finish_proc(proc, code, host),
        }
    }

    fn is_expected(&mut self, event: &Event, host: &dyn Host) -> bool {
        let Some((deadline, mods, pending)) = self
            .expected
            .get(&event.code)
            .map(|hit| (hit.deadline, hit.mods.clone(), hit.pending))
        else {
            return false;
        };
        if host.now() > deadline {
            self.expected.remove(&event.code);
            return false;
        }
        if mods.iter().any(|m| !event.flags.has_mod(*m)) {
            return false;
        }
        if !event.down {
            if pending <= 1 {
                self.expected.remove(&event.code);
            } else if let Some(hit) = self.expected.get_mut(&event.code) {
                hit.pending = pending - 1;
            }
        }
        true
    }

    fn active_layer(&self) -> Option<Layer> {
        self.locked.or_else(|| self.layer_from_hold())
    }

    fn layer_from_hold(&self) -> Option<Layer> {
        match (self.os_down, self.app_down) {
            (true, true) => self.last_held,
            (true, false) => Some(Layer::Os),
            (false, true) => Some(Layer::App),
            (false, false) => None,
        }
    }

    fn arm(&mut self, which: Layer, host: &mut dyn Host) {
        match which {
            Layer::Os => self.os_down = true,
            Layer::App => self.app_down = true,
        }
        self.last_held = Some(which);
        if self.chord.is_some() || self.locked.is_some() {
            return;
        }
        self.hide_overlay(host);
        self.later(OverlayWake::Layer, host);
    }

    fn release(&mut self, which: Layer, host: &mut dyn Host) {
        match which {
            Layer::Os => self.os_down = false,
            Layer::App => self.app_down = false,
        }
        if self.locked.is_some() || self.chord.is_some() {
            return;
        }
        self.hide_overlay(host);
        if self.layer_from_hold().is_some() {
            self.later(OverlayWake::Layer, host);
        }
    }

    fn unlock(&mut self, host: &mut dyn Host) {
        if self.locked.is_none() {
            return;
        }
        self.locked = None;
        self.hide_overlay(host);
        if self.layer_from_hold().is_some() {
            self.later(OverlayWake::Layer, host);
        }
    }

    fn handle_chord(&mut self, name: &str, shift: bool, flags: &Flags, host: &mut dyn Host) {
        let layer = self.chord.as_ref().map(|chord| chord.layer);
        let chord_name = self.chord.as_ref().map(|chord| chord.name.clone());
        let binding = if !flags.blocked() && !shift {
            self.lookup_chord(chord_name.as_deref(), layer, name)
        } else {
            None
        };
        if let (Some(layer), Some(binding)) = (layer, binding) {
            self.deliver(layer, &binding, host);
        }
        self.end_chord(host);
    }

    fn lookup_chord(&self, name: Option<&str>, layer: Option<Layer>, key: &str) -> Option<Binding> {
        let name = name?;
        let layer = layer?;
        self.grammar
            .chords
            .get(name)?
            .index
            .get(&layer)?
            .get(key)
            .cloned()
    }

    fn handle_layer(&mut self, name: &str, shift: bool, flags: &Flags, host: &mut dyn Host) {
        let Some(layer) = self.active_layer() else {
            return;
        };
        if flags.blocked() {
            return;
        }
        if name == "escape" {
            self.unlock(host);
            return;
        }
        if name == "space" && !shift {
            self.locked = Some(layer);
            self.on_binding(host);
            return;
        }
        let Some(binding) = self
            .grammar
            .layer_index
            .get(&layer)
            .and_then(|by_shift| by_shift.get(&shift))
            .and_then(|index| index.get(name))
            .cloned()
        else {
            return;
        };
        if let Some(chord) = binding.chord.clone() {
            self.begin_chord(&chord, layer, host);
            return;
        }
        self.deliver(layer, &binding, host);
        self.on_binding(host);
    }

    fn deliver(&mut self, layer: Layer, binding: &Binding, host: &mut dyn Host) {
        if let Some(run) = &binding.run {
            if run == "forwardDelete" {
                self.post_stroke(
                    &Stroke {
                        mods: Vec::new(),
                        key: "forwarddelete".to_string(),
                    },
                    host,
                );
            }
            return;
        }
        let Some(verb) = binding.verb.as_deref() else {
            return;
        };
        let spec = if layer == Layer::Os {
            self.grammar.system.get(verb)
        } else {
            let Some(bundle) = host.front_bundle() else {
                return;
            };
            let Some(app) = self.grammar.apps.get(&bundle) else {
                return;
            };
            app.get(verb)
        };
        let Some(spec) = spec else {
            return;
        };
        if let Some(action) = self.resolve_action(spec, &binding.arg, host) {
            self.run_action(action, host);
        }
    }

    fn resolve_action(&self, spec: &ActionSpec, arg: &str, host: &mut dyn Host) -> Option<Action> {
        let mut warnings = Vec::new();
        let action = resolve(spec, arg, &mut warnings);
        for warning in warnings {
            host.warn(&warning);
        }
        action
    }

    fn run_action(&mut self, action: Action, host: &mut dyn Host) {
        match action {
            Action::Stroke(stroke) => self.post_stroke(&stroke, host),
            Action::Seq(strokes) => self.post_sequence(&strokes, host),
            Action::Menu(paths) => {
                host.schedule(0.0, Wake::Menu { paths });
            }
            Action::Aero(args) => self.aero_command(args, host),
            Action::Launch(bundle) => {
                self.spawn_proc(
                    "/usr/bin/open",
                    vec!["-g".to_string(), "-b".to_string(), bundle],
                    false,
                    None,
                    host,
                );
            }
            Action::Hotkey { mods, key } => self.post_hotkey(&mods, &key, host),
        }
    }

    fn post_sequence(&mut self, steps: &[Stroke], host: &mut dyn Host) {
        let Some(first) = steps.first() else {
            return;
        };
        self.post_stroke(first, host);
        if steps.len() > 1 {
            host.schedule(
                CHORD_GAP,
                Wake::ChordGap {
                    rest: steps[1..].to_vec(),
                },
            );
        }
    }

    fn post_stroke(&mut self, stroke: &Stroke, _host: &mut dyn Host) {
        self.pending_posts.push_back(stroke.clone());
    }

    pub fn take_post(&mut self) -> Option<Stroke> {
        self.pending_posts.pop_front()
    }

    fn post_hotkey(&mut self, mods: &[Mod], key: &str, host: &mut dyn Host) {
        let Some((code, script)) = system_events_script(&self.keys, mods, key) else {
            host.warn(&format!("no key code for {key}"));
            return;
        };
        let pending = self.expected.get(&code).map(|hit| hit.pending).unwrap_or(0);
        self.expected.insert(
            code,
            Expected {
                mods: mods.to_vec(),
                pending: pending + 1,
                deadline: host.now() + HOTKEY_WAIT,
            },
        );
        self.spawn_proc(
            "/usr/bin/osascript",
            vec!["-e".to_string(), script],
            false,
            Some(HotkeyDelivery {
                code,
                flags: Flags::from_mods(mods),
            }),
            host,
        );
    }

    fn aero_command(&mut self, args: Vec<String>, host: &mut dyn Host) {
        let id = args.join(" ");
        if self.aerospace.is_none() {
            host.warn(&format!("aerospace {id}"));
            return;
        }
        self.queue.push_back(args);
        self.pump(host);
    }

    fn pump(&mut self, host: &mut dyn Host) {
        if self.running.is_some() || self.queue.is_empty() {
            return;
        }
        let Some(args) = self.queue.pop_front() else {
            return;
        };
        let id = args.join(" ");
        let Some(path) = self.aerospace.clone() else {
            host.warn(&format!("aerospace {id}"));
            return;
        };
        let proc = self.alloc_proc(ProcMeta {
            aero: true,
            hotkey: None,
            warn: format!("aerospace {id}"),
        });
        let started = host.spawn(proc, &Command { path, args });
        if !started {
            self.finish_proc(proc, -1, host);
            return;
        }
        let timeout = host.schedule(AERO_TIMEOUT, Wake::AeroTimeout { proc });
        self.running = Some(AeroJob {
            proc,
            timeout: Some(timeout),
        });
    }

    fn finish_proc(&mut self, proc: u64, code: i32, host: &mut dyn Host) -> Option<HotkeyDelivery> {
        let Some(meta) = self.procs.remove(&proc) else {
            return None;
        };
        if code != 0 {
            host.warn(&meta.warn);
        }
        let delivery = if code == 0 { meta.hotkey } else { None };
        if meta.aero && self.running.as_ref().is_some_and(|job| job.proc == proc) {
            if let Some(timer) = self.running.as_ref().and_then(|job| job.timeout) {
                host.cancel(timer);
            }
            self.running = None;
            self.pump(host);
        }
        delivery
    }

    fn spawn_proc(
        &mut self,
        path: &str,
        args: Vec<String>,
        aero: bool,
        hotkey: Option<HotkeyDelivery>,
        host: &mut dyn Host,
    ) {
        let warn = format!("{path} {}: ", args.join(" "));
        let proc = self.alloc_proc(ProcMeta { aero, hotkey, warn });
        if !host.spawn(
            proc,
            &Command {
                path: path.to_string(),
                args,
            },
        ) {
            self.finish_proc(proc, -1, host);
        }
    }

    fn alloc_proc(&mut self, meta: ProcMeta) -> u64 {
        let id = self.next_proc;
        self.next_proc += 1;
        self.procs.insert(id, meta);
        id
    }

    fn begin_chord(&mut self, name: &str, layer: Layer, host: &mut dyn Host) {
        self.chord = Some(ActiveChord {
            layer,
            name: name.to_string(),
        });
        self.hide_overlay(host);
        self.later(OverlayWake::Chord, host);
    }

    fn end_chord(&mut self, host: &mut dyn Host) {
        self.chord = None;
        self.hide_overlay(host);
        if self.locked.is_some() {
            self.later(OverlayWake::Layer, host);
        }
    }

    fn on_binding(&mut self, host: &mut dyn Host) {
        self.hide_overlay(host);
        if self.locked.is_some() && self.chord.is_none() {
            self.later(OverlayWake::Layer, host);
        }
    }

    fn later(&mut self, which: OverlayWake, host: &mut dyn Host) {
        self.cancel_overlay(host);
        let id = host.schedule(OVERLAY_DELAY, Wake::Overlay(which));
        self.overlay_timer = Some(id);
    }

    fn cancel_overlay(&mut self, host: &mut dyn Host) {
        if let Some(id) = self.overlay_timer.take() {
            host.cancel(id);
        }
    }

    fn hide_overlay(&mut self, host: &mut dyn Host) {
        self.cancel_overlay(host);
        host.hide_overlay();
    }

    fn show_scheduled(&mut self, which: OverlayWake, host: &mut dyn Host) {
        let spec = match which {
            OverlayWake::Layer => {
                if self.chord.is_some() {
                    return;
                }
                self.layer_overlay()
            }
            OverlayWake::Chord => self.chord_overlay(),
        };
        if let Some(spec) = spec {
            host.show_overlay(&spec);
        }
    }

    fn layer_overlay(&self) -> Option<OverlaySpec> {
        let layer = self.active_layer()?;
        let mut title = self.grammar.titles.get(&layer).cloned().unwrap_or_default();
        if self.locked.is_some() {
            title.push_str("  ·  locked");
        }
        let columns = self
            .grammar
            .columns
            .iter()
            .map(|column| overlay_rows(column, layer))
            .collect();
        Some(OverlaySpec {
            layer,
            title,
            columns,
            rows: Vec::new(),
            footer: "space locks      esc clears".to_string(),
        })
    }

    fn chord_overlay(&self) -> Option<OverlaySpec> {
        let chord = self.chord.as_ref()?;
        let def = self.grammar.chords.get(&chord.name)?;
        Some(OverlaySpec {
            layer: chord.layer,
            title: def.title.clone(),
            columns: Vec::new(),
            rows: overlay_rows(&def.rows, chord.layer),
            footer: "esc cancels".to_string(),
        })
    }
}

fn overlay_rows(rows: &[crate::model::Row], layer: Layer) -> Vec<OverlayRow> {
    rows.iter()
        .filter(|row| row.label.is_some() && row.on_layer(layer))
        .map(|row| OverlayRow {
            label: row.label.clone().unwrap_or_default(),
            hint: row.hint.clone().unwrap_or_default(),
        })
        .collect()
}

pub struct Driver<H: Host> {
    pub engine: Engine,
    pub host: H,
}

impl<H: Host> Driver<H> {
    pub fn handle(&mut self, event: &Event) -> bool {
        let swallowed = self.engine.handle(event, &mut self.host);
        self.drain_posts();
        swallowed
    }

    pub fn on_wake(&mut self, wake: Wake) {
        let delivery = self.engine.on_wake(wake, &mut self.host);
        self.drain_posts();
        if let Some(delivery) = delivery {
            self.inject_hotkey(delivery);
        }
    }

    fn drain_posts(&mut self) {
        while let Some(stroke) = self.engine.take_post() {
            if self.host.posts_into_tap() {
                self.host.emit_stroke(&stroke);
                continue;
            }
            let Some(code) = self.engine.keys.code(&stroke.key) else {
                self.host.warn(&format!("no key code for {}", stroke.key));
                continue;
            };
            let flags = Flags::from_mods(&stroke.mods);
            let down_passed = !self.engine.handle(
                &Event {
                    code,
                    down: true,
                    flags: flags.clone(),
                    repeat: false,
                    marked: true,
                },
                &mut self.host,
            );
            let up_passed = !self.engine.handle(
                &Event {
                    code,
                    down: false,
                    flags: flags.clone(),
                    repeat: false,
                    marked: true,
                },
                &mut self.host,
            );
            let label = key_label(&self.engine.keys, &flags, code);
            self.host.record_posted(&label, down_passed, up_passed);
        }
    }

    fn inject_hotkey(&mut self, delivery: HotkeyDelivery) {
        if !self.host.deliver_hotkeys() {
            return;
        }
        let down = Event {
            code: delivery.code,
            down: true,
            flags: delivery.flags.clone(),
            repeat: false,
            marked: false,
        };
        let up = Event {
            code: delivery.code,
            down: false,
            flags: delivery.flags.clone(),
            repeat: false,
            marked: false,
        };
        let down_passed = !self.handle(&down);
        let up_passed = !self.handle(&up);
        if !(down_passed && up_passed) {
            let label = key_label(&self.engine.keys, &delivery.flags, delivery.code);
            self.host.problem(&format!(
                "the tap swallowed the System Events keystroke {label}"
            ));
        }
    }
}
