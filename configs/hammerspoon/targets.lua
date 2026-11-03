-- What each verb in bindings.lua does. `system` is the operating-system
-- layer. `apps` is the App layer, keyed by bundle id. An app with no entry
-- ignores the App layer.
--
-- A field is one action, a table of actions keyed by the argument, or a
-- function of the argument that returns an action. A missing field, or a
-- function that returns nil, means the key does nothing in that target.
--
-- `legend` is the App overlay's words for this app, keyed by the row's verb
-- or chord. A string replaces the label. A table replaces `label` and
-- `hint`. A row with no action here is left out of the overlay.

local actions = require("actions")
local omniwm = require("omniwm")

local stroke, seq, menu = actions.stroke, actions.seq, actions.menu
local launch = actions.launch

local function wm(...) return actions.wm("command", ...) end

-- OmniWM's niri layout: each workspace is a strip of columns that scrolls
-- left and right, a column holds one or more windows stacked top to bottom,
-- and a monitor's workspaces stack top to bottom. Left and right move along
-- the strip. Up and down move inside the column, and past its end to the
-- workspace above or below.
local VERTICAL = { up = true, down = true }

-- settings.toml gives each workspace a key as its display name and the key's
-- character code as its raw name. OmniWM needs raw names that are positive
-- integers, and reads a display name such as "3" as raw name 3, so commands
-- go by the code.
local function workspace(key) return tostring(key:byte()) end

local system = {
  focus = function(dir)
    if VERTICAL[dir] then return wm("focus-window-or-workspace-" .. dir) end
    return wm("focus", dir)
  end,
  move = function(dir)
    if VERTICAL[dir] then return wm("move-window-" .. dir .. "-or-to-workspace-" .. dir) end
    return wm("move-column", dir)
  end,
  zoom = wm("toggle-fullscreen"),
  close = wm("close-focused-window"),
  resize = {
    left = wm("set-container-primary-span", "-10%"),
    right = wm("set-container-primary-span", "+10%"),
    down = wm("set-window-secondary-span", "+10%"),
    up = wm("set-window-secondary-span", "-10%"),
  },
  -- Into the neighboring column, or out of a shared column into its own.
  join = {
    left = wm("consume-or-expel-window-left"),
    right = wm("consume-or-expel-window-right"),
  },
  sendColumn = {
    up = wm("move-column-to-workspace", "up"),
    down = wm("move-column-to-workspace", "down"),
  },
  layoutWidth = wm("cycle-size", "forward"),
  layoutFull = wm("toggle-container-full-primary-span"),
  layoutTabbed = wm("toggle-column-tabbed"),
  layoutCenter = wm("center-column"),
  layoutEqual = wm("balance-sizes"),

  -- prev is the workspace above, next the one below, on this monitor.
  switch = function(dir) return wm("switch-workspace", dir) end,
  jump = function(key) return wm("switch-workspace", workspace(key)) end,
  send = {
    prev = wm("move-to-workspace", "up"),
    next = wm("move-to-workspace", "down"),
  },
  sendNamed = function(key) return wm("move-to-workspace", workspace(key)) end,
  -- OmniWM keeps one step of each: the window and the workspace focused
  -- before this one. Pressing again goes back.
  history = {
    back = wm("focus", "previous"),
    forward = wm("switch-workspace", "back-and-forth"),
  },
  command = launch("com.raycast.macos"),
  -- Return focuses the window where it is. Shift+Return brings it here, as a
  -- new column right of the focused one.
  open = wm("open-command-palette", "windows"),
  quake = wm("toggle-quake-terminal"),
  scratchpad = wm("scratchpad", "toggle", "1"),
  scratchpadSend = wm("scratchpad", "assign", "1"),
  overview = wm("toggle-overview"),
  focusMonitor = wm("focus-monitor", "next"),
  sendMonitor = actions.call(omniwm.sendWorkspaceToNextMonitor),
}

local vscode = {
  legend = {
    focus = "Focus group",
    zoom = "Zoom group",
    close = "Close editor",
    split = "Split editor",
    layout = { label = "Flip layout", hint = "L then F" },
    switch = "Switch tab",
    jump = "Jump to tab",
    send = "Move tab",
    history = "Back and forward",
    command = "Command palette",
    open = "Quick open",
  },
  focus = function(dir)
    return seq(stroke({ "cmd" }, "k"), stroke({ "cmd" }, dir))
  end,
  zoom = seq(stroke({ "cmd" }, "k"), stroke({ "cmd" }, "m")),
  close = stroke({ "cmd" }, "w"),
  split = stroke({ "cmd" }, "\\"),
  layoutFlip = stroke({ "cmd", "alt" }, "0"),
  switch = {
    prev = seq(stroke({ "cmd" }, "k"), stroke({ "cmd", "alt" }, "left")),
    next = seq(stroke({ "cmd" }, "k"), stroke({ "cmd", "alt" }, "right")),
  },
  jump = function(n)
    if n == 9 then return stroke({ "cmd" }, "9") end
    return stroke({ "ctrl" }, tostring(n))
  end,
  send = {
    prev = seq(stroke({ "cmd" }, "k"), stroke({ "cmd", "shift" }, "left")),
    next = seq(stroke({ "cmd" }, "k"), stroke({ "cmd", "shift" }, "right")),
  },
  history = {
    back = stroke({ "ctrl" }, "-"),
    forward = stroke({ "ctrl", "shift" }, "-"),
  },
  command = stroke({ "cmd", "shift" }, "p"),
  open = stroke({ "cmd" }, "p"),
}

