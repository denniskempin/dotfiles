//! macOS adapter: a modifying session event tap, a process queue, menu
//! presses, and the overlay panel.
//!
//! Posted events are stamped with [`MARK`] and the callback returns them
//! before it borrows the session. `CGEventPost` re-enters the tap on the
//! same stack, and borrowing first would panic.

mod menu;
mod panel;

use crate::engine::{Command, Driver, Engine, Event, Host, OverlaySpec, Wake};
use crate::grammar::{load_dir, repo_config_dir};
use crate::keys::{KeyMap, MARK};
use crate::model::Flags;
use objc2::rc::Retained;
use objc2::runtime::{AnyObject, NSObject};
use objc2::{define_class, msg_send, sel, DefinedClass, MainThreadMarker};
use objc2_app_kit::{
    NSApplication, NSApplicationActivationPolicy, NSRunningApplication, NSWorkspace,
};
use objc2_application_services::{kAXTrustedCheckOptionPrompt, AXIsProcessTrustedWithOptions};
use objc2_core_foundation::{
    kCFRunLoopCommonModes, kCFTypeDictionaryKeyCallBacks, kCFTypeDictionaryValueCallBacks,
    CFDictionary, CFMachPort, CFRunLoop, CFString, CFType,
};
use objc2_core_graphics::{
    CGEvent, CGEventField, CGEventFlags, CGEventTapLocation, CGEventTapOptions,
    CGEventTapPlacement, CGEventTapProxy, CGEventType,
};
use objc2_foundation::{NSRunLoop, NSRunLoopCommonModes, NSTimer};
use panel::OverlayWindows;
use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::ffi::c_void;
use std::path::{Path, PathBuf};
use std::ptr::{self, NonNull};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime};

const PUMP_SECONDS: f64 = 0.005;

static RELOAD: AtomicBool = AtomicBool::new(false);

extern "C" {
    static kCFBooleanTrue: &'static CFType;
}

struct Timer {
    id: u64,
    at: f64,
    live: bool,
    wake: Wake,
}

struct MacHost {
    mtm: MainThreadMarker,
    started: Instant,
    keys: KeyMap,
    timers: RefCell<Vec<Timer>>,
    next_timer: Cell<u64>,
    pids: RefCell<HashMap<u64, u32>>,
    tx: Sender<Wake>,
    overlay: RefCell<OverlayWindows>,
}

struct Session {
    driver: RefCell<Driver<MacHost>>,
    rx: Mutex<Receiver<Wake>>,
    tap: Cell<*const CFMachPort>,
    tap_try: Cell<Instant>,
    config_dir: PathBuf,
    stamp: Cell<Option<(SystemTime, SystemTime)>>,
    polled: Cell<Instant>,
}

pub fn run() {
    let mtm = MainThreadMarker::new().expect("keyagent must start on the main thread");
    let app = NSApplication::sharedApplication(mtm);
    let _ = app.setActivationPolicy(NSApplicationActivationPolicy::Accessory);
    prompt_accessibility();

    let config_dir = match config_dir() {
        Ok(dir) => dir,
        Err(err) => {
            eprintln!("keyagent: {err}");
            std::process::exit(1);
        }
    };
    let grammar = match load_dir(&config_dir) {
        Ok(grammar) => Arc::new(grammar),
        Err(err) => {
            eprintln!("keyagent: {err}");
            std::process::exit(1);
        }
    };

    let (tx, rx) = mpsc::channel();
    let mut host = MacHost::new(mtm, tx);
    for warning in &grammar.warnings {
        host.warn(warning);
    }
    let engine = Engine::new(Arc::clone(&grammar), KeyMap::us(), &mut host);
    let session = Box::leak(Box::new(Session {
        driver: RefCell::new(Driver { engine, host }),
        rx: Mutex::new(rx),
        tap: Cell::new(ptr::null()),
        tap_try: Cell::new(Instant::now()),
        config_dir,
        stamp: Cell::new(None),
        polled: Cell::new(Instant::now()),
    }));
    session.stamp.set(file_stamp(&session.config_dir));
    install_reload_signal();
    ensure_tap(session);
    schedule_pump(session);
    eprintln!("keyagent: running");
    app.run();
}

