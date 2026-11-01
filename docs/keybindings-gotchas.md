# Implementation gotchas

Notes from building `configs/karabiner/karabiner.json` and `configs/hammerspoon/` against `keybindings.md`. Each item is something that failed or could not be done the obvious way.

## Karabiner

### `repeat: false` releases the layer key immediately

`to_if_held_down` with `"repeat": false` posts the key-down and the key-up together. That is the wrong shape for a layer: holding Right Command or Right Option would flash F18 or F19 and the layer would disarm before the next key. `halt` on that event does not help: `halt` applies to `to_after_key_up`.

Leave `repeat` unset on F18 and F19 so it stays at its default, enabled. The held key then stays down until the physical key is released.

### `to_if_held_down` waits out the tap timeout

That event is posted only after `basic.to_if_held_down_threshold_milliseconds`. A layer could not arm until 250 ms had passed, so Right Command and Right Option use `to` instead.

The layer hold is a `to` event, which Karabiner 16.3 posts on the physical key-down and releases on the physical key-up. A tap of either modifier is that key-down and key-up with no other key. The brief F18 or F19 press is a no-op: Hammerspoon arms the layer and disarms it, and the overlay timer is the same 250 ms, so a tap does not draw the overlay.

### The running grabber ignores edits to the symlink target

`~/.config/karabiner/karabiner.json` points at `configs/karabiner/karabiner.json`. `karabiner_core_service` watches the path under `~/.config/karabiner/`. Writing the target file produced no `Load` line in `/var/log/karabiner/core_service.log`, so the process kept the previous rules and the 250 ms hold remained.

A directory change next to the symlink makes it reload. Rewriting the symlink with `ln -sfn` and touching that directory logged `core_configuration is updated`. Check that log after a Karabiner edit before deciding the new rules are wrong.

### Fn is not remapped

A tap of Fn changes the input source, and Fn+arrow is Home, End, Page Up, and Page Down. An earlier rule posted the globe key on a tap and had to guard against recursion: the posted globe key is another Fn press (`apple_vendor_top_case_key_code: keyboard_fn`), so it matched the same manipulator.

## Hammerspoon

### Posted shortcuts come back through the tap

Events posted with `hs.eventtap` are visible to the same tap. Every posted key is stamped with `eventSourceUserData` `0x4B424C31`, and `handle` returns those events unchanged. A two-stroke shortcut is two marked keystrokes 20 ms apart so the app sees a chord rather than one merged press.

`Keybindings.tap` is a global. A tap stored only in a local is collected and stops.

### Window manager commands cannot run inside the tap

The tap callback holds every key on the system until it returns. `hs.execute` waits for the command to exit, and a window manager can take seconds when it waits on an app that is slow to answer it. Long enough, and macOS disables the tap, so a layer key-up can be missed and the layer stays armed.

Commands go through `hs.task` on a queue that runs one command at a time in key order. A command still running after 5 seconds is terminated. Exit 1 is OmniWM declining, such as focus with nothing on that side, and is not logged. Exit 2 means OmniWM is not running or IPC is off, and is logged.

### OmniWM's settings file is strict

`configs/omniwm/settings.toml` is linked file by file, because OmniWM writes `settings.toml.pre-v<N>` and `settings.toml.corrupt` backups next to it. On OmniWM's `main`, saving from the Settings window while the file is invalid moves it to `settings.toml.corrupt` and writes the running settings in its place, which through the link replaces the repo's copy. `git diff` shows that, and `git checkout` puts the file back. It is the v0.7.6 schema, `schemaVersion = 4`. OmniWM's docs on `main` describe version 5, which v0.7.6 treats as unsupported and refuses to load or edit. A missing required key, or an unknown value for a string key, rejects the whole file. OmniWM then runs with its defaults, which have `ipcEnabled = false` and every hotkey on, so the layers stop working. Diagnostics in the status menu names the key. Re-check the file against the release's `CanonicalTOMLConfig` and `SettingsExport` before bumping the cask.

The Settings window writes back through the symlink into the repo. It keeps unknown keys but sorts the file and drops comments, so the file has none; the reasons live in `keybindings.md`.

`hotkeysEnabled = false` and `hotkeys = []` leave every key to Hammerspoon. An action left out of `hotkeys` is unassigned, not defaulted.

### OmniWM and AeroSpace cannot both run

OmniWM refuses to manage windows while AeroSpace is running. It also needs "Displays have separate Spaces" on, which AeroSpace wanted off, and Accessibility and Input Monitoring. Start at Login is a macOS login item, not a key in `settings.toml`.

### iTerm's menus

Pane and divider actions try the menu path and then the leaf title, because the View, Window → Select Split Pane, and Window → Split Pane parents have differed across versions.

### Cursor is a second bundle id on the VS Code table