local apps = {
  ["com.google.Chrome"] = {
    legend = {
      switch = "Switch tab",
      jump = "Jump to tab",
      send = "Move tab",
      history = "Back and forward",
      command = "Search menus",
      open = "Search tabs",
    },
    switch = {
      prev = stroke({ "cmd", "shift" }, "["),
      next = stroke({ "cmd", "shift" }, "]"),
    },
    jump = function(n) return stroke({ "cmd" }, tostring(n)) end,
    send = {
      prev = stroke({ "ctrl", "shift" }, "pageup"),
      next = stroke({ "ctrl", "shift" }, "pagedown"),
    },
    history = {
      back = stroke({ "cmd" }, "["),
      forward = stroke({ "cmd" }, "]"),
    },
    command = stroke({ "cmd", "shift" }, "/"),
    open = stroke({ "cmd", "shift" }, "a"),
  },

  ["com.microsoft.VSCode"] = vscode,

  -- Cursor keeps the VS Code keybindings.
  ["com.todesktop.230313mzl4w4u92"] = vscode,

  ["com.mitchellh.ghostty"] = {
    legend = {
      focus = "Focus pane",
      zoom = "Zoom pane",
      close = "Close pane",
      split = "Split pane",
      resize = "Resize pane",
      layout = { label = "Equalize panes", hint = "L then =" },
      switch = "Switch tab",
      jump = "Jump to tab",
      send = "Move tab",
      history = "Directory history",
      command = "Command palette",
      open = "Show all tabs",
    },
    focus = function(dir) return stroke({ "cmd", "alt" }, dir) end,
    zoom = stroke({ "cmd", "shift" }, "return"),
    close = stroke({ "cmd" }, "w"),
    split = {
      left = menu({ "File", "Split Left" }),
      down = stroke({ "cmd", "shift" }, "d"),
      up = menu({ "File", "Split Up" }),
      right = stroke({ "cmd" }, "d"),
    },
    resize = function(dir) return stroke({ "cmd", "ctrl" }, dir) end,
    layoutEqual = stroke({ "cmd", "ctrl" }, "="),
    switch = {
      prev = stroke({ "cmd", "shift" }, "["),
      next = stroke({ "cmd", "shift" }, "]"),
    },
    jump = function(n) return stroke({ "cmd" }, tostring(n)) end,
    -- Bound to move_tab in configs/ghostty/config.ghostty; Ghostty has no default.
    send = {
      prev = stroke({ "cmd", "shift" }, "left"),
      next = stroke({ "cmd", "shift" }, "right"),
    },
    -- fish binds Alt+J to prevd and Alt+K to nextd. macos-option-as-alt makes
    -- Option send Esc+.
    history = {
      back = stroke({ "alt" }, "j"),
      forward = stroke({ "alt" }, "k"),
    },
    command = stroke({ "cmd", "shift" }, "p"),
    -- View > Show All Tabs, the macOS tab overview.
    open = stroke({ "cmd", "shift" }, "\\"),
  },

  ["md.obsidian"] = {
    legend = {
      close = "Close tab",
      split = { label = "Split pane", hint = "\\ then ↓ →" },
      switch = "Switch tab",
      jump = "Jump to tab",
      history = "Back and forward",
      command = "Command palette",
      open = "Open note",
    },
    close = stroke({ "cmd" }, "w"),
    split = {
      down = menu({ "Split down" }, "Split down"),
      right = menu({ "Split right" }, "Split right"),
    },
    switch = {
      prev = stroke({ "cmd", "shift" }, "["),
      next = stroke({ "cmd", "shift" }, "]"),
    },
    jump = function(n) return stroke({ "cmd" }, tostring(n)) end,
    history = {
      back = stroke({ "cmd", "alt" }, "left"),
      forward = stroke({ "cmd", "alt" }, "right"),
    },
    command = stroke({ "cmd" }, "p"),
    open = stroke({ "cmd" }, "o"),
  },
}

return { system = system, apps = apps }
