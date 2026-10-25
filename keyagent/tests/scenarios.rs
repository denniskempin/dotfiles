use keyagent::{
    fixture_grammar, generate, load_dir, repo_config_dir, Flags, Mod, World, WorldOpts, APP,
};
use std::sync::Arc;

fn none() -> Flags {
    Flags::empty()
}
fn shift() -> Flags {
    Flags::from_mods(&[Mod::Shift])
}
fn cmd() -> Flags {
    Flags::from_mods(&[Mod::Cmd])
}
fn ctrl() -> Flags {
    Flags::from_mods(&[Mod::Ctrl])
}
fn hyper() -> Flags {
    Flags::from_mods(&[Mod::Cmd, Mod::Alt, Mod::Ctrl])
}

fn world(opts: WorldOpts) -> World {
    World::new(Arc::new(fixture_grammar()), opts)
}

fn front(bundle: &str) -> WorldOpts {
    WorldOpts {
        front: Some(bundle.to_string()),
        ..WorldOpts::default()
    }
}

fn expect(w: &mut World, expected: &[&str]) {
    w.settle();
    assert_eq!(w.effects(), expected);
}

fn expect_now(w: &mut World, expected: &[&str]) {
    assert_eq!(w.effects(), expected);
}

fn clean(w: &World) {
    assert!(
        w.problems().is_empty() && w.warnings().is_empty(),
        "problems {:?}\nwarnings {:?}",
        w.problems(),
        w.warnings()
    );
}

const HOTKEY: &str = "system-events cmd+alt+ctrl+o";

#[test]
fn real_config_loads_without_warnings() {
    let grammar = load_dir(&repo_config_dir()).expect("grammar");
    assert!(grammar.warnings.is_empty(), "{:?}", grammar.warnings);
    let w = World::new(Arc::new(grammar), WorldOpts::default());
    clean(&w);
}

#[test]
fn keys_pass_through_with_no_layer_held() {
    let mut w = world(front(APP));
    let (down, up) = w.press("left", none());
    assert!(down && up);
    expect(&mut w, &[]);
    clean(&w);
}

#[test]
fn caps_lock_sends_the_verb_to_the_operating_system() {
    let mut w = world(front(APP));
    assert!(!w.down("f18", none()));
    let (down, up) = w.press("left", none());
    assert!(!down && !up);
    w.up("f18", none());
    expect(&mut w, &["aerospace go left"]);
    clean(&w);
}

#[test]
fn fn_sends_the_verb_to_the_front_app() {
    let mut w = world(front(APP));
    w.down("f19", none());
    w.press("left", none());
    w.up("f19", none());
    expect(&mut w, &["press cmd+left"]);
    clean(&w);
}

#[test]
fn shift_selects_the_shift_row() {
    let mut w = world(front(APP));
    w.down("f18", none());
    w.press("left", shift());
    w.up("f18", none());
    expect(&mut w, &["aerospace carry left"]);
    clean(&w);
}

#[test]
fn an_unlisted_app_ignores_the_app_layer_but_still_swallows_keys() {
    let mut w = world(front(keyagent::UNLISTED));
    w.down("f19", none());
    assert_eq!(w.press("left", none()), (false, false));
    w.up("f19", none());
    expect(&mut w, &[]);
    clean(&w);
}

#[test]
fn unbound_keys_are_swallowed() {
    let mut w = world(front(APP));
    w.down("f18", none());
    assert_eq!(w.press("z", none()), (false, false));
    w.up("f18", none());
    expect(&mut w, &[]);
    clean(&w);
}

#[test]
fn command_combinations_are_swallowed() {
    let mut w = world(front(APP));
    w.down("f18", none());
    assert_eq!(w.press("left", cmd()), (false, false));
    assert_eq!(w.press("left", ctrl()), (false, false));
    w.up("f18", none());
    expect(&mut w, &[]);
    clean(&w);
}

#[test]
fn autorepeat_runs_nothing() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.down("left", none());
    assert!(!w.autorepeat("left", none()));
    w.autorepeat("left", none());
    w.up("left", none());
    w.up("f18", none());
    expect(&mut w, &["aerospace go left"]);
    clean(&w);
}

#[test]
fn a_key_held_across_release_keeps_its_key_up_swallowed() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.down("left", none());
    w.up("f18", none());
    assert!(!w.up("left", none()));
    assert_eq!(w.press("left", none()), (true, true));
    expect(&mut w, &["aerospace go left"]);
    clean(&w);
}

