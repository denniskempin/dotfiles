-- A small made-up grammar for scenarios.lua, so the framework tests do not
-- depend on the real bindings. snapshot.txt covers those.
--
-- Both layers:  arrows go, Shift+arrows carry, S starts the "pick" chord,
--               Shift+S starts the "place" chord
-- OS layer:     P launches, O sends a hotkey, Y calls a function that
--               runs an OmniWM command, U opens a panel and ends a lock
-- App layer:    K posts a two-stroke sequence, M tries three menu paths
-- Only APP has App-layer targets.

local M = {}

M.APP = "com.example.App"
M.UNLISTED = "com.example.Unlisted"
M.HYPER = { "cmd", "alt", "ctrl" }

local arrows = { "left", "down", "up", "right" }

function M.bindings()
  return {
    title = { os = "OS", app = "App" },
    layer = {
      {
        { keys = arrows, verb = "go", label = "Go", hint = "arrows" },
        { keys = arrows, shift = true, verb = "carry", label = "Carry", hint = "⇧ arrows" },
        { keys = "s", chord = "pick", label = "Pick", hint = "S then arrow" },
        { keys = "s", shift = true, chord = "place", label = "Place", hint = "⇧ S then arrow" },
      },
      {
        { keys = "p", layer = "os", verb = "launch", label = "Launch", hint = "P" },
        { keys = "o", layer = "os", verb = "hotkey", label = "Hotkey", hint = "O" },
        { keys = "y", layer = "os", verb = "call", label = "Call", hint = "Y" },
        { keys = "u", layer = "os", verb = "panel", unlocks = true, label = "Panel", hint = "U" },
        { keys = "k", layer = "app", verb = "sequence", label = "Sequence", hint = "K" },
        { keys = "m", layer = "app", verb = "menu", label = "Menu", hint = "M" },
      },
    },
    chords = {
      pick = {
        title = "Pick",
        rows = {
          { keys = arrows, verb = "pick", label = "Pick", hint = "arrows" },
        },
      },
      place = {
        title = "Place",
        rows = {
          { keys = arrows, verb = "place", label = "Place", hint = "arrows" },
        },
      },
    },
  }
end

function M.targets(actions)
  local stroke = actions.stroke
  return {
    system = {
      go = function(dir) return actions.wm("go", dir) end,
      carry = function(dir) return actions.wm("carry", dir) end,
      pick = function(dir) return actions.wm("pick", dir) end,
      place = function(dir) return actions.wm("place", dir) end,
      launch = actions.launch("com.example.Launcher"),
      hotkey = actions.hotkey(M.HYPER, "o"),
      call = actions.call(function() require("omniwm").command({ "called" }) end),
      panel = actions.wm("panel"),
    },
    apps = {
      [M.APP] = {
        go = function(dir) return stroke({ "cmd" }, dir) end,
        carry = function(dir) return stroke({ "cmd", "shift" }, dir) end,
        pick = function(dir) return stroke({ "alt" }, dir) end,
        place = function(dir) return stroke({ "ctrl" }, dir) end,
        sequence = actions.seq(stroke({ "cmd" }, "k"), stroke({ "cmd" }, "j")),
        menu = actions.menu({ "Edit", "First" }, { "Edit", "Second" }, "Third"),
      },
    },
  }
end

return M
