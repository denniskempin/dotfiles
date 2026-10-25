//! Offline stand-in for the event tap, processes, and overlay.
//! Time moves only when a test calls [`World::advance`] or [`World::settle`].

use crate::engine::{Command, Driver, Engine, Event, Host, OverlaySpec, Wake};
use crate::keys::KeyMap;
use crate::model::{key_label, menu_label, parse_system_events, Compiled, Flags, Layer};
use std::collections::HashSet;
use std::sync::Arc;

pub struct WorldOpts {
    pub front: Option<String>,
    pub latency: f64,
    pub hang: Option<Box<dyn Fn(&[String]) -> bool>>,
    pub deliver_hotkeys: bool,
    pub menus: HashSet<String>,
}

impl Default for WorldOpts {
    fn default() -> Self {
        Self {
            front: None,
            latency: 0.05,
            hang: None,
            deliver_hotkeys: true,
            menus: HashSet::new(),
        }
    }
}

struct Timer {
    id: u64,
    at: f64,
    seq: u64,
    live: bool,
    wake: Wake,
}

struct Job {
    effect: String,
    done: bool,
}

struct SimHost {
    keys: KeyMap,
    now: f64,
    timers: Vec<Timer>,
    next_timer: u64,
    seq: u64,
    log: Vec<String>,
    warnings: Vec<String>,
    problems: Vec<String>,
    front: Option<String>,
    latency: f64,
    hang: Option<Box<dyn Fn(&[String]) -> bool>>,
    deliver_hotkeys: bool,
    menus: HashSet<String>,
    jobs: std::collections::HashMap<u64, Job>,
    overlay_visible: bool,
    overlay_shows: u32,
    overlay_title: String,
}

pub struct OverlayView {
    pub visible: bool,
    pub shows: u32,
    pub title: String,
}

impl SimHost {
    fn new(opts: WorldOpts) -> Self {
        Self {
            keys: KeyMap::us(),
            now: 0.0,
            timers: Vec::new(),
            next_timer: 1,
            seq: 0,
            log: Vec::new(),
            warnings: Vec::new(),
            problems: Vec::new(),
            front: opts.front,
            latency: opts.latency,
            hang: opts.hang,
            deliver_hotkeys: opts.deliver_hotkeys,
            menus: opts.menus,
            jobs: std::collections::HashMap::new(),
            overlay_visible: false,
            overlay_shows: 0,
            overlay_title: String::new(),
        }
    }

    fn record(&mut self, effect: String) {
        self.log.push(effect);
    }

    fn pop_due(&mut self, target: f64) -> Option<Wake> {
        let mut best: Option<usize> = None;
        for (i, timer) in self.timers.iter().enumerate() {
            if timer.live && timer.at <= target {
                let better = match best {
                    None => true,
                    Some(b) => {
                        timer.at < self.timers[b].at
                            || (timer.at == self.timers[b].at && timer.seq < self.timers[b].seq)
                    }
                };
                if better {
                    best = Some(i);
                }
            }
        }
        let index = best?;
        self.timers[index].live = false;
        self.now = self.now.max(self.timers[index].at);
        Some(self.timers[index].wake.clone())
    }
}

impl Host for SimHost {
    fn now(&self) -> f64 {
        self.now
    }

    fn schedule(&mut self, delay: f64, wake: Wake) -> u64 {
        self.seq += 1;
        let id = self.next_timer;
        self.next_timer += 1;
        self.timers.push(Timer {
            id,
            at: self.now + delay,
            seq: self.seq,
            live: true,
            wake,
        });
        id
    }

    fn cancel(&mut self, id: u64) {
        for timer in &mut self.timers {
            if timer.id == id {
                timer.live = false;
            }
        }
    }

    fn spawn(&mut self, proc: u64, cmd: &Command) -> bool {
        let name = cmd.path.rsplit('/').next().unwrap_or(&cmd.path);
        let mut effect = format!("{name} {}", cmd.args.join(" "));
        if name == "osascript" {
            if let Some((code, flags)) = parse_system_events(&cmd.args) {
                effect = format!("system-events {}", key_label(&self.keys, &flags, code));
            }
        }
        self.record(effect.clone());
        self.jobs.insert(
            proc,
            Job {
                effect,
                done: false,
            },
        );
        let hung = self.hang.as_ref().is_some_and(|hang| hang(&cmd.args));
        if !hung {
            let latency = self.latency;
            self.schedule(latency, Wake::ProcDone { proc, code: 0 });
        }
        true
    }

