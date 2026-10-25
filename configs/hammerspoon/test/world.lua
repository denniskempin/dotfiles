-- Runs configs/hammerspoon in plain Lua against a fake `hs`.
--
-- A world loads the config fresh, takes key events, and records what the
-- config does to the outside world as effect strings:
--
--   press cmd+shift+[               a key the config posted, down and up
--   aerospace focus left            an AeroSpace command it started
--   open -b com.raycast.macos       any other process it started
--   system-events cmd+alt+ctrl+o    a keystroke it asked System Events for
--   menu Window > Split Pane        a menu item it tried in the front app
--
-- Time moves only on advance and settle.
--
-- The fake does what the live system was seen to do (docs/keybindings-gotchas.md):
-- posted events come back through the config's own tap, and System Events
-- keystrokes reach the tap like typed keys. A posted key or System Events
-- keystroke that the tap swallows is recorded in `problems`. Menu items match
-- only when listed in `menus`, so every candidate path shows up.
--
-- It cannot tell which keys trigger global hotkeys, whether an app honors a
-- shortcut, or what AeroSpace does with a command. AGENTS.md covers checking
-- those on the live system.
--
-- The config reads the global `hs`, so only the newest world is live.

local TEST_DIR = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local HS_DIR = TEST_DIR .. "/.."

local CODES = dofile(TEST_DIR .. "/keycodes.lua")
local KEYMAP = {}
for code, name in pairs(CODES) do
  KEYMAP[code] = name
  KEYMAP[name] = code
end

local MODULES = { "actions", "aerospace", "bindings", "overlay", "switcher", "targets" }

local chunks = {}
local function chunk(name)
  if not chunks[name] then
    chunks[name] = assert(loadfile(HS_DIR .. "/" .. name .. ".lua"))
  end
  return chunks[name]
end

local MOD_ORDER = { "cmd", "alt", "ctrl", "shift", "fn" }
local USING = { command = "cmd", option = "alt", control = "ctrl", shift = "shift" }
local PROPS = { eventSourceUserData = 42, keyboardEventAutorepeat = 8 }
local TYPES = { keyDown = 10, keyUp = 11, flagsChanged = 12 }

-- Accepts { "cmd", "shift" } or { cmd = true, shift = true }.
local function flagSet(mods)
  local set = {}
  for k, v in pairs(mods or {}) do
    if type(k) == "number" then set[v] = true elseif v then set[k] = true end
  end
  return set
end

local function keyLabel(flags, code)
  local parts = {}
  for _, mod in ipairs(MOD_ORDER) do
    if flags[mod] then parts[#parts + 1] = mod end
  end
  parts[#parts + 1] = CODES[code] or tostring(code)
  return table.concat(parts, "+")
end

local function keyCode(key)
  local code = type(key) == "number" and key or KEYMAP[key]
  if type(code) ~= "number" then error("unknown key " .. tostring(key), 3) end
  return code
end

local World = {}
World.__index = World

local M = { KEYMAP = KEYMAP, CODES = CODES }

-- opts.front           bundle id of the front app, or nil for none
-- opts.latency         seconds each started process runs (default 0.05)
-- opts.hang            function(path, args) returning true keeps that process running
-- opts.deliverHotkeys  false drops System Events keystrokes
-- opts.menus           set of "A > B > C" menu paths the front app has
-- opts.stdout          function(args) returning the stdout of a finished process
-- opts.bindings        a table that replaces bindings.lua
-- opts.targets         function(actions) returning a table that replaces targets.lua
function M.new(opts)
  opts = opts or {}
  local w = setmetatable({
    replace = { bindings = opts.bindings, targets = opts.targets },
    now = 0,
    timers = {},
    seq = 0,
    log = {},
    warnings = {},
    problems = {},
    front = opts.front,
    latency = opts.latency or 0.05,
    hang = opts.hang,
    deliverHotkeys = opts.deliverHotkeys ~= false,
    menus = opts.menus or {},
    stdout = opts.stdout,
    overlay = { visible = false, shows = 0, texts = {} },
  }, World)
  w:load()
  return w
end

function World:load()
  hs = self:fake()
  package.loaded["hs.ipc"] = nil
  package.preload["hs.ipc"] = function() return {} end
  for _, name in ipairs(MODULES) do
    package.loaded[name] = nil
    package.preload[name] = chunk(name)
  end
  local bindings, targets = self.replace.bindings, self.replace.targets
  if bindings then package.preload.bindings = function() return bindings end end
  if targets then package.preload.targets = function() return targets(require("actions")) end end
  chunk("init")()
  self.modules = {}
  for _, name in ipairs(MODULES) do self.modules[name] = package.loaded[name] end
end

-- Clock

function World:timer(delay, fn)
  self.seq = self.seq + 1
  local t = { at = self.now + delay, fn = fn, seq = self.seq, live = true }
  function t:stop()
    t.live = false
    return t
  end
  self.timers[#self.timers + 1] = t
  return t
end

function World:advance(dt)
  local target = self.now + (dt or 0)
  while true do
    local best
    for _, t in ipairs(self.timers) do
      if t.live and t.at <= target and (not best or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then
        best = t
      end
    end
    if not best then break end
    best.live = false
    self.now = math.max(self.now, best.at)
    best.fn()
  end
  self.now = target
  local live = {}
  for _, t in ipairs(self.timers) do
    if t.live then live[#live + 1] = t end
  end
  self.timers = live
end

-- Runs every pending timer and process.
function World:settle()
  self:advance(30)
end

-- Results

function World:record(effect)
  self.log[#self.log + 1] = effect
end

-- Effects since the last call.
function World:effects()
  local out = self.log
  self.log = {}
  return out
end

-- Warnings the config logged since the last call.
function World:takeWarnings()
  local out = self.warnings
  self.warnings = {}
  return out
end

-- Input. Each returns true when the event goes on to apps, false when the
-- tap swallows it.

function World:event(code, down, flags, isRepeat, kind)
  local w = self
  local e = {
    code = code,
    down = down,
    flags = flags,
    kind = kind,
    props = { [PROPS.eventSourceUserData] = 0, [PROPS.keyboardEventAutorepeat] = isRepeat and 1 or 0 },
  }
  function e:getKeyCode() return e.code end
  function e:getType()
    if e.kind then return e.kind end
    return e.down and TYPES.keyDown or TYPES.keyUp
  end
  function e:getFlags()
    local copy = {}
    for k, v in pairs(e.flags) do copy[k] = v end
    return copy
  end
  function e:getProperty(p) return e.props[p] end
  function e:setProperty(p, v)
    e.props[p] = v
    return e
  end
  function e:post() w:posted(e) end
  return e
end

function World:toTap(e)
  if not (self.tapFn and self.tapRunning) then return true end
  return self.tapFn(e) ~= true
end

function World:flags(mods)
  return self:toTap(self:event(keyCode("fn"), false, flagSet(mods), false, TYPES.flagsChanged))
end

function World:down(key, mods)
  return self:toTap(self:event(keyCode(key), true, flagSet(mods), false))
end

function World:up(key, mods)
  return self:toTap(self:event(keyCode(key), false, flagSet(mods), false))
end

function World:press(key, mods)
  local down = self:down(key, mods)
  local up = self:up(key, mods)
  return down, up
end

function World:autorepeat(key, mods)
  return self:toTap(self:event(keyCode(key), true, flagSet(mods), true))
end

function World:posted(e)
  local label = keyLabel(e.flags, e.code)
  if not self:toTap(e) then
    self.problems[#self.problems + 1] = "the tap swallowed posted " .. label .. (e.down and " down" or " up")
  end
  local last = self.log[#self.log]
  if not e.down and last == "down " .. label then
    self.log[#self.log] = "press " .. label
  else
    self:record((e.down and "down " or "up ") .. label)
  end
end

-- Processes

local function systemEventsKey(args)
  local script = args[1] == "-e" and args[2] or ""
  local code, using = script:match('^tell application "System Events" to key code (%d+) using {(.-)}$')
  if not code then return nil end
  local flags = {}
  for word in using:gmatch("(%a+) down") do
    if not USING[word] then return nil end
    flags[USING[word]] = true
  end
  return tonumber(code), flags
end

function World:task(path, callback, args)
  local w = self
  local name = path:match("[^/]+$")
  local effect = name .. " " .. table.concat(args, " ")
  local deliver
  if name == "osascript" then
    local code, flags = systemEventsKey(args)
    if code then
      effect = "system-events " .. keyLabel(flags, code)
      deliver = function()
        if not w.deliverHotkeys then return end
        local down = w:toTap(w:event(code, true, flags, false))
        local up = w:toTap(w:event(code, false, flags, false))
        if not (down and up) then
          w.problems[#w.problems + 1] = "the tap swallowed the System Events keystroke " .. keyLabel(flags, code)
        end
      end
    end
  end

  local t = { done = false }
  local function finish(code)
    if t.done then return end
    t.done = true
    if code == 0 and deliver then deliver() end
    local out = ""
    if w.stdout then out = w.stdout(args) or "" end
    callback(code, out, "")
  end
  function t:start()
    w:record(effect)
    if not (w.hang and w.hang(path, args)) then
      w:timer(w.latency, function() finish(0) end)
    end
    return t
  end
  function t:terminate()
    if t.done then return end
    w:record("terminate " .. effect)
    w:timer(0, function() finish(15) end)
  end
  function t:isRunning() return not t.done end
  return t
end

-- The fake hs

local function strict(name, t)
  return setmetatable(t, {
    __index = function(_, k)
      error("the fake has no " .. name .. "." .. tostring(k) .. "; add it to configs/hammerspoon/test/world.lua", 2)
    end,
  })
end

function World:fake()
  local w = self

  local function logger()
    local function warn(message) w.warnings[#w.warnings + 1] = message end
    return setmetatable({ w = warn, e = warn }, { __index = function() return function() end end })
  end

  local function canvas()
    local c = {}
    function c:level() return c end
    function c:clickActivating() return c end
    function c:behavior() return c end
    function c:frame() return c end
    function c:replaceElements(elements)
      local texts = {}
      for _, el in ipairs(elements) do
        if el.type == "text" then texts[#texts + 1] = el.text end
      end
      w.overlay.texts = texts
      w.overlay.title = texts[1]
      return c
    end
    function c:show()
      w.overlay.visible = true
      w.overlay.shows = w.overlay.shows + 1
      return c
    end
    function c:hide()
      w.overlay.visible = false
      return c
    end
    return c
  end

  return strict("hs", {
    logger = strict("hs.logger", { new = logger }),
    keycodes = strict("hs.keycodes", { map = KEYMAP }),
    fs = strict("hs.fs", {
      attributes = function(path)
        if path == "/opt/homebrew/bin/aerospace" then return { mode = "file" } end
        return nil
      end,
    }),
    timer = strict("hs.timer", {
      doAfter = function(delay, fn) return w:timer(delay, fn) end,
      secondsSinceEpoch = function() return w.now end,
    }),
    task = strict("hs.task", {
      new = function(path, callback, args) return w:task(path, callback, args or {}) end,
    }),
    application = strict("hs.application", {
      frontmostApplication = function()
        if not w.front then return nil end
        return {
          bundleID = function() return w.front end,
          selectMenuItem = function(_, path)
            local text = type(path) == "table" and table.concat(path, " > ") or path
            w:record("menu " .. text)
            return w.menus[text] == true
          end,
        }
      end,
    }),
    screen = strict("hs.screen", {
      mainScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1512, h = 944 } end }
      end,
    }),
    canvas = strict("hs.canvas", {
      windowLevels = { overlay = 1 },
      windowBehaviors = { canJoinAllSpaces = 1, stationary = 2, ignoresCycle = 4 },
      new = canvas,
    }),
    eventtap = strict("hs.eventtap", {
      new = function(_, fn)
        w.tapFn = fn
        local tap = {}
        function tap:start()
          w.tapRunning = true
          return tap
        end
        function tap:stop()
          w.tapRunning = false
          return tap
        end
        function tap:isEnabled() return w.tapRunning == true end
        return tap
      end,
      event = strict("hs.eventtap.event", {
        properties = PROPS,
        types = TYPES,
        newKeyEvent = function(mods, key, down)
          return w:event(keyCode(key), down, flagSet(mods), false)
        end,
        newKeyEventSequence = function()
          error("hs.eventtap.event.newKeyEventSequence keeps only the first modifier", 2)
        end,
      }),
    }),
  })
end

return M
