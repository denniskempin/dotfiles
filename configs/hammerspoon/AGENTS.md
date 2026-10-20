# Testing keybinding changes

`docs/keybindings.md` is the spec and `docs/keybindings-gotchas.md` records how the live system actually behaves. Read both before changing this directory.

Every change gets the offline suite. Changes that depend on macOS, an app, or AeroSpace also get a live check. `~/.hammerspoon` links to `configs/hammerspoon`, so a Hammerspoon reload picks up edits. No `darwin-rebuild` is needed, and the drift check in `.cursor/rules` does not apply to a reload.

## Offline suite

```sh
lua configs/hammerspoon/test/run.lua            # scenarios, then the snapshot
lua configs/hammerspoon/test/run.lua --update   # rewrite snapshot.txt
```

It runs in under a second with Homebrew's `lua` (5.4, like Hammerspoon), and needs no permissions.

- `snapshot.txt` lists every key, with and without Shift, in each layer, app, and chord, with what it did. A failing snapshot prints a diff grouped by section. Read the diff. Run `--update` only when every changed line is intended, and commit the snapshot with the change.
- `scenarios.lua` covers the framework: layers, lock and unlock, chords, each action kind, the AeroSpace queue and its timeout, the hotkey pass-through, and the overlay. It runs against the made-up grammar in `fixture.lua`, not the real bindings, and checks timing as before and after rather than exact delays. A binding change or a retuned delay should only move the snapshot. Keep it that way: per-app and per-key detail belongs in the snapshot, not in a scenario.
- A test also fails when the config logs a warning the test does not take, or when the config's own tap swallows a key it posted.

When fixing a framework bug, add a scenario that fails before the fix. When fixing a binding, the snapshot diff is the test.

A world (`test/world.lua`) loads the config fresh against a fake `hs`. Scenarios pass the fixture as `bindings` and `targets`:

```lua
local w = world(t, { front = fixture.APP })  -- also latency, hang, deliverHotkeys, menus
w:down("f18")                       -- Caps Lock held
w:press("left", { shift = true })   -- returns whether down and up reached apps
w:up("f18")
t.expect(w, { "aerospace carry left" })  -- runs every timer first; t.expectNow does not
```

A new action kind or layer rule gets a fixture verb, not a real binding.

Effects are strings such as `press cmd+k`, `aerospace focus ... left`, `open -g -b com.raycast.macos`, `system-events cmd+alt+ctrl+o`, and `menu View > Open Quickly`.

The fake follows what the live system was seen to do, not Hammerspoon's docs. A missing `hs` function raises an error that names it. Add it to `world.lua` only after checking the real behavior live. `keycodes.lua` is the real `hs.keycodes.map`. Regenerate it with:

```sh
/opt/homebrew/bin/hs -c 'local out = {} for code = 0, 127 do local n = hs.keycodes.map[code] if type(n) == "string" then out[#out + 1] = ("  [%d] = %q,"):format(code, n) end end return table.concat(out, "\n")' 2>/dev/null
```

The suite cannot tell whether a key triggers a global hotkey, whether an app honors a shortcut or has a menu item, or what AeroSpace does with a command. Those need the live system.

## Live system

### Running Lua in Hammerspoon

`init.lua` loads `hs.ipc`, so `/opt/homebrew/bin/hs -c '<lua>'` runs code in the live config and prints the return value.

- Shell commands that talk to Hammerspoon or AeroSpace need the sandbox disabled (`required_permissions: ["all"]`).
- Output includes `-- Loading extension` lines. Filter them with `grep -v "Loading extension"`.
- Code that posts events or reloads must run on a timer (`hs.timer.doAfter(0, ...)`). Posting inside `hs -c` itself prints "hs.ipc already recursing". Anything asynchronous finishes after `hs -c` returns, so sleep, then query.

`test/live.lua` wraps the common cases. Load it after every reload:

