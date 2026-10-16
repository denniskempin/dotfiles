# Implementation gotchas

Notes from building `karabiner.json` and `hammerspoon/` against `keybindings.md`. Each item is something that failed or could not be done the obvious way.

## Karabiner

### `repeat: false` releases the layer key immediately

`to_if_held_down` with `"repeat": false` posts the key-down and the key-up together. Holding Caps Lock or Fn flashed F18 or F19 and the layer disarmed before the next key. `halt` on that event does not help: `halt` applies to `to_after_key_up`.

Leave `repeat` unset so it stays at its default, enabled. The held key then stays down until the physical key is released.

### `to_if_held_down` waits out the tap timeout

That event is posted only after `basic.to_if_held_down_threshold_milliseconds`. The layer could not arm until 250 ms had passed.

The hold is a `to` event, which Karabiner 16.3 posts on the physical key-down and releases on the physical key-up. The tap is `to_if_alone`, posted on key-up when no other key was pressed and the hold was shorter than `basic.to_if_alone_timeout_milliseconds`. On a tap the order is F18 or F19 down, then that key-up, then Escape or the globe key. The brief F18 or F19 press is a no-op: Hammerspoon arms the layer and disarms it before Escape arrives, and the overlay timer is the same 250 ms, so a tap does not draw the overlay.

### The running grabber ignores edits to the symlink target

`~/.config/karabiner/karabiner.json` points at `keybindings/karabiner.json`. `karabiner_core_service` watches the path under `~/.config/karabiner/`. Writing the target file produced no `Load` line in `/var/log/karabiner/core_service.log`, so the process kept the previous rules and the 250 ms hold remained.

A directory change next to the symlink makes it reload. Rewriting the symlink with `ln -sfn` and touching that directory logged `core_configuration is updated`. Check that log after a Karabiner edit before deciding the new rules are wrong.

### A posted globe key is another Fn press

The native tap is `apple_vendor_top_case_key_code: keyboard_fn` (Event Viewer label "fn (globe)"). The rule's `from` is `key_code: fn`, so the posted globe key matches the same manipulator and would recurse.

`to_if_alone` sets the variable `posting_globe` to 1, posts the globe key, then sets it back to 0. The manipulator runs only under `variable_unless posting_globe == 1`.

## Hammerspoon

### Posted shortcuts come back through the tap

Events posted with `hs.eventtap` are visible to the same tap. Every posted key is stamped with `eventSourceUserData` `0x4B424C31`, and `handle` returns those events unchanged. A two-stroke shortcut is two marked keystrokes 20 ms apart so the app sees a chord rather than one merged press.

`Keybindings.tap` is a global. A tap stored only in a local is collected and stops.

### AeroSpace commands cannot run inside the tap

The tap callback holds every key on the system until it returns. `hs.execute` waits for the command to exit: 10 to 20 ms per `aerospace` call when AeroSpace is idle, and seconds when AeroSpace waits on an app that is slow to answer it. Long enough, and macOS disables the tap, so a layer key-up can be missed and the layer stays armed.

Commands go through `hs.task` on a queue that runs one command at a time in key order. A command still running after 5 seconds is terminated.

`workspace next` and `move-node-to-workspace next` pass `--no-stdin`. Without it AeroSpace may take its workspace list from stdin, and `hs.task` leaves stdin open as a pipe.

### iTerm's menus

Pane and divider actions try the menu path and then the leaf title, because the View, Window → Select Split Pane, and Window → Split Pane parents have differed across versions.

### Cursor is a second bundle id on the VS Code table

Cursor's id on this Mac is `com.todesktop.230313mzl4w4u92`, from `CFBundleIdentifier` in `/Applications/Cursor.app`. It is assigned the same table object as `com.microsoft.VSCode`. An app with no row ignores the App layer.

### Overlay columns overlapped

The verb frame used about the first 0.58 of the row while the key frame started at 0.42, so the two strings drew on top of each other. The key frame now starts at `verbW`.

### Password fields are invisible to the tap

A session event tap receives nothing while secure input is on, which is the state of a password field. Querying the accessibility tree from inside the tap can deadlock, so there is no password-field exception. Those keystrokes never reach the grammar.

### Raycast and Contexts

Keys that Hammerspoon posts reach the focused window but never trigger a global hotkey. Flags on the letter, a full modifier-down, letter, modifier-up sequence, and `hs.eventtap.keyStroke` all fail, even against an `hs.hotkey` bound in Hammerspoon itself. `hs.eventtap.event.newKeyEventSequence` is also broken: it keeps only the first modifier and sets no flags. Karabiner-EventViewer reads the keyboard before Hammerspoon, so it shows `F18`+`P` and never the posted keys.

Run command opens Raycast with `open -g -b com.raycast.macos`. With Raycast already running, that shows the search bar, and the bar takes keys. Without `-g`, Raycast also becomes the active app and stays active with no window after Escape closes the bar, so typed keys go nowhere.

Contexts has no URL scheme or AppleScript dictionary, so Open document still goes through its Hyper+`O` hotkey (Command-Option-Control). The keystroke comes from System Events through `osascript`, run with `hs.task`, and that does trigger the hotkey. The first run asks for permission for Hammerspoon to control System Events. System Events keys reach the tap like typed keys, and the armed layer would swallow them. `actions.isExpected` lets through the expected key code with Command, Option, and Control set, until its key-up or for 2 seconds. A typed `O` has none of those flags, so it still reaches the layer. Contexts must be running. It is a login item, and with no copy running the key does nothing.

Raycast stores that chord as the defaults string `raycastGlobalHotkey`. Key code 35 is `P`. The previous value was `Shift-Control-Option-Command-49`, Hyper-Shift-Space. The Application Support directory is encrypted SQLite (clipboard, AI, activity) plus window frames and install ids in the preferences plist. None of that is linked. The hotkey string is the piece in `darwin/home.nix`.

Contexts stores the switcher chord as an `NSKeyedArchiver` blob, `CTPreferenceSearchShortcutModal`, inside `com.contextsformac.Contexts`. Key code 31 is `O`. Modifier flags `1835008` are Command, Option, and Control. The previous flags were `1966080`, which adds Shift. The same plist holds usage counters, a Sparkle schedule, and App Center install ids, and Contexts rewrites it while running. The license file and Realm database sit beside it. That domain stays on the machine. A running copy of either app keeps the old hotkey in memory and writes it back on quit, so the preference is written while the app is not running.

## Install

`darwin/home.nix` links `~/.hammerspoon` and `~/.config/karabiner/karabiner.json` at the files in this directory. The previous link target, `darwin/config/karabiner.json`, maps Caps Lock to Hyper or Escape. A rebuild that still pointed there would put that profile back. That file is still in the repo and is not linked.