Cursor's id on this Mac is `com.todesktop.230313mzl4w4u92`, from `CFBundleIdentifier` in `/Applications/Cursor.app`. It is assigned the same table object as `com.microsoft.VSCode`. An app with no row ignores the App layer.

### Overlay columns overlapped

The verb frame used about the first 0.58 of the row while the key frame started at 0.42, so the two strings drew on top of each other. The key frame now starts at `verbW`.

### Password fields are invisible to the tap

A session event tap receives nothing while secure input is on, which is the state of a password field. Querying the accessibility tree from inside the tap can deadlock, so there is no password-field exception. Those keystrokes never reach the grammar.

### Raycast and Contexts

Keys that Hammerspoon posts reach the focused window but never trigger a global hotkey. Flags on the letter, a full modifier-down, letter, modifier-up sequence, and `hs.eventtap.keyStroke` all fail, even against an `hs.hotkey` bound in Hammerspoon itself. `hs.eventtap.event.newKeyEventSequence` is also broken: it keeps only the first modifier and sets no flags. Karabiner-EventViewer reads the keyboard before Hammerspoon, so it shows `F19`+`P` for the operating-system layer and never the posted keys.

Run command opens Raycast with `open -g -b com.raycast.macos`. With Raycast already running, that shows the search bar, and the bar takes keys. Without `-g`, Raycast also becomes the active app and stays active with no window after Escape closes the bar, so typed keys go nowhere.

Contexts has no URL scheme or AppleScript dictionary. Open document used to send its hotkey through System Events. It is now OmniWM's window list, `omniwmctl command open-command-palette windows`, whose Shift+Return summons the window next to the focused one. Holding Fn and typing is a Hammerspoon search that focuses a match on release. Letting go of the globe key is a flags change, not a key-up, so the tap watches `flagsChanged` to close the search. Escape closes it too, including after Fn is already up. The Fn key itself is passed through, so a tap still changes the input source and Fn+arrow is still Home, End, Page Up, and Page Down. Swallowing Fn the way F19 is swallowed breaks both of those.

Raycast stores that chord as the defaults string `raycastGlobalHotkey`. Key code 35 is `P`. The previous value was `Shift-Control-Option-Command-49`, Hyper-Shift-Space. The Application Support directory is encrypted SQLite (clipboard, AI, activity) plus window frames and install ids in the preferences plist. None of that is linked, and no Nix module sets the hotkey string either. It is machine state.

Contexts stores the switcher chord as an `NSKeyedArchiver` blob, `CTPreferenceSearchShortcutModal`, inside `com.contextsformac.Contexts`. Key code 31 is `O`. Modifier flags `1835008` are Command, Option, and Control. The previous flags were `1966080`, which adds Shift. The same plist holds usage counters, a Sparkle schedule, and App Center install ids, and Contexts rewrites it while running. The license file and Realm database sit beside it. That domain stays on the machine. A running copy of either app keeps the old hotkey in memory and writes it back on quit, so the preference is written while the app is not running.

### Chrome tabs in the Fn search

Chrome's AppleScript window id is not the macOS window id. OmniWM reports the macOS id as `windowId` beside its own `id`, which is what `window` commands take and is only valid until OmniWM restarts. The search matches a tab to its window by the window bounds, within a few pixels. `tab` inside `tell application "Google Chrome"` is Chrome's tab class, so a tab character has to be `ASCII character 9`. A tell to Chrome launches it when it is not running, so the query is skipped unless Chrome is already running. Selecting a tab needs Hammerspoon allowed to control Google Chrome under Automation. Without that permission the window still focuses and the tab stays as it was.

OmniWM's palette lists windows only, so the Fn search is the one place tabs appear. `--sort` and `focus-rank` from OmniWM's `main` docs are not in v0.7.6, so the Fn search orders by `hs.window.orderedWindows`.

### OmniWM's own panels take the keyboard

The window list (O) and Overview (V) are OmniWM panels. Once open they handle their own keys, but only keys the tap lets through reach them. While Right Option is held the layer still swallows every key, so release it before typing. A locked layer would keep swallowing them, so both rows are marked `unlocks` and end the lock. Show scratchpad (`Z`) is marked `unlocks` for the same reason: a locked layer would swallow what is typed into the window it focuses. The workspace map Hammerspoon used to draw under the layer overlay was removed in favor of Overview, which cannot be a peek while the layer is held.

## Install

`nix/home/links.nix` links `~/.hammerspoon` to `configs/hammerspoon`, `~/.config/karabiner/karabiner.json` to `configs/karabiner/karabiner.json`, and `~/.config/omniwm/settings.toml` to `configs/omniwm/settings.toml`. An older copy of `karabiner.json` that mapped Caps Lock to Hyper or Escape has been deleted, so a rebuild cannot bring that profile back.