```sh
q() { /opt/homebrew/bin/hs -c "$1" 2>&1 | grep -v "Loading extension"; }
q 'hs.timer.doAfter(0.1, hs.reload) return "reloading"'; sleep 2.5
q 'return dofile(hs.configdir .. "/test/live.lua")'
q 'return Live.check()'   # config loaded, tap enabled, keybindings warnings since the reload
```

### Triggering a binding

`Live.press(layer, key, mods)` posts an F18 or F19 hold around the key, with `layer` "os", "app", or nil. The events are unmarked, so the config's tap handles them exactly like typed keys:

```sh
q 'return Live.press("os", "p")'; sleep 1          # Caps Lock+P
q 'return Live.press("app", "]", { "shift" })'     # Fn+Shift+]
```

Karabiner is not involved. Tapping Caps Lock for Escape, tapping Fn for the globe key, and holding a real key need a person (see below).

This is the user's desktop, and the user may be working on it:

- The front app is usually the agent's editor, Cursor. An App-layer press acts on it. Use `Live.focus(bundleID)` first, sleep, and check `Live.front()`.
- Posted keys go to whatever has focus at that moment. Check the front app right before pressing.
- System-layer keys move, resize, close, and rearrange the user's real windows. App-layer `X` closes a tab or editor. Do not run verbs that change windows without asking. Prefer bindings whose effect can be read and undone: focus, switch, jump, Raycast. Put things back afterwards.

### Checking the result

AeroSpace state, for before and after:

```sh
aerospace list-windows --focused --format '%{app-bundle-id} | %{window-title} | %{workspace}'
aerospace list-workspaces --focused
```

| Action | How to check it |
| --- | --- |
| AeroSpace | The two queries above, before and after |
| Key posted to an app | `Live.front()` before and after. The window title follows the Chrome tab and the editor in VS Code or Cursor |
| Menu item | `Live.menu({ "View", "Open Quickly" })` with the app in front. `missing` means the path does not exist in that app version |
| Raycast | `Live.windows("Raycast")` shows `750x64 layer=8` while the bar is open. While the bar has keys, `Live.front()` shows the window "Main Window". `Live.press(nil, "escape")` closes it |
| Contexts | It must be running: `pgrep -x Contexts`. Its switcher window has not been identified; at launch Contexts shows an 840×658 window titled "Contexts", which is not the switcher. Ask the user whether the switcher opened |
| Global hotkey delivery | `q 'return Live.probe({ "cmd", "alt", "ctrl" }, "f13")'`, send the hotkey through the code path under test, then `q 'return Live.hits("cmd+alt+ctrl+f13")'` |

`Live.reset()` deletes probes. A reload clears all `Live` state.

### Things that mislead

- Karabiner-EventViewer reads the keyboard before Hammerspoon. It shows `F18`+`P` and never shows what Hammerspoon swallows or posts. It is only useful for checking Karabiner itself.
- Keys posted from Hammerspoon reach windows but never trigger a global hotkey, including an `hs.hotkey` in Hammerspoon. System Events keystrokes do.
- `hs.eventtap.event.newKeyEventSequence` keeps only the first modifier.
- `osascript` keystrokes run from the agent's shell fail with "not allowed to send keystrokes", because Accessibility belongs to Hammerspoon. Run them from Hammerspoon with `hs.task`.
- `open -b` without `-g` activates the app, so focus does not come back when its panel closes.

### Asking the user

When a change touches Karabiner, the Caps Lock or Fn handling, or anything the table above cannot check, ask the user to press the keys and report. Keep the list short and specific, for example:

1. Tap Caps Lock: Escape. Hold it for a moment: the System overlay.
2. Tap Fn: the globe key. Hold it: the App overlay.
3. Caps Lock+Space, then an arrow, then Escape: locked focus, then unlocked.
4. Caps Lock+P: Raycast's bar, and Escape puts focus back. Caps Lock+O: the Contexts switcher.
5. The changed binding, in each app it affects.
