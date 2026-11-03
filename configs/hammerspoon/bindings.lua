-- The layer grammar: which key runs which verb, and what the overlay shows.
--
-- Both layers read the same rows. Right Option sends the verb to the
-- operating system and Right Command sends it to the front app; targets.lua
-- says what each verb does there. A row with `layer` exists on that layer
-- only.
--
-- keys      one key, a list of keys, or a map from key to argument. With a
--           list the argument is the key name, or `arg(key)` when set.
-- shift     the row matches with Shift held, instead of without it.
-- verb      the field to run on the target.
-- chord     the chord, from `chords` below, that this key starts.
-- run       a command in actions.commands, the same for every app.
-- unlocks   the key ends a lock, because it opens something that takes the
--           keys that follow.
-- label     the overlay line, with `hint` on the right. A row without a
--           label still runs and is not drawn. On the App layer the line
--           comes from that app's legend in targets.lua when it has one.

local arrows = { "left", "down", "up", "right" }
local across = { "left", "right" }
local along = { "down", "up" }

-- Workspaces 1–5, the only ones settings.toml defines. The value is the
-- workspace's raw name, which is also its display name.
local workspaces = { z = "1", x = "2", c = "3", v = "4", b = "5" }

local step = { [";"] = "prev", ["'"] = "next" }

return {
  title = { os = "System", app = "App" },

  -- Each inner list is one overlay column. A column with no row for the
  -- active layer is left out. On the App layer a row the front app cannot
  -- run is left out too.
  layer = {
    {
      name = "Tiles",
      { keys = across, layer = "os", verb = "focus", label = "Focus column", hint = "← →" },
      { keys = along, layer = "os", verb = "focus", label = "Focus workspace", hint = "↑ ↓" },
      { keys = across, layer = "os", shift = true, verb = "move", label = "Move window", hint = "⇧ ← →" },
      { keys = along, layer = "os", shift = true, verb = "move", label = "Move to workspace", hint = "⇧ ↑ ↓" },
      { keys = arrows, layer = "app", verb = "focus", label = "Focus tile", hint = "← ↓ ↑ →" },
      { keys = arrows, layer = "app", shift = true, verb = "move", label = "Move tile", hint = "⇧ ← ↓ ↑ →" },
      { keys = "return", verb = "zoom", label = "Zoom tile", hint = "↩" },
      -- X is workspace 2, so the operating system closes with Q.
      { keys = "q", layer = "os", verb = "close", label = "Close tile", hint = "Q" },
      { keys = "x", layer = "app", verb = "close", label = "Close tile", hint = "X" },
      { keys = "g", layer = "app", chord = "split", label = "Split tile", hint = "G then arrow" },
      { keys = "s", layer = "os", verb = "size", label = "Size tile", hint = "S" },
    },
    {
      name = "Slots",
      { keys = step, layer = "app", verb = "switch", label = "Switch slot", hint = ";  '" },
      { keys = workspaces, layer = "os", verb = "jump", label = "Jump to workspace", hint = "Z X C V B" },
      { keys = step, layer = "app", shift = true, verb = "send", label = "Send to slot", hint = "⇧ ;  '" },
      { keys = workspaces, layer = "os", shift = true, verb = "sendNamed", label = "Send to workspace", hint = "⇧ Z X C V B" },
    },
    {
      name = "Other",
      { keys = { ["["] = "back", ["]"] = "forward" }, layer = "os", verb = "history",
        label = "Last window, workspace", hint = "[  ]" },
      { keys = { ["["] = "back", ["]"] = "forward" }, layer = "app", verb = "history",
        label = "Walk history", hint = "[  ]" },
      { keys = "p", verb = "command", label = "Run command", hint = "P" },
      { keys = "f", verb = "open", unlocks = true, label = "Open document", hint = "F" },
      { keys = "t", layer = "os", verb = "quake", unlocks = true, label = "Quake terminal", hint = "T" },
      { keys = "d", layer = "os", verb = "dashboard", unlocks = true, label = "Dashboard", hint = "D" },
      { keys = "tab", layer = "os", verb = "focusMonitor", label = "Focus monitor", hint = "⇥" },
      { keys = "tab", layer = "os", shift = true, verb = "sendMonitor", label = "Send slot", hint = "⇧ ⇥" },
    },
  },

  -- A chord takes one more key from `rows`, then ends. Escape or any other
  -- key ends it without an action. A chord started with Shift takes its key
  -- with or without Shift.
  chords = {
    split = {
      title = "Split",
      rows = {
        { keys = "left", verb = "split", label = "Left", hint = "←" },
        { keys = "down", verb = "split", label = "Down", hint = "↓" },
        { keys = "up", verb = "split", label = "Up", hint = "↑" },
        { keys = "right", verb = "split", label = "Right", hint = "→" },
      },
    },
  },
}
