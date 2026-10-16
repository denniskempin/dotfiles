-- Helpers for checking the config inside the running Hammerspoon. See
-- keybindings/AGENTS.md. Load with:
--
--   hs -c 'dofile(hs.configdir .. "/../test/live.lua")'
--
-- Everything that posts events runs on a timer, so `hs -c` has returned
-- before the config's tap sees the keys.

Live = Live or {}

local LAYER_KEY = { os = "f18", app = "f19" }

local function defer(fn) hs.timer.doAfter(0, fn) end

-- Whether the config loaded and its tap is running, plus the keybindings
-- warnings in the console since the last reload.
function Live.check()
  local lines = {
    "config loaded: " .. tostring(Keybindings ~= nil),
    "tap enabled: " .. tostring(Keybindings ~= nil and Keybindings.tap:isEnabled()),
  }
  local console = hs.console.getConsole()
  local start = 1
  for i in console:gmatch("()%-%- Loading ~/%.hammerspoon/init%.lua") do start = i end
  for line in console:sub(start):gmatch("[^\n]+") do
    if line:find("keybindings") or line:find("%*%*%*") then lines[#lines + 1] = line end
  end
  return table.concat(lines, "\n")
end

-- Presses `key` with `mods` while `layer` ("os", "app", or nil) is held. The
-- events are unmarked, so the config's tap handles them like typed keys.
-- Karabiner is not involved.
function Live.press(layer, key, mods)
  defer(function()
    local new = hs.eventtap.event.newKeyEvent
    local hold = LAYER_KEY[layer]
    if hold then new({}, hold, true):post() end
    new(mods or {}, key, true):post()
    new(mods or {}, key, false):post()
    if hold then new({}, hold, false):post() end
  end)
  return "pressed"
end

-- Brings an app to the front, so App-layer presses go to it and not to the
-- agent's editor.
function Live.focus(bundleID)
  defer(function() hs.application.launchOrFocusByBundleID(bundleID) end)
  return "focusing " .. bundleID
end

-- The front app and its focused window.
function Live.front()
  local app = hs.application.frontmostApplication()
  local win = hs.window.focusedWindow()
  return ("%s | %s"):format(app and app:bundleID() or "none", win and win:title() or "no window")
end

-- On-screen windows owned by `owner` (an app name such as "Raycast"), with
-- their size and window layer. Panels and switchers show up here even when
-- they never take focus.
function Live.windows(owner)
  local out = {}
  for _, w in ipairs(hs.window.list(true)) do
    if w.kCGWindowOwnerName == owner and w.kCGWindowIsOnscreen then
      local b = w.kCGWindowBounds
      out[#out + 1] = ("%dx%d layer=%s %s"):format(b.Width, b.Height, tostring(w.kCGWindowLayer), w.kCGWindowName or "")
    end
  end
  return #out > 0 and table.concat(out, "\n") or "none"
end

-- Whether a menu item exists in the front app, and its state. Use it before
-- trusting a menu action, since titles change between app versions.
function Live.menu(path)
  local app = hs.application.frontmostApplication()
  local item = app and app:findMenuItem(path)
  if not item then return "missing" end
  return ("enabled=%s ticked=%s"):format(tostring(item.enabled), tostring(item.ticked))
end

-- Binds a throwaway global hotkey and counts how often it fires. A posted key
-- that should trigger another app's hotkey can be pointed here first.
function Live.probe(mods, key)
  Live.probes = Live.probes or {}
  local id = table.concat(mods, "+") .. "+" .. key
  if Live.probes[id] then Live.probes[id].hotkey:delete() end
  local probe = { hits = 0 }
  probe.hotkey = hs.hotkey.bind(mods, key, function() probe.hits = probe.hits + 1 end)
  Live.probes[id] = probe
  return id
end

function Live.hits(id)
  local probe = Live.probes and Live.probes[id]
  return probe and probe.hits or "no probe " .. id
end

-- Removes probes. A reload clears everything as well.
function Live.reset()
  for _, probe in pairs(Live.probes or {}) do probe.hotkey:delete() end
  Live.probes = nil
  return "reset"
end

return "live helpers loaded"