fn prompt_accessibility() {
    let key = unsafe { kAXTrustedCheckOptionPrompt };
    let value = unsafe { kCFBooleanTrue };
    let mut keys = [key as *const CFString as *const c_void];
    let mut values = [value as *const CFType as *const c_void];
    let options = unsafe {
        CFDictionary::new(
            None,
            keys.as_mut_ptr(),
            values.as_mut_ptr(),
            1,
            &kCFTypeDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks,
        )
    };
    let _trusted = unsafe { AXIsProcessTrustedWithOptions(options.as_deref()) };
}

fn config_dir() -> Result<PathBuf, String> {
    if let Some(dir) = std::env::var_os("KEYAGENT_CONFIG") {
        return Ok(PathBuf::from(dir));
    }
    if let Some(home) = std::env::var_os("HOME") {
        let dir = PathBuf::from(home).join(".config/keyagent");
        if dir.join("bindings.ron").is_file() {
            return Ok(dir);
        }
    }
    let repo = repo_config_dir();
    if repo.join("bindings.ron").is_file() {
        return Ok(repo);
    }
    Err("no grammar found. Link ~/.config/keyagent or set KEYAGENT_CONFIG.".into())
}

fn file_stamp(dir: &Path) -> Option<(SystemTime, SystemTime)> {
    let bindings = std::fs::metadata(dir.join("bindings.ron"))
        .ok()?
        .modified()
        .ok()?;
    let targets = std::fs::metadata(dir.join("targets.ron"))
        .ok()?
        .modified()
        .ok()?;
    Some((bindings, targets))
}

fn install_reload_signal() {
    unsafe {
        libc::signal(libc::SIGHUP, handle_hup as *const () as libc::sighandler_t);
    }
}

extern "C" fn handle_hup(_signal: i32) {
    RELOAD.store(true, Ordering::Relaxed);
}

fn ensure_tap(session: &Session) {
    if !session.tap.get().is_null() {
        return;
    }
    let mask = (1u64 << CGEventType::KeyDown.0) | (1u64 << CGEventType::KeyUp.0);
    let port = unsafe {
        CGEvent::tap_create(
            CGEventTapLocation::SessionEventTap,
            CGEventTapPlacement::HeadInsertEventTap,
            CGEventTapOptions::Default,
            mask,
            Some(tap_callback),
            session as *const Session as *mut c_void,
        )
    };
    let Some(port) = port else {
        eprintln!(
            "keyagent: event tap was not created. Grant Accessibility and Input Monitoring to Keyagent, then it will retry."
        );
        return;
    };
    let Some(source) = CFMachPort::new_run_loop_source(None, Some(&port), 0) else {
        eprintln!("keyagent: event tap run-loop source was not created");
        return;
    };
    if let Some(run_loop) = CFRunLoop::current() {
        run_loop.add_source(Some(&source), unsafe { kCFRunLoopCommonModes });
    }
    CGEvent::tap_enable(&port, true);
    session.tap.set(&*port as *const CFMachPort);
    // The port and source have to outlive every callback. Dropping them
    // removes the tap.
    std::mem::forget(port);
    std::mem::forget(source);
    eprintln!("keyagent: event tap installed");
}

unsafe extern "C-unwind" fn tap_callback(
    _proxy: CGEventTapProxy,
    kind: CGEventType,
    event: NonNull<CGEvent>,
    user: *mut c_void,
) -> *mut CGEvent {
    let session = unsafe { &*(user as *const Session) };
    if kind == CGEventType::TapDisabledByTimeout || kind == CGEventType::TapDisabledByUserInput {
        let port = session.tap.get();
        if !port.is_null() {
            CGEvent::tap_enable(unsafe { &*port }, true);
            eprintln!("keyagent: re-enabled the event tap");
        }
        return ptr::null_mut();
    }
    let ev = unsafe { event.as_ref() };
    if CGEvent::integer_value_field(Some(ev), CGEventField::EventSourceUserData) == MARK {
        return event.as_ptr();
    }
    if kind != CGEventType::KeyDown && kind != CGEventType::KeyUp {
        return event.as_ptr();
    }
    let code = CGEvent::integer_value_field(Some(ev), CGEventField::KeyboardEventKeycode) as u16;
    let repeat = CGEvent::integer_value_field(Some(ev), CGEventField::KeyboardEventAutorepeat) != 0;
    let raw = CGEvent::flags(Some(ev));
    let input = Event {
        code,
        down: kind == CGEventType::KeyDown,
        flags: Flags {
            cmd: raw.contains(CGEventFlags::MaskCommand),
            alt: raw.contains(CGEventFlags::MaskAlternate),
            ctrl: raw.contains(CGEventFlags::MaskControl),
            shift: raw.contains(CGEventFlags::MaskShift),
            fn_key: raw.contains(CGEventFlags::MaskSecondaryFn),
        },
        repeat,
        marked: false,
    };
    let swallowed = session.driver.borrow_mut().handle(&input);
    if swallowed {
        ptr::null_mut()
    } else {
        event.as_ptr()
    }
}

