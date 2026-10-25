-- Hammerspoon side of docs/keybindings.md.
--
-- Karabiner turns Right Option into F19 while held (operating-system layer)
-- and Right Command into F18 while held (app layer). This file watches
-- those two keys and runs the layer grammar: AeroSpace for the operating
-- system, and each app's own shortcut or menu item for the app layer.
--
--   bindings.lua   which key runs which verb, and the overlay text
--   targets.lua    what each verb does on the operating system and in each app
--   actions.lua    carrying out an action, and posting events
--   aerospace.lua  the AeroSpace command queue
--   switcher.lua   the window search behind Open document and Fn
--   overlay.lua    the overlay canvas
--
-- AeroSpace stays in main with an empty binding table.

require("hs.ipc") -- lets the `hs` command run Lua in this config

local actions = require("actions")
local bindings = require("bindings")
local overlay = require("overlay")
local switcher = require("switcher")
local targets = require("targets")

local log = hs.logger.new("keybindings", "warning")

local LAYERS = { "os", "app" }

local F18 = hs.keycodes.map.f18
local F19 = hs.keycodes.map.f19
local FN = hs.keycodes.map.fn

local ALIAS = {
  backslash = "\\",
  quote = "'",
  semicolon = ";",
  equal = "=",
  minus = "-",
  leftbracket = "[",
  rightbracket = "]",
  padenter = "return",
}

local function onLayer(row, layer)
  return row.layer == nil or row.layer == layer
end

local function eachKey(row, fn)
  local keys = row.keys
  if type(keys) == "string" then keys = { keys } end
  if #keys > 0 then
    for _, key in ipairs(keys) do
      fn(key, row.arg and row.arg(key) or key)
    end
  else
    for key, arg in pairs(keys) do fn(key, arg) end
  end
end

-- index[shift][key] is { row = row, arg = arg } for the rows on `layer`.
local function compile(rows, layer)
  local index = { [false] = {}, [true] = {} }
  for _, row in ipairs(rows) do
    if onLayer(row, layer) then
      local shift = row.shift == true
      eachKey(row, function(key, arg)
        if index[shift][key] then
          log.w(("%s layer binds %s%s twice"):format(layer, shift and "shift+" or "", key))
        end
        index[shift][key] = { row = row, arg = arg }
      end)
    end
  end
  return index
end

