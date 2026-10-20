-- An action is a small table with a `kind`. targets.lua builds them and
-- `run` carries them out. `commands` holds the App-layer keys that act the
-- same in every app.

local aerospace = require("aerospace")

local log = hs.logger.new("keybindings", "warning")

local M = {}

local MARK = 0x4B424C31 -- marks events this config posts, so the tap ignores them
local CHORD_GAP = 0.02

local function mark(event)
  if event then
    pcall(function()
      event:setProperty(hs.eventtap.event.properties.eventSourceUserData, MARK)
    end)
  end
  return event
end

function M.isMarked(event)
  local ok, value = pcall(function()
    return event:getProperty(hs.eventtap.event.properties.eventSourceUserData)
  end)
  return ok and value == MARK
end

local function postKey(mods, key)
  local down = mark(hs.eventtap.event.newKeyEvent(mods, key, true))
  local up = mark(hs.eventtap.event.newKeyEvent(mods, key, false))
  if down then down:post() end
  if up then up:post() end
end

local function postSequence(steps)
  local function go(i)
    local step = steps[i]
    if not step then return end
    postKey(step.mods, step.key)
    if steps[i + 1] then hs.timer.doAfter(CHORD_GAP, function() go(i + 1) end) end
  end
  go(1)
end

local tasks = {}

local function spawn(path, args)
  local task
  task = hs.task.new(path, function(code, _, err)
    tasks[task] = nil
    if code ~= 0 then log.w(path .. " " .. table.concat(args, " ") .. ": " .. (err or "")) end
  end, args)
  if task and task:start() then tasks[task] = true end
end

-- Keys posted from Hammerspoon never trigger a global hotkey. System Events
-- keystrokes do, but they reach the tap like typed keys, and an armed layer
-- would swallow them. `expected` lets the matching key through until one
-- key-up per keystroke has passed, or HOTKEY_WAIT after the last one.
local HOTKEY_WAIT = 2
local USING = { cmd = "command down", alt = "option down", ctrl = "control down", shift = "shift down" }
local expected = {}

local function postHotkey(mods, key)
  local code = hs.keycodes.map[key]
  local using = {}
  for i, mod in ipairs(mods) do using[i] = USING[mod] end
  local pending = expected[code] and expected[code].pending or 0
  expected[code] = {
    mods = mods,
    pending = pending + 1,
    deadline = hs.timer.secondsSinceEpoch() + HOTKEY_WAIT,
  }
  spawn("/usr/bin/osascript", {
    "-e",
    string.format('tell application "System Events" to key code %d using {%s}', code, table.concat(using, ", ")),
  })
end

function M.isExpected(event)
  local code = event:getKeyCode()
  local hit = expected[code]
  if not hit then return false end
  if hs.timer.secondsSinceEpoch() > hit.deadline then
    expected[code] = nil
    return false
  end
  local flags = event:getFlags()
  for _, mod in ipairs(hit.mods) do
    if not flags[mod] then return false end
  end
  if event:getType() == hs.eventtap.event.types.keyUp then
    hit.pending = hit.pending - 1
    if hit.pending == 0 then expected[code] = nil end
  end
  return true
end

local function selectMenu(app, paths)
  for _, path in ipairs(paths) do
    if app:selectMenuItem(path) then return true end
  end
  return false
end

function M.stroke(mods, key) return { kind = "stroke", mods = mods, key = key } end

-- Strokes posted CHORD_GAP apart, so the app sees a chord.
function M.seq(...) return { kind = "seq", strokes = { ... } } end

-- Menu paths tried in order. A leaf title alone also works.
function M.menu(...) return { kind = "menu", paths = { ... } } end

function M.aero(...) return { kind = "aero", args = { ... } } end

-- Reopens a running app by bundle id, which for Raycast shows the search bar.
-- Without -g the app also activates and keeps focus after its panel closes.
function M.launch(bundleID) return { kind = "launch", bundleID = bundleID } end

-- A global hotkey owned by another app.
function M.hotkey(mods, key) return { kind = "hotkey", mods = mods, key = key } end

function M.run(action)
  if not action then return end
  local kind = action.kind
  if kind == "stroke" then
    postKey(action.mods, action.key)
  elseif kind == "seq" then
    postSequence(action.strokes)
  elseif kind == "launch" then
    spawn("/usr/bin/open", { "-g", "-b", action.bundleID })
  elseif kind == "hotkey" then
    postHotkey(action.mods, action.key)
  elseif kind == "aero" then
    aerospace.command(action.args)
  elseif kind == "menu" then
    hs.timer.doAfter(0, function()
      local app = hs.application.frontmostApplication()
      if app then selectMenu(app, action.paths) end
    end)
  else
    log.w("unknown action kind " .. tostring(kind))
  end
end

M.commands = {}

function M.commands.forwardDelete()
  postKey({}, "forwarddelete")
end

return M
