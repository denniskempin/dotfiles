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
local digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }

-- a through z. configs/omniwm/settings.toml defines a workspace named for each.
local letters = {}
for key in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
  letters[#letters + 1] = key
end

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
      { keys = across, layer = "os", shift = true, verb = "move", label = "Move column", hint = "⇧ ← →" },
      { keys = along, layer = "os", shift = true, verb = "move", label = "Move to workspace", hint = "⇧ ↑ ↓" },
      { keys = arrows, layer = "app", verb = "focus", label = "Focus tile", hint = "← ↓ ↑ →" },
      { keys = arrows, layer = "app", shift = true, verb = "move", label = "Move tile", hint = "⇧ ← ↓ ↑ →" },
      { keys = "return", verb = "zoom", label = "Zoom tile", hint = "↩" },
      { keys = "x", verb = "close", label = "Close tile", hint = "X" },
      { keys = "\\", layer = "app", chord = "split", label = "Split tile", hint = "\\ then arrow" },
      { keys = "s", chord = "resize", label = "Resize tile", hint = "S then arrow" },
      { keys = "l", layer = "os", chord = "layout", label = "Layout tiles", hint = "L then W F A C =" },
      { keys = "l", layer = "app", chord = "layout", label = "Layout tiles", hint = "L then F =" },
      { keys = "j", layer = "os", chord = "column", label = "Join or send column", hint = "J then arrow" },
    },
    {
      name = "Slots",
      { keys = step, verb = "switch", label = "Switch slot", hint = ";  '" },
      { keys = "g", layer = "os", chord = "jump", label = "Jump to workspace", hint = "G then key" },
      { keys = digits, arg = tonumber, layer = "app", verb = "jump", label = "Jump to slot", hint = "1–8   9" },
      { keys = step, shift = true, verb = "send", label = "Send to slot", hint = "⇧ ;  '" },
      { keys = "g", layer = "os", shift = true, chord = "send", label = "Send to workspace", hint = "⇧ G then key" },
    },
    {
      name = "Other",
      { keys = { ["["] = "back", ["]"] = "forward" }, layer = "os", verb = "history",
        label = "Last window, workspace", hint = "[  ]" },
      { keys = { ["["] = "back", ["]"] = "forward" }, layer = "app", verb = "history",
        label = "Walk history", hint = "[  ]" },
      { keys = "p", verb = "command", label = "Run command", hint = "P" },
      { keys = "o", verb = "open", unlocks = true, label = "Open document", hint = "O" },
      { keys = "t", layer = "os", verb = "quake", unlocks = true, label = "Quake terminal", hint = "T" },
      { keys = "z", layer = "os", verb = "scratchpad", unlocks = true, label = "Scratchpad", hint = "Z" },
      { keys = "z", layer = "os", shift = true, verb = "scratchpadSend", label = "To scratchpad", hint = "⇧ Z" },
      { keys = "v", layer = "os", verb = "overview", unlocks = true, label = "Overview", hint = "V" },
      { keys = "tab", layer = "os", verb = "focusMonitor", label = "Focus monitor", hint = "⇥" },
      { keys = "tab", layer = "os", shift = true, verb = "sendMonitor", label = "Send slot", hint = "⇧ ⇥" },
      { keys = "delete", layer = "app", run = "forwardDelete" },
    },
  },

  -- A chord takes one more key from `rows`, then ends. Escape or any other
  -- key ends it without an action. A chord started with Shift takes its key
  -- with or without Shift.
  chords = {
    jump = {
      title = "Jump to workspace",
      rows = {
        { keys = letters, verb = "jump", label = "The workspace named by the key", hint = "a–z" },
      },
    },
    send = {
      title = "Send to workspace",
      rows = {
        { keys = letters, verb = "sendNamed", label = "The workspace named by the key", hint = "a–z" },
      },
    },
    resize = {
      title = "Resize",
      rows = {
        { keys = "left", verb = "resize", label = "Shrink width", hint = "←" },
        { keys = "right", verb = "resize", label = "Grow width", hint = "→" },
        { keys = "down", verb = "resize", label = "Grow height", hint = "↓" },
        { keys = "up", verb = "resize", label = "Shrink height", hint = "↑" },
      },
    },
    split = {
      title = "Split",
      rows = {
        { keys = "left", verb = "split", label = "Left", hint = "←" },
        { keys = "down", verb = "split", label = "Down", hint = "↓" },
        { keys = "up", verb = "split", label = "Up", hint = "↑" },
        { keys = "right", verb = "split", label = "Right", hint = "→" },
      },
    },
    column = {
      title = "Column",
      rows = {
        { keys = "left", verb = "join", label = "Join left", hint = "←" },
        { keys = "down", verb = "sendColumn", label = "To workspace below", hint = "↓" },
        { keys = "up", verb = "sendColumn", label = "To workspace above", hint = "↑" },
        { keys = "right", verb = "join", label = "Join right", hint = "→" },
      },
    },
    layout = {
      title = "Layout",
      rows = {
        { keys = "w", layer = "os", verb = "layoutWidth", label = "Cycle width", hint = "W" },
        { keys = "f", layer = "os", verb = "layoutFull", label = "Full width", hint = "F" },
        { keys = "f", layer = "app", verb = "layoutFlip", label = "Flip axis", hint = "F" },
        { keys = "a", layer = "os", verb = "layoutTabbed", label = "Tabbed column", hint = "A" },
        { keys = "c", layer = "os", verb = "layoutCenter", label = "Center column", hint = "C" },
        { keys = "=", verb = "layoutEqual", label = "Equalize", hint = "=" },
      },
    },
  },
}