struct PumpIvars {
    session: *const Session,
}

define_class!(
    #[unsafe(super(NSObject))]
    #[ivars = PumpIvars]
    struct Pump;

    impl Pump {
        #[unsafe(method(tick:))]
        fn tick(&self, _timer: &NSTimer) {
            let session = self.ivars().session;
            if !session.is_null() {
                on_tick(unsafe { &*session });
            }
        }
    }
);

fn schedule_pump(session: *const Session) {
    let this = Pump::alloc().set_ivars(PumpIvars { session });
    let pump: Retained<Pump> = unsafe { msg_send![super(this), init] };
    let timer = unsafe {
        NSTimer::timerWithTimeInterval_target_selector_userInfo_repeats(
            PUMP_SECONDS,
            as_object(&*pump),
            sel!(tick:),
            None,
            true,
        )
    };
    let run_loop = NSRunLoop::currentRunLoop();
    unsafe { run_loop.addTimer_forMode(&timer, NSRunLoopCommonModes) };
    // The run loop retains the timer, and the timer retains the target.
    // Forget our owns so both stay up for the process lifetime.
    std::mem::forget(timer);
    std::mem::forget(pump);
}

fn on_tick(session: &Session) {
    if session.tap.get().is_null() && session.tap_try.get().elapsed() >= Duration::from_secs(1) {
        session.tap_try.set(Instant::now());
        ensure_tap(session);
    }
    maybe_reload(session);
    for _ in 0..64 {
        let mut batch = Vec::new();
        if let Ok(rx) = session.rx.lock() {
            while let Ok(wake) = rx.try_recv() {
                batch.push(wake);
            }
        }
        let mut driver = session.driver.borrow_mut();
        batch.extend(driver.host.pop_due());
        if batch.is_empty() {
            break;
        }
        for wake in batch {
            if let Wake::ProcDone { proc, .. } = &wake {
                driver.host.forget(*proc);
            }
            driver.on_wake(wake);
        }
    }
}

fn maybe_reload(session: &Session) {
    let forced = RELOAD.swap(false, Ordering::Relaxed);
    let due = session.polled.get().elapsed() >= Duration::from_secs(1);
    if !forced && !due {
        return;
    }
    session.polled.set(Instant::now());
    let stamp = file_stamp(&session.config_dir);
    if !forced && stamp == session.stamp.get() {
        return;
    }
    match load_dir(&session.config_dir) {
        Ok(grammar) => {
            session.stamp.set(stamp);
            let grammar = Arc::new(grammar);
            let warnings = grammar.warnings.clone();
            let mut driver = session.driver.borrow_mut();
            driver.engine.reload(grammar, &mut driver.host);
            for warning in &warnings {
                driver.host.warn(warning);
            }
            eprintln!("keyagent: reloaded {}", session.config_dir.display());
        }
        Err(err) => {
            session.stamp.set(stamp);
            session.driver.borrow_mut().host.warn(&err);
        }
    }
}

impl MacHost {
    fn new(mtm: MainThreadMarker, tx: Sender<Wake>) -> Self {
        Self {
            mtm,
            started: Instant::now(),
            keys: KeyMap::us(),
            timers: RefCell::new(Vec::new()),
            next_timer: Cell::new(1),
            pids: RefCell::new(HashMap::new()),
            tx,
            overlay: RefCell::new(OverlayWindows::new()),
        }
    }

    fn pop_due(&self) -> Vec<Wake> {
        let now = self.now();
        let mut timers = self.timers.borrow_mut();
        let mut due = Vec::new();
        for timer in timers.iter_mut() {
            if timer.live && timer.at <= now {
                timer.live = false;
                due.push(timer.wake.clone());
            }
        }
        timers.retain(|timer| timer.live);
        due
    }

