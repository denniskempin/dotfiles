//! Press a menu item in the front app. Called from the run-loop timer, never
//! from the event-tap callback: an accessibility query on that stack can
//! deadlock the app being asked.

use objc2_application_services::{AXError, AXUIElement};
use objc2_core_foundation::{CFArray, CFRetained, CFString, CFType};
use std::ptr::NonNull;

const TIMEOUT_SECS: f32 = 0.25;
const MAX_DEPTH: u32 = 8;

pub fn press(pid: libc::pid_t, path: &[String]) -> bool {
    if path.is_empty() || pid < 0 {
        return false;
    }
    let app = unsafe { AXUIElement::new_application(pid) };
    limit(&app);
    let Some(bar) = element(&app, "AXMenuBar") else {
        return false;
    };
    if path.len() == 1 {
        press_leaf(&bar, &path[0], 0)
    } else {
        press_path(&bar, path)
    }
}

fn press_path(bar: &AXUIElement, path: &[String]) -> bool {
    let mut level = descend(bar);
    for (i, name) in path.iter().enumerate() {
        let Some(hit) = level
            .into_iter()
            .find(|el| title(el).as_deref() == Some(name.as_str()))
        else {
            return false;
        };
        if i + 1 == path.len() {
            return activate(&hit);
        }
        level = descend(&hit);
    }
    false
}

fn press_leaf(el: &AXUIElement, name: &str, depth: u32) -> bool {
    if depth > MAX_DEPTH {
        return false;
    }
    if title(el).as_deref() == Some(name) && role(el).as_deref() == Some("AXMenuItem") {
        return activate(el);
    }
    for child in children(el) {
        if press_leaf(&child, name, depth + 1) {
            return true;
        }
    }
    false
}

/// Menu-bar items contain a menu. The titles we match live on the items inside it.
fn descend(el: &AXUIElement) -> Vec<CFRetained<AXUIElement>> {
    let mut out = Vec::new();
    for child in children(el) {
        if role(&child).as_deref() == Some("AXMenu") {
            out.extend(children(&child));
        } else {
            out.push(child);
        }
    }
    out
}

fn activate(el: &AXUIElement) -> bool {
    limit(el);
    let err = unsafe { el.perform_action(&cf("AXPress")) };
    err == AXError::Success
}

fn element(el: &AXUIElement, name: &str) -> Option<CFRetained<AXUIElement>> {
    copy_value(el, name)?.downcast::<AXUIElement>().ok()
}

fn children(el: &AXUIElement) -> Vec<CFRetained<AXUIElement>> {
    let Some(value) = copy_value(el, "AXChildren") else {
        return Vec::new();
    };
    let Ok(array) = value.downcast::<CFArray>() else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for index in 0..array.count() {
        let ptr = unsafe { array.value_at_index(index) } as *mut CFType;
        let Some(ptr) = NonNull::new(ptr) else {
            continue;
        };
        let retained = unsafe { CFRetained::<CFType>::retain(ptr) };
        if let Ok(item) = retained.downcast::<AXUIElement>() {
            out.push(item);
        }
    }
    out
}

fn title(el: &AXUIElement) -> Option<String> {
    string_attr(el, "AXTitle")
}

fn role(el: &AXUIElement) -> Option<String> {
    string_attr(el, "AXRole")
}

fn string_attr(el: &AXUIElement, name: &str) -> Option<String> {
    let value = copy_value(el, name)?;
    let string = value.downcast::<CFString>().ok()?;
    Some(string.to_string())
}

fn copy_value(el: &AXUIElement, name: &str) -> Option<CFRetained<CFType>> {
    limit(el);
    let mut raw: *const CFType = std::ptr::null();
    let slot = NonNull::new(&mut raw)?;
    let err = unsafe { el.copy_attribute_value(&cf(name), slot) };
    if err != AXError::Success || raw.is_null() {
        return None;
    }
    let ptr = NonNull::new(raw as *mut CFType)?;
    Some(unsafe { CFRetained::from_raw(ptr) })
}

fn limit(el: &AXUIElement) {
    let _ = unsafe { el.set_messaging_timeout(TIMEOUT_SECS) };
}

fn cf(text: &str) -> CFRetained<CFString> {
    CFString::from_str(text)
}