local layerRows = {}
for _, column in ipairs(bindings.layer) do
  for _, row in ipairs(column) do layerRows[#layerRows + 1] = row end
end

local LAYER_INDEX, CHORD_INDEX = {}, {}
for _, layer in ipairs(LAYERS) do
  LAYER_INDEX[layer] = compile(layerRows, layer)
  for name, chord in pairs(bindings.chords) do
    CHORD_INDEX[name] = CHORD_INDEX[name] or {}
    CHORD_INDEX[name][layer] = compile(chord.rows, layer)[false]
  end
end

-- A misspelled name fails silently at the key, so names are checked at load.
local function checkNames()
  local warned, used = {}, {}
  local function warn(message)
    if not warned[message] then
      warned[message] = true
      log.w(message)
    end
  end
  local function check(layer, row)
    if row.verb then
      used[row.verb] = true
      if layer == "os" and targets.system[row.verb] == nil then
        warn("the operating system has no " .. row.verb)
      end
    end
    if row.run and not actions.commands[row.run] then warn("no command " .. row.run) end
    if row.chord and not CHORD_INDEX[row.chord] then warn("no chord " .. row.chord) end
  end
  for _, layer in ipairs(LAYERS) do
    for _, keys in pairs(LAYER_INDEX[layer]) do
      for _, binding in pairs(keys) do
        check(layer, binding.row)
        local chord = CHORD_INDEX[binding.row.chord]
        if chord then
          for _, inner in pairs(chord[layer]) do check(layer, inner.row) end
        end
      end
    end
  end
  local function unused(name, target)
    for verb in pairs(target) do
      if not used[verb] then warn(name .. " defines " .. verb .. ", which no key runs") end
    end
  end
  unused("the operating system", targets.system)
  for bundle, app in pairs(targets.apps) do unused(bundle, app) end
end

checkNames()

local function resolve(target, verb, arg)
  local cell = target[verb]
  if type(cell) == "function" then return cell(arg) end
  if type(cell) == "table" and not cell.kind then return cell[arg] end
  return cell
end

local function frontApp()
  local app = hs.application.frontmostApplication()
  local bundle = app and app:bundleID()
  return bundle and targets.apps[bundle] or nil
end

local function deliver(layer, binding, key)
  local row = binding.row
  if row.run then
    actions.commands[row.run](key)
  elseif layer == "os" then
    actions.run(resolve(targets.system, row.verb, binding.arg))
  else
    local app = frontApp()
    if app then actions.run(resolve(app, row.verb, binding.arg)) end
  end
end

local osDown, appDown = false, false
local lastHeld = nil
local locked = nil
local chord = nil -- { name, layer, def, index } while a chord waits for its key
local session = nil -- { kind = "move"|"focus", query, selected } while a window search is open
local fnDown = false
local swallowed = {}

local function layerFromHold()
  if osDown and appDown then return lastHeld end
  if osDown then return "os" end
  if appDown then return "app" end
  return nil
end

local function activeLayer()
  return locked or layerFromHold()
end

local function overlayRows(rows, layer)
  local shown = {}
  for _, row in ipairs(rows) do
    if row.label and onLayer(row, layer) then shown[#shown + 1] = row end
  end
  return shown
end

local function showLayerOverlay()
  local layer = activeLayer()
  if not layer then return end
  local columns = {}
  for i, column in ipairs(bindings.layer) do
    columns[i] = overlayRows(column, layer)
  end
  local title = bindings.title[layer]
  if locked then title = title .. "  ·  locked" end
  overlay.show({
    layer = layer,
    title = title,
    columns = columns,
    footer = "space locks      esc clears",
  })
end

local function showChordOverlay()
  if not chord then return end
  overlay.show({
    layer = chord.layer,
    title = chord.def.title,
    rows = overlayRows(chord.def.rows, chord.layer),
    footer = "esc cancels",
  })
end

local function scheduleLayerOverlay()
  overlay.later(function()
    if not chord and not session then showLayerOverlay() end
  end)
end

local function endChord()
  chord = nil
  overlay.hide()
  if locked then scheduleLayerOverlay() end
end

local function beginChord(name, layer)
  chord = {
    name = name,
    layer = layer,
    def = bindings.chords[name],
    index = CHORD_INDEX[name][layer],
  }
  overlay.hide()
  overlay.later(showChordOverlay)
end

local function onBinding()
  overlay.hide()
  if locked and not chord then scheduleLayerOverlay() end
end

local function keyName(code)
  local name = hs.keycodes.map[code]
  if type(name) ~= "string" then return nil end
  return ALIAS[name] or name
end

local function blocked(flags)
  return flags.cmd or flags.alt or flags.ctrl
end

local function queryChar(name)
  if not name then return nil end
  if name == "space" then return " " end
  if #name == 1 then return name:lower() end
  return nil
end

local function showSession()
  if not session then return end
  local rows, selected = switcher.rows(session.query, session.selected)
  session.selected = selected
  overlay.show({
    layer = "os",
    title = session.query ~= "" and session.query or "Windows",
    rows = rows,
    footer = session.kind == "move"
      and "up down select      return brings here      esc cancels"
      or "release focuses      esc cancels",
    colW = 520,
    verbShare = 0.34,
  })
end

switcher.updated = function()
  if session then showSession() end
end

local function endSession()
  session = nil
  swallowed = {}
  overlay.hide()
  if locked then
    scheduleLayerOverlay()
  elseif layerFromHold() then
    scheduleLayerOverlay()
  end
end

local function beginSession(kind)
  session = { kind = kind, query = "", selected = 1 }
  switcher.refresh()
  showSession()
end

local function handleMoveKey(name)
  if not name or not session then return end
  if name == "escape" then
    endSession()
    return
  end
  if name == "return" then
    local chosen = switcher.pick(session.query, session.selected)
    if not chosen then return end
    endSession()
    switcher.bring(chosen)
    return
  end
  if name == "delete" then
    session.query = session.query:sub(1, -2)
    session.selected = 1
    showSession()
    return
  end
  if name == "down" or name == "up" then
    local matches = switcher.matches(session.query)
    if name == "down" and session.selected < #matches then
      session.selected = session.selected + 1
    elseif name == "up" and session.selected > 1 then
      session.selected = session.selected - 1
    end
    showSession()
    return
  end
  local ch = queryChar(name)
  if not ch then return end
  session.query = session.query .. ch
  session.selected = 1
  showSession()
end

-- A letter starts the Fn search. Delete and escape apply only once it is open.
local function focusSearchKey(name)
  if queryChar(name) then return true end
  return session and session.kind == "focus" and (name == "delete" or name == "escape")
end

local function pressFn()
  if fnDown then return end
  fnDown = true
  if not session and not activeLayer() and not chord then
    overlay.later(function()
      if session or not fnDown then return end
      beginSession("focus")
    end)
  end
end

-- The globe key often arrives as a flags change and never as a key-up.
local function releaseFn()
  local searching = session and session.kind == "focus"
  if not fnDown and not searching then return end
  fnDown = false
  if searching then
    local chosen = session.query ~= "" and switcher.pick(session.query, session.selected) or nil
    endSession()
    if chosen then switcher.focus(chosen) end
  elseif not activeLayer() and not chord and not session then
    overlay.hide()
  end
end

local function onFocusKey(name)
  if name == "escape" then
    if session and session.kind == "focus" then endSession() end
    return
  end
  if name == "delete" then
    if not (session and session.kind == "focus") then return end
    session.query = session.query:sub(1, -2)
    session.selected = 1
    showSession()
    return
  end
  local ch = queryChar(name)
  if not ch or (session and session.kind ~= "focus") then return end
  if not session then
    session = { kind = "focus", query = "", selected = 1 }
    switcher.refresh()
  end
  session.query = session.query .. ch
  session.selected = 1
  showSession()
end

local function arm(which)
  if which == "os" then osDown = true else appDown = true end
  lastHeld = which
  if session and session.kind == "focus" then session = nil end
  if chord or locked or session then return end
  overlay.hide()
  scheduleLayerOverlay()
end

local function release(which)
  if which == "os" then osDown = false else appDown = false end
  if locked or chord or session then return end
  overlay.hide()
  if layerFromHold() then scheduleLayerOverlay() end
end

local function unlock()
  if not locked then return end
  locked = nil
  overlay.hide()
  if layerFromHold() then scheduleLayerOverlay() end
end

local function handleChord(name, shift, flags)
  local binding = not blocked(flags) and not shift and chord.index[name]
  if binding then deliver(chord.layer, binding, name) end
  endChord()
end

local function handleLayer(name, shift, flags)
  local layer = activeLayer()
  if not layer or blocked(flags) then return end

  if name == "escape" then
    unlock()
    return
  end

  if name == "space" and not shift then
    locked = layer
    onBinding()
    return
  end

  local binding = LAYER_INDEX[layer][shift][name]
  if not binding then return end

  if binding.row.chord then
    beginChord(binding.row.chord, layer)
    return
  end

  if binding.row.switcher then
    beginSession(binding.row.switcher)
    return
  end

  deliver(layer, binding, name)
  onBinding()
end

local function handle(event)
  if actions.isMarked(event) or actions.isExpected(event) then return false end
  local code = event:getKeyCode()
  local kind = event:getType()
  local isDown = kind == hs.eventtap.event.types.keyDown
  local isRepeat = event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 0
  local flags = event:getFlags()

  -- Letting go of the globe key is a flags change. A key-up often never arrives.
  -- A press can be a flags change too, and that one still has the Fn flag.
  if kind == hs.eventtap.event.types.flagsChanged then
    if flags.fn then
      pressFn()
    elseif fnDown or (session and session.kind == "focus") then
      releaseFn()
    end
    return false
  end

  if code == F18 or code == F19 then
    if isRepeat then return true end
    local which = code == F18 and "app" or "os"
    if isDown then arm(which) else release(which) end
    swallowed[code] = nil
    return true
  end

  -- A key-down still starts the search on keyboards that send one. Letters
  -- held with Fn narrow it, and releasing Fn focuses the match.
  if code == FN then
    if isDown then
      if isRepeat then return true end
      pressFn()
    else
      releaseFn()
    end
    return false
  end

  if session and session.kind == "move" then
    if not isDown then
      swallowed[code] = nil
      return true
    end
    swallowed[code] = true
    if not isRepeat or keyName(code) == "delete" then handleMoveKey(keyName(code)) end
    return true
  end

  if not isDown then
    if swallowed[code] then
      swallowed[code] = nil
      return true
    end
    return false
  end

  local name = keyName(code)
  -- Escape cancels even after Fn is already up. The key often has no Fn flag.
  if session and session.kind == "focus" and name == "escape" and not isRepeat then
    swallowed[code] = true
    endSession()
    return true
  end
  if flags.fn and not blocked(flags) and not activeLayer() and not chord and name and focusSearchKey(name) then
    if isRepeat and name ~= "delete" then
      swallowed[code] = true
      return true
    end
    onFocusKey(name)
    swallowed[code] = true
    return true
  end

  if not activeLayer() and not chord then return false end

  swallowed[code] = true
  if not name or isRepeat then return true end
  local shift = flags.shift == true
  if chord then
    handleChord(name, shift, flags)
  else
    handleLayer(name, shift, flags)
  end
  return true
end

-- A tap stored only in a local is collected and stops.
Keybindings = {}
Keybindings.tap = hs.eventtap.new({
  hs.eventtap.event.types.keyDown,
  hs.eventtap.event.types.keyUp,
  hs.eventtap.event.types.flagsChanged,
}, handle)
Keybindings.tap:start()