    fn forget(&self, proc: u64) {
        self.pids.borrow_mut().remove(&proc);
    }
}

impl Host for MacHost {
    fn now(&self) -> f64 {
        self.started.elapsed().as_secs_f64()
    }

    fn schedule(&mut self, delay: f64, wake: Wake) -> u64 {
        let id = self.next_timer.get();
        self.next_timer.set(id + 1);
        self.timers.borrow_mut().push(Timer {
            id,
            at: self.now() + delay,
            live: true,
            wake,
        });
        id
    }

    fn cancel(&mut self, id: u64) {
        for timer in self.timers.borrow_mut().iter_mut() {
            if timer.id == id {
                timer.live = false;
            }
        }
    }

    fn spawn(&mut self, proc: u64, cmd: &Command) -> bool {
        let mut command = std::process::Command::new(&cmd.path);
        command.args(&cmd.args).stdin(std::process::Stdio::null());
        let Ok(child) = command.spawn() else {
            return false;
        };
        let pid = child.id();
        self.pids.borrow_mut().insert(proc, pid);
        let tx = self.tx.clone();
        std::thread::spawn(move || {
            let code = match child.wait() {
                Ok(status) => status.code().unwrap_or(1),
                Err(_) => -1,
            };
            let _ = tx.send(Wake::ProcDone { proc, code });
        });
        true
    }

    fn terminate(&mut self, proc: u64) {
        let Some(pid) = self.pids.borrow_mut().remove(&proc) else {
            return;
        };
        unsafe {
            libc::kill(pid as i32, libc::SIGKILL);
        }
    }

    fn front_bundle(&self) -> Option<String> {
        let app = front_app()?;
        Some(app.bundleIdentifier()?.to_string())
    }

    fn press_menu(&mut self, path: &[String]) -> bool {
        let Some(app) = front_app() else {
            return false;
        };
        menu::press(app.processIdentifier(), path)
    }

    fn show_overlay(&mut self, spec: &OverlaySpec) {
        self.overlay.borrow_mut().show(self.mtm, spec);
    }

    fn hide_overlay(&mut self) {
        self.overlay.borrow_mut().hide();
    }

    fn warn(&mut self, message: &str) {
        eprintln!("keyagent: {message}");
    }

    fn problem(&mut self, message: &str) {
        eprintln!("keyagent: {message}");
    }

    fn aerospace_path(&self) -> Option<String> {
        for path in ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace"] {
            if Path::new(path).is_file() {
                return Some(path.to_string());
            }
        }
        None
    }

    fn deliver_hotkeys(&self) -> bool {
        // System Events posts the real key. Injecting a second copy would
        // consume the pass-through before that key arrives.
        false
    }

    fn posts_into_tap(&self) -> bool {
        true
    }

    fn emit_stroke(&mut self, stroke: &crate::model::Stroke) {
        let Some(code) = self.keys.code(&stroke.key) else {
            self.warn(&format!("no key code for {}", stroke.key));
            return;
        };
        let flags = Flags::from_mods(&stroke.mods);
        post_key(code, true, &flags);
        post_key(code, false, &flags);
    }
}

fn as_object(obj: &impl objc2::Message) -> &AnyObject {
    unsafe { &*(obj as *const _ as *const AnyObject) }
}

fn front_app() -> Option<Retained<NSRunningApplication>> {
    NSWorkspace::sharedWorkspace().frontmostApplication()
}

fn post_key(code: u16, down: bool, flags: &Flags) {
    let Some(event) = CGEvent::new_keyboard_event(None, code, down) else {
        return;
    };
    CGEvent::set_flags(Some(&event), event_flags(flags));
    CGEvent::set_integer_value_field(Some(&event), CGEventField::EventSourceUserData, MARK);
    CGEvent::post(CGEventTapLocation::SessionEventTap, Some(&event));
}

fn event_flags(flags: &Flags) -> CGEventFlags {
    let mut raw = CGEventFlags::empty();
    if flags.cmd {
        raw |= CGEventFlags::MaskCommand;
    }
    if flags.alt {
        raw |= CGEventFlags::MaskAlternate;
    }
    if flags.ctrl {
        raw |= CGEventFlags::MaskControl;
    }
    if flags.shift {
        raw |= CGEventFlags::MaskShift;
    }
    if flags.fn_key {
        raw |= CGEventFlags::MaskSecondaryFn;
    }
    raw
}