#[test]
fn space_locks_the_layer_and_escape_unlocks_it() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("space", none());
    w.up("f18", none());
    assert_eq!(w.press("left", none()), (false, false));
    expect(&mut w, &["aerospace go left"]);
    w.press("escape", none());
    assert_eq!(w.press("left", none()), (true, true));
    expect(&mut w, &[]);
    clean(&w);
}

#[test]
fn with_both_layers_held_the_last_one_pressed_wins() {
    let mut w = world(front(APP));
    w.down("f18", none());
    w.down("f19", none());
    w.press("left", none());
    expect(&mut w, &["press cmd+left"]);
    w.up("f19", none());
    w.press("left", none());
    w.up("f18", none());
    expect(&mut w, &["aerospace go left"]);
    clean(&w);
}

#[test]
fn a_chord_takes_one_key_then_the_layer_is_back() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("s", none());
    w.press("right", none());
    w.press("right", none());
    w.up("f18", none());
    expect(&mut w, &["aerospace pick right", "aerospace go right"]);
    clean(&w);
}

#[test]
fn a_chord_runs_on_the_layer_that_started_it() {
    let mut w = world(front(APP));
    w.down("f19", none());
    w.press("s", none());
    w.press("right", none());
    w.up("f19", none());
    expect(&mut w, &["press alt+right"]);
    clean(&w);
}

#[test]
fn an_unbound_key_shift_or_escape_ends_a_chord() {
    let enders = [("z", none()), ("right", shift()), ("escape", none())];
    for (key, flags) in enders {
        let mut w = world(WorldOpts::default());
        w.down("f18", none());
        w.press("s", none());
        w.press(key, flags);
        w.press("right", none());
        w.up("f18", none());
        expect(&mut w, &["aerospace go right"]);
        clean(&w);
    }
}

#[test]
fn a_chord_takes_its_key_after_the_layer_is_released() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("s", none());
    w.up("f18", none());
    assert_eq!(w.press("right", none()), (false, false));
    assert_eq!(w.press("right", none()), (true, true));
    expect(&mut w, &["aerospace pick right"]);
    clean(&w);
}

#[test]
fn posted_keys_are_marked_so_the_tap_lets_them_through() {
    let mut w = world(front(APP));
    w.down("f19", none());
    w.press("left", none());
    w.up("f19", none());
    expect(&mut w, &["press cmd+left"]);
    clean(&w);
}

#[test]
fn a_sequence_posts_its_strokes_with_a_gap() {
    let mut w = world(front(APP));
    w.down("f19", none());
    w.press("k", none());
    expect_now(&mut w, &["press cmd+k"]);
    w.up("f19", none());
    expect(&mut w, &["press cmd+j"]);
    clean(&w);
}

#[test]
fn menu_actions_run_after_the_tap_returns() {
    let mut w = world(front(APP));
    w.down("f19", none());
    w.press("m", none());
    expect_now(&mut w, &[]);
    w.up("f19", none());
    expect(
        &mut w,
        &["menu Edit > First", "menu Edit > Second", "menu Third"],
    );
    clean(&w);
}

#[test]
fn menu_actions_stop_at_the_first_path_that_exists() {
    let mut menus = std::collections::HashSet::new();
    menus.insert("Edit > Second".to_string());
    let mut w = world(WorldOpts {
        front: Some(APP.to_string()),
        menus,
        ..WorldOpts::default()
    });
    w.down("f19", none());
    w.press("m", none());
    w.up("f19", none());
    expect(&mut w, &["menu Edit > First", "menu Edit > Second"]);
    clean(&w);
}

#[test]
fn a_launch_action_reopens_the_app_by_bundle_id() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("p", none());
    w.up("f18", none());
    w.settle();
    let effects = w.effects();
    assert_eq!(effects.len(), 1);
    assert!(
        effects[0].starts_with("open ") && effects[0].ends_with("com.example.Launcher"),
        "{}",
        effects[0]
    );
    clean(&w);
}

#[test]
fn aerospace_commands_run_one_at_a_time() {
    let mut w = world(WorldOpts {
        latency: 1.0,
        ..WorldOpts::default()
    });
    w.down("f18", none());
    w.press("left", none());
    w.press("right", none());
    w.up("f18", none());
    expect_now(&mut w, &["aerospace go left"]);
    expect(&mut w, &["aerospace go right"]);
    clean(&w);
}

