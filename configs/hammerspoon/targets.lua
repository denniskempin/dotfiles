-- What each verb in bindings.lua does. `system` is the operating-system
-- layer. `apps` is the App layer, keyed by bundle id. An app with no entry
-- ignores the App layer.
--
-- A field is one action, a table of actions keyed by the argument, or a
-- function of the argument that returns an action. A missing field, or a
-- function that returns nil, means the key does nothing in that target.

local actions = require("actions")

local stroke, seq, menu = actions.stroke, actions.seq, actions.menu
local aero, launch = actions.aero, actions.launch

local system = {
  focus = function(dir)
    return aero("focus",
      "--boundaries", "all-monitors-outer-frame",
      "--boundaries-action", "wrap-around-all-monitors",
      dir)
  end,
  move = function(dir)
    return aero("move",
      "--boundaries", "all-monitors-outer-frame",
      "--boundaries-action", "create-implicit-container",
      dir)
  end,
  zoom = aero("fullscreen"),
  close = aero("close"),
  resize = {
    left = aero("resize", "width", "-100"),
    right = aero("resize", "width", "+100"),
    down = aero("resize", "height", "+100"),
    up = aero("resize", "height", "-100"),
  },
  join = function(dir) return aero("join-with", dir) end,
  layoutFlip = aero("layout", "horizontal", "vertical"),
  layoutAccordion = aero("layout", "tiles", "accordion"),
  layoutEqual = aero("balance-sizes"),

  -- next and prev step through the workspaces on the focused monitor. Without
  -- --no-stdin AeroSpace may read the list from hs.task's open stdin pipe.
  switch = function(dir) return aero("workspace", "--no-stdin", "--wrap-around", dir) end,
  jump = function(n) return aero("workspace", tostring(n)) end,
  send = function(dir)
    return aero("move-node-to-workspace", "--no-stdin", "--focus-follows-window", "--wrap-around", dir)
  end,
  sendNumber = function(n)
    return aero("move-node-to-workspace", "--focus-follows-window", tostring(n))
  end,
  command = launch("com.raycast.macos"),
  focusMonitor = aero("focus-monitor", "--wrap-around", "next"),
  sendMonitor = aero("move-workspace-to-monitor", "--wrap-around", "next"),
}

local PANE_ITEM = {
  left = "Select Pane Left",
  down = "Select Pane Below",
  up = "Select Pane Above",
  right = "Select Pane Right",
}

local DIVIDER_ITEM = {
  left = "Move Divider Left",
  down = "Move Divider Down",
  up = "Move Divider Up",
  right = "Move Divider Right",
}

local vscode = {
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

  ["com.googlecode.iterm2"] = {
    focus = function(dir)
      local item = PANE_ITEM[dir]
      return menu(
        { "Window", "Select Split Pane", item },
        { "Window", "Split Pane", "Select Split Pane", item },
        item
      )
    end,
    zoom = menu({ "View", "Maximize Active Pane" }, "Maximize Active Pane"),
    close = stroke({ "cmd" }, "w"),
    split = {
      down = stroke({ "cmd", "shift" }, "d"),
      right = stroke({ "cmd" }, "d"),
    },
    resize = function(dir)
      local item = DIVIDER_ITEM[dir]
      return menu(
        { "Window", "Resize Split Pane", item },
        { "Window", "Split Pane", "Resize Split Pane", item },
        item
      )
    end,
    layoutEqual = menu(
      { "Window", "Arrange Windows", "Arrange Split Panes Evenly" },
      "Arrange Split Panes Evenly"
    ),
    switch = {
      prev = stroke({ "cmd" }, "left"),
      next = stroke({ "cmd" }, "right"),
    },
    jump = function(n) return stroke({ "cmd" }, tostring(n)) end,
    send = {
      prev = stroke({ "cmd", "shift" }, "left"),
      next = stroke({ "cmd", "shift" }, "right"),
    },
    -- fish binds Alt+J to prevd and Alt+K to nextd. Option sends Esc+.
    history = {
      back = stroke({ "alt" }, "j"),
      forward = stroke({ "alt" }, "k"),
    },
    command = stroke({ "cmd", "shift" }, "/"),
    open = menu({ "View", "Open Quickly" }, "Open Quickly"),
  },

  ["md.obsidian"] = {
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