    fn terminate(&mut self, proc: u64) {
        let effect = {
            let Some(job) = self.jobs.get_mut(&proc) else {
                return;
            };
            if job.done {
                return;
            }
            job.done = true;
            job.effect.clone()
        };
        self.record(format!("terminate {effect}"));
        self.schedule(0.0, Wake::ProcDone { proc, code: 15 });
    }

    fn front_bundle(&self) -> Option<String> {
        self.front.clone()
    }

    fn press_menu(&mut self, path: &[String]) -> bool {
        let text = menu_label(path);
        let hit = self.menus.contains(&text);
        self.record(format!("menu {text}"));
        hit
    }

    fn show_overlay(&mut self, spec: &OverlaySpec) {
        self.overlay_title = spec.title.clone();
        self.overlay_visible = true;
        self.overlay_shows += 1;
    }

    fn hide_overlay(&mut self) {
        self.overlay_visible = false;
    }

    fn warn(&mut self, message: &str) {
        self.warnings.push(message.to_string());
    }

    fn aerospace_path(&self) -> Option<String> {
        Some("/opt/homebrew/bin/aerospace".to_string())
    }

    fn deliver_hotkeys(&self) -> bool {
        self.deliver_hotkeys
    }

    fn problem(&mut self, message: &str) {
        self.problems.push(message.to_string());
    }

    fn record_posted(&mut self, label: &str, down_passed: bool, up_passed: bool) {
        if !down_passed {
            self.problems
                .push(format!("the tap swallowed posted {label} down"));
        }
        if !up_passed {
            self.problems
                .push(format!("the tap swallowed posted {label} up"));
        }
        self.log.push(format!("press {label}"));
    }
}

pub struct World {
    driver: Driver<SimHost>,
}

impl World {
    pub fn new(grammar: Arc<Compiled>, opts: WorldOpts) -> Self {
        let warnings = grammar.warnings.clone();
        let mut host = SimHost::new(opts);
        host.warnings.extend(warnings);
        let engine = Engine::new(grammar, KeyMap::us(), &mut host);
        Self {
            driver: Driver { engine, host },
        }
    }

    pub fn advance(&mut self, dt: f64) {
        let target = self.driver.host.now + dt;
        loop {
            let Some(wake) = self.driver.host.pop_due(target) else {
                break;
            };
            self.driver.on_wake(wake);
        }
        self.driver.host.now = target;
        self.driver.host.timers.retain(|timer| timer.live);
    }

    pub fn settle(&mut self) {
        self.advance(30.0);
    }

    pub fn effects(&mut self) -> Vec<String> {
        std::mem::take(&mut self.driver.host.log)
    }

    pub fn take_warnings(&mut self) -> Vec<String> {
        std::mem::take(&mut self.driver.host.warnings)
    }

    pub fn problems(&self) -> &[String] {
        &self.driver.host.problems
    }

    pub fn warnings(&self) -> &[String] {
        &self.driver.host.warnings
    }

    pub fn overlay(&self) -> OverlayView {
        OverlayView {
            visible: self.driver.host.overlay_visible,
            shows: self.driver.host.overlay_shows,
            title: self.driver.host.overlay_title.clone(),
        }
    }

    fn code(&self, key: &str) -> u16 {
        self.driver
            .engine
            .keys
            .code(key)
            .unwrap_or_else(|| panic!("unknown key {key}"))
    }

    pub fn event(&mut self, key: &str, down: bool, flags: Flags, repeat: bool) -> bool {
        let code = self.code(key);
        let swallowed = self.driver.handle(&Event {
            code,
            down,
            flags,
            repeat,
            marked: false,
        });
        !swallowed
    }

    pub fn down(&mut self, key: &str, flags: Flags) -> bool {
        self.event(key, true, flags, false)
    }

    pub fn up(&mut self, key: &str, flags: Flags) -> bool {
        self.event(key, false, flags, false)
    }

    pub fn press(&mut self, key: &str, flags: Flags) -> (bool, bool) {
        let down = self.down(key, flags.clone());
        let up = self.up(key, flags);
        (down, up)
    }

    pub fn autorepeat(&mut self, key: &str, flags: Flags) -> bool {
        self.event(key, true, flags, true)
    }

    pub fn layer_title(&self, layer: Layer) -> String {
        self.driver
            .engine
            .grammar()
            .titles
            .get(&layer)
            .cloned()
            .unwrap_or_default()
    }
}