#[test]
fn a_hung_aerospace_command_is_terminated() {
    let mut w = world(WorldOpts {
        hang: Some(Box::new(|args| {
            args.last().map(String::as_str) == Some("left")
        })),
        ..WorldOpts::default()
    });
    w.down("f18", none());
    w.press("left", none());
    w.press("right", none());
    w.up("f18", none());
    expect_now(&mut w, &["aerospace go left"]);
    expect(
        &mut w,
        &["terminate aerospace go left", "aerospace go right"],
    );
    assert_eq!(w.take_warnings().len(), 1);
    clean(&w);
}

#[test]
fn a_hotkey_gets_past_the_layer_that_is_still_held() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("o", none());
    w.advance(0.5);
    expect_now(&mut w, &[HOTKEY]);
    w.up("f18", none());
    clean(&w);
}

#[test]
fn a_hotkey_sent_twice_gets_through_twice() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("o", none());
    w.press("o", none());
    w.advance(0.5);
    w.up("f18", none());
    expect(&mut w, &[HOTKEY, HOTKEY]);
    clean(&w);
}

#[test]
fn the_typed_key_still_reaches_the_layer_while_its_hotkey_is_expected() {
    let mut w = world(WorldOpts {
        deliver_hotkeys: false,
        ..WorldOpts::default()
    });
    w.down("f18", none());
    w.press("o", none());
    assert_eq!(w.press("o", none()), (false, false));
    w.up("f18", none());
    expect(&mut w, &[HOTKEY, HOTKEY]);
    clean(&w);
}

#[test]
fn an_expected_hotkey_that_never_arrives_stops_passing() {
    let mut w = world(WorldOpts {
        deliver_hotkeys: false,
        ..WorldOpts::default()
    });
    w.down("f18", none());
    w.press("o", none());
    assert!(w.down("o", hyper()));
    w.up("o", hyper());
    w.press("o", none());
    w.advance(30.0);
    assert!(!w.down("o", hyper()));
    w.up("f18", none());
    clean(&w);
}

#[test]
fn the_overlay_appears_after_a_delay_and_hides_on_release() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.advance(0.0);
    assert!(!w.overlay().visible);
    w.advance(1.0);
    assert!(w.overlay().visible);
    assert_eq!(w.overlay().title, "OS");
    w.up("f18", none());
    assert!(!w.overlay().visible);
    clean(&w);
}

#[test]
fn a_quick_press_never_shows_the_overlay() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("left", none());
    w.up("f18", none());
    w.settle();
    assert_eq!(w.overlay().shows, 0);
    w.effects();
    clean(&w);
}

#[test]
fn a_locked_layer_keeps_its_overlay_up() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("space", none());
    w.up("f18", none());
    w.advance(1.0);
    assert!(w.overlay().visible);
    assert!(
        w.overlay().title.starts_with("OS") && w.overlay().title.contains("locked"),
        "{}",
        w.overlay().title
    );
    w.press("left", none());
    w.advance(1.0);
    assert!(w.overlay().visible);
    w.press("escape", none());
    assert!(!w.overlay().visible);
    w.effects();
    clean(&w);
}

#[test]
fn a_chord_shows_its_own_overlay() {
    let mut w = world(WorldOpts::default());
    w.down("f18", none());
    w.press("s", none());
    w.advance(1.0);
    assert_eq!(w.overlay().title, "Pick");
    w.press("escape", none());
    assert!(!w.overlay().visible);
    w.up("f18", none());
    clean(&w);
}

#[test]
fn snapshot_matches() {
    let grammar = Arc::new(load_dir(&repo_config_dir()).expect("grammar"));
    let (generated, problems) = generate(Arc::clone(&grammar));
    assert!(problems.is_empty(), "{problems:?}");
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/snapshot.txt");
    let saved = std::fs::read_to_string(&path).expect("snapshot");
    if saved != generated {
        panic!("snapshot differs:\n{}", first_diff(&saved, &generated));
    }
}

fn first_diff(old: &str, new: &str) -> String {
    let old: Vec<&str> = old.lines().collect();
    let new: Vec<&str> = new.lines().collect();
    let mut out = String::new();
    let mut shown = 0;
    let limit = old.len().max(new.len());
    for i in 0..limit {
        let a = old.get(i).copied();
        let b = new.get(i).copied();
        if a != b {
            if let Some(line) = a {
                out.push_str(&format!("-{line}\n"));
            }
            if let Some(line) = b {
                out.push_str(&format!("+{line}\n"));
            }
            shown += 1;
            if shown > 40 {
                out.push_str("...\n");
                break;
            }
        }
    }
    out
}
