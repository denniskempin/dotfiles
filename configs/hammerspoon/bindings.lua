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
-- label     the overlay line, with `hint` on the right. A row without a
--           label still runs and is not drawn.

local arrows = { "left", "down", "up", "right" }
local digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }

local step = { [";"] = "prev", ["'"] = "next" }

return {
  title = { os = "System", app = "App" },

  -- Each inner list is one overlay column.
  layer = {
    {
      { keys = arrows, verb = "focus", label = "Focus tile", hint = "← ↓ ↑ →" },
      { keys = arrows, shift = true, verb = "move", label = "Move tile", hint = "⇧ ← ↓ ↑ →" },
      { keys = "return", verb = "zoom", label = "Zoom tile", hint = "↩" },
      { keys = "x", verb = "close", label = "Close tile", hint = "X" },
      { keys = "\\", layer = "app", chord = "split", label = "Split tile", hint = "\\ then arrow" },
      { keys = "s", chord = "resize", label = "Resize tile", hint = "S then arrow" },
      { keys = "l", layer = "os", chord = "layout", label = "Layout tiles", hint = "L then F A =" },
      { keys = "l", layer = "app", chord = "layout", label = "Layout tiles", hint = "L then F =" },
      { keys = "j", layer = "os", chord = "join", label = "Join tile", hint = "J then arrow" },
    },
    {
      { keys = step, verb = "switch", label = "Switch slot", hint = ";  '" },
      { keys = digits, arg = tonumber, layer = "os", verb = "jump", label = "Jump to slot", hint = "1–9" },
      { keys = digits, arg = tonumber, layer = "app", verb = "jump", label = "Jump to slot", hint = "1–8   9" },
      { keys = step, shift = true, verb = "send", label = "Send to slot", hint = "⇧ ; ' 1–9" },
      { keys = digits, arg = tonumber, shift = true, verb = "sendNumber" },
      { keys = { ["["] = "back", ["]"] = "forward" }, layer = "app", verb = "history",
        label = "Walk history", hint = "[  ]" },
      { keys = "p", verb = "command", label = "Run command", hint = "P" },
      { keys = "o", verb = "open", label = "Open document", hint = "O" },
      { keys = "tab", layer = "os", verb = "focusMonitor", label = "Focus monitor", hint = "⇥" },
      { keys = "tab", layer = "os", shift = true, verb = "sendMonitor", label = "Send slot", hint = "⇧ ⇥" },
      { keys = "delete", layer = "app", run = "forwardDelete" },
    },
  },

  -- A chord takes one more key from `rows`, then ends. Escape or any other
  -- key ends it without an action.
  chords = {
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
    join = {
      title = "Join",
      rows = {
        { keys = "left", verb = "join", label = "Left", hint = "←" },
        { keys = "down", verb = "join", label = "Down", hint = "↓" },
        { keys = "up", verb = "join", label = "Up", hint = "↑" },
        { keys = "right", verb = "join", label = "Right", hint = "→" },
      },
    },
    layout = {
      title = "Layout",
      rows = {
        { keys = "f", verb = "layoutFlip", label = "Flip axis", hint = "F" },
        { keys = "a", layer = "os", verb = "layoutAccordion", label = "Tiled / accordion", hint = "A" },
        { keys = "=", verb = "layoutEqual", label = "Equalize", hint = "=" },
      },
    },
  },
}
