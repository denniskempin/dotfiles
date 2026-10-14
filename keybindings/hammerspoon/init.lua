-- Hammerspoon side of keybindings/keybindings.md.
--
-- Karabiner turns Caps Lock into F18 while held and Escape when tapped, and
-- Fn into F19 while held and the globe key when tapped. This file watches
-- those two keys and runs the layer grammar: AeroSpace for the operating
-- system, and each app's own shortcut or menu item for the app layer.
--
-- AeroSpace stays in main with an empty binding table. Its on-focus-changed
-- callback should be:
--
--   on-focus-changed = ['exec-and-forget hs -c "Keybindings.onFocusChanged()"']
--
-- `hs` is Hammerspoon's IPC command. The callback appends the focused
-- application to the history stack. [ and ] move the cursor and focus that
-- application, with a flag set so their own focus change is not recorded.

local log = hs.logger.new("keybindings", "warning")

local MARK = 0x4B424C31 -- marks events this file posts, so the tap ignores them
local OVERLAY_DELAY = 0.25
local RESIZE_IDLE = 1
local CHORD_GAP = 0.02

local F18 = hs.keycodes.map.f18
local F19 = hs.keycodes.map.f19

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

local ARROW = { left = true, down = true, up = true, right = true }
local FKEY = {}
for i = 1, 12 do FKEY["f" .. i] = true end

local RESIZE = {
  left = { "width", "-50" },
  right = { "width", "+50" },
  down = { "height", "+50" },
  up = { "height", "-50" },
}

local function aerospacePath()
  for _, path in ipairs({ "/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace" }) do
    if hs.fs.attributes(path) then return path end
  end
  return "aerospace"
end

local AEROSPACE = aerospacePath()

local function quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function aero(args, quiet)
  local cmd = { quote(AEROSPACE) }
  for i, arg in ipairs(args) do
    cmd[i + 1] = quote(arg)
  end
  local out, ok = hs.execute(table.concat(cmd, " "))
  if not ok and not quiet then
    log.w("aerospace " .. table.concat(args, " "))
  end
  return ok, out or ""
end

local function lines(text)
  local result = {}
  for line in tostring(text):gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then result[#result + 1] = trimmed end
  end
  return result
end

-- GNU sort -V. Workspace names are short; digit runs compare as numbers.
local function versionLess(a, b)
  local ia, ib = 1, 1
  while ia <= #a and ib <= #b do
    local da, db = a:match("^%d+", ia), b:match("^%d+", ib)
    if da or db then
      local va = tonumber(da) or -1
      local vb = tonumber(db) or -1
      if va ~= vb then return va < vb end
      ia = ia + (da and #da or 0)
      ib = ib + (db and #db or 0)
    else
      local ca, cb = a:sub(ia, ia), b:sub(ib, ib)
      if ca ~= cb then return ca < cb end
      ia, ib = ia + 1, ib + 1
    end
  end
  return #a < #b
end

local function workspaceSequence()
  local okEmpty, emptyOut = aero({ "list-workspaces", "--monitor", "focused", "--empty", "no" }, true)
  local okFocus, focusOut = aero({ "list-workspaces", "--focused" }, true)
  local names, seen = {}, {}
  local function add(name)
    if name and name ~= "" and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  if okEmpty then
    for _, name in ipairs(lines(emptyOut)) do add(name) end
  end
  local focused = okFocus and lines(focusOut)[1] or nil
  add(focused)
  table.sort(names, versionLess)
  return names, focused
end

local function lastNonEmptyWorkspace()
  local ok, out = aero({ "list-workspaces", "--monitor", "focused", "--empty", "no" }, true)
  if not ok then return nil end
  local names = lines(out)
  table.sort(names, versionLess)
  return names[#names]
end

local function stepName(dir)
  local names, current = workspaceSequence()
  if not current or #names == 0 then return nil end
  local index
  for i, name in ipairs(names) do
    if name == current then index = i break end
  end
  if not index then return nil end
  local n = index + (dir == "next" and 1 or -1)
  if n < 1 then n = #names elseif n > #names then n = 1 end
  return names[n]
end

local function focusDir(dir)
  aero({
    "focus",
    "--boundaries", "all-monitors-outer-frame",
    "--boundaries-action", "wrap-around-all-monitors",
    dir,
  })
end

local function moveDir(dir)
  aero({
    "move",
    "--boundaries", "all-monitors-outer-frame",
    "--boundaries-action", "create-implicit-container",
    dir,
  })
end

local function switchWorkspace(dir)
  local name = stepName(dir)
  if name then aero({ "workspace", name }) end
end

local function sendToWorkspace(dir)
  local name = stepName(dir)
  if name then aero({ "move-node-to-workspace", "--focus-follows-window", name }) end
end

local function jumpWorkspace(n)
  if n == 9 then
    local name = lastNonEmptyWorkspace()
    if name then aero({ "workspace", name }) end
  else
    aero({ "workspace", tostring(n) })
  end
end

local function sendToNumber(n)
  if n == 9 then
    local name = lastNonEmptyWorkspace()
    if name then aero({ "move-node-to-workspace", "--focus-follows-window", name }) end
  else
    aero({ "move-node-to-workspace", "--focus-follows-window", tostring(n) })
  end
end

local history = { stack = {}, cursor = 0, ignore = nil }

local function focusedApp()
  local ok, out = aero({
    "list-windows", "--focused",
    "--format", "%{app-bundle-id}\t%{app-name}",
  }, true)
  if not ok then return nil end
  local bundle, name = out:match("^(%S+)\t(.-)%s*$")
  if not bundle or bundle == "" then return nil end
  return { bundleID = bundle, name = name }
end

local function onFocusChanged()
  local app = focusedApp()
  if history.ignore then
    local expected = history.ignore
    history.ignore = nil
    if app and app.bundleID == expected then return end
  end
  if not app then return end
  while #history.stack > history.cursor do
    table.remove(history.stack)
  end
  local current = history.stack[history.cursor]
  if current and current.bundleID == app.bundleID then return end
  history.stack[#history.stack + 1] = app
  history.cursor = #history.stack
end

local function walkHistory(delta)
  local dest = history.cursor + delta
  if dest < 1 or dest > #history.stack then return end
  history.cursor = dest
  local entry = history.stack[dest]
  history.ignore = entry.bundleID
  hs.timer.doAfter(0.8, function()
    if history.ignore == entry.bundleID then history.ignore = nil end
  end)
  hs.timer.doAfter(0, function()
    hs.application.launchOrFocusByBundleID(entry.bundleID)
  end)
end

local function mark(event)
  if event then
    pcall(function()
      event:setProperty(hs.eventtap.event.properties.eventSourceUserData, MARK)
    end)
  end
  return event
end

local function isMarked(event)
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
    postKey(step.mods or {}, step.key)
    if steps[i + 1] then hs.timer.doAfter(CHORD_GAP, function() go(i + 1) end) end
  end
  go(1)
end

local function pressSystem(name)
  local down = mark(hs.eventtap.event.newSystemKeyEvent(name, true))
  local up = mark(hs.eventtap.event.newSystemKeyEvent(name, false))
  if down then down:post() end
  if up then up:post() end
end

local function postHyper(key, shift)
  local mods = { "cmd", "alt", "ctrl" }
  if shift then mods[#mods + 1] = "shift" end
  postKey(mods, key)
end

local fnCache = { value = false, at = 0 }
local focusWarned = false

local function functionKeysAreStandard()
  local now = hs.timer.secondsSinceEpoch()
  if now - fnCache.at < 2 then return fnCache.value end
  local out, ok = hs.execute("/usr/bin/defaults read -g com.apple.keyboard.fnState")
  fnCache.value = ok and out and out:match("^%s*1") ~= nil or false
  fnCache.at = now
  return fnCache.value
end

-- Glyphs on the MacBook Pro 14-inch (2021) function row. Brightness, transport,
-- and volume are system keys. Mission Control, Spotlight, and Dictation have no
-- Hammerspoon system-key name, so those three run the feature directly.
local function postFlippedFunction(name)
  if not functionKeysAreStandard() then
    postKey({}, name)
    return
  end
  local system = {
    f1 = "BRIGHTNESS_DOWN",
    f2 = "BRIGHTNESS_UP",
    f7 = "PREVIOUS",
    f8 = "PLAY",
    f9 = "NEXT",
    f10 = "MUTE",
    f11 = "SOUND_DOWN",
    f12 = "SOUND_UP",
  }
  if system[name] then
    pressSystem(system[name])
    return
  end
  hs.timer.doAfter(0, function()
    if name == "f3" then
      pcall(function() hs.spaces.toggleMissionControl() end)
    elseif name == "f4" then
      hs.application.launchOrFocusByBundleID("com.apple.Spotlight")
    elseif name == "f5" then
      local app = hs.application.frontmostApplication()
      if app then
        if not app:selectMenuItem({ "Edit", "Start Dictation" }) then
          app:selectMenuItem("Start Dictation")
        end
      end
    elseif name == "f6" then
      -- The moon key toggles Focus. It is a generic-desktop do-not-disturb
      -- event, which Hammerspoon cannot post, and this Mac has no shortcut
      -- assigned for it.
      if not focusWarned then
        focusWarned = true
        log.w("Focus (F6) has no postable system key")
      end
    end
  end)
end

local function stroke(mods, key)
  return { mods = mods, key = key }
end

local function seq(first, second)
  return { strokes = { first, second } }
end

local function menu(...)
  return { menu = { ... } }
end

local ITERM_BACK = [[
tell application "iTerm2"
  tell current session of current window
    write text (character id 27) & "[91;7u" newline false
  end tell
end tell
]]

local ITERM_FORWARD = [[
tell application "iTerm2"
  tell current session of current window
    write text (character id 27) & "[93;7u" newline false
  end tell
end tell
]]

local function paneItem(dir)
  return ({
    left = "Select Pane Left",
    down = "Select Pane Below",
    up = "Select Pane Above",
    right = "Select Pane Right",
  })[dir]
end

local function dividerItem(dir)
  return ({
    left = "Move Divider Left",
    down = "Move Divider Down",
    up = "Move Divider Up",
    right = "Move Divider Right",
  })[dir]
end

local APPS = {
  ["com.google.Chrome"] = {
    switchPrev = stroke({ "cmd", "shift" }, "["),
    switchNext = stroke({ "cmd", "shift" }, "]"),
    jump = function(n) return stroke({ "cmd" }, tostring(n)) end,
    sendPrev = stroke({ "ctrl", "shift" }, "pageup"),
    sendNext = stroke({ "ctrl", "shift" }, "pagedown"),
    back = stroke({ "cmd" }, "["),
    forward = stroke({ "cmd" }, "]"),
    command = stroke({ "cmd", "shift" }, "/"),
    open = stroke({ "cmd", "shift" }, "a"),
  },
  ["com.microsoft.VSCode"] = {
    focus = function(dir)
      return seq(stroke({ "cmd" }, "k"), stroke({ "cmd" }, dir))
    end,
    zoom = seq(stroke({ "cmd" }, "k"), stroke({ "cmd" }, "m")),
    switchPrev = seq(stroke({ "cmd" }, "k"), stroke({ "cmd", "alt" }, "left")),
    switchNext = seq(stroke({ "cmd" }, "k"), stroke({ "cmd", "alt" }, "right")),
    jump = function(n)
      if n == 9 then return stroke({ "cmd" }, "9") end
      return stroke({ "ctrl" }, tostring(n))
    end,
    sendPrev = seq(stroke({ "cmd" }, "k"), stroke({ "cmd", "shift" }, "left")),
    sendNext = seq(stroke({ "cmd" }, "k"), stroke({ "cmd", "shift" }, "right")),
    back = stroke({ "ctrl" }, "-"),
    forward = stroke({ "ctrl", "shift" }, "-"),
    close = stroke({ "cmd" }, "w"),
    command = stroke({ "cmd", "shift" }, "p"),
    open = stroke({ "cmd" }, "p"),
    split = function() return stroke({ "cmd" }, "\\") end,
    layoutFlip = stroke({ "cmd", "alt" }, "0"),
  },
  ["com.googlecode.iterm2"] = {
    focus = function(dir)
      local item = paneItem(dir)
      return menu(
        { "Window", "Select Split Pane", item },
        { "Window", "Split Pane", "Select Split Pane", item },
        item
      )
    end,
    zoom = menu({ "View", "Maximize Active Pane" }, "Maximize Active Pane"),
    switchPrev = stroke({ "cmd" }, "left"),
    switchNext = stroke({ "cmd" }, "right"),
    jump = function(n) return stroke({ "cmd" }, tostring(n)) end,
    sendPrev = stroke({ "cmd", "shift" }, "left"),
    sendNext = stroke({ "cmd", "shift" }, "right"),
    back = { iterm = ITERM_BACK },
    forward = { iterm = ITERM_FORWARD },
    close = stroke({ "cmd" }, "w"),
    command = stroke({ "cmd", "shift" }, "/"),
    open = menu({ "View", "Open Quickly" }, "Open Quickly"),
    split = function(dir)
      if dir == "down" then return stroke({ "cmd", "shift" }, "d") end
      if dir == "right" then return stroke({ "cmd" }, "d") end
    end,
    resize = function(dir)
      local item = dividerItem(dir)
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
  },
  ["md.obsidian"] = {
    switchPrev = stroke({ "cmd", "shift" }, "["),
    switchNext = stroke({ "cmd", "shift" }, "]"),
    jump = function(n) return stroke({ "cmd" }, tostring(n)) end,
    back = stroke({ "cmd", "alt" }, "left"),
    forward = stroke({ "cmd", "alt" }, "right"),
    close = stroke({ "cmd" }, "w"),
    command = stroke({ "cmd" }, "p"),
    open = stroke({ "cmd" }, "o"),
    split = function(dir)
      if dir == "down" then return menu({ "Split down" }, "Split down") end
      if dir == "right" then return menu({ "Split right" }, "Split right") end
    end,
  },
}

local function selectMenu(app, spec)
  for _, path in ipairs(spec) do
    if app:selectMenuItem(path) then return true end
  end
  return false
end

local function runAction(action)
  if not action then return end
  if action.menu or action.iterm or action.launch then
    hs.timer.doAfter(0, function()
      if action.launch then
        hs.application.launchOrFocusByBundleID(action.launch)
        return
      end
      if action.iterm then
        hs.osascript.applescript(action.iterm)
        return
      end
      local app = hs.application.frontmostApplication()
      if app then selectMenu(app, action.menu) end
    end)
    return
  end
  if action.strokes then
    postSequence(action.strokes)
    return
  end
  postKey(action.mods or {}, action.key)
end

local function frontAppSpec()
  local app = hs.application.frontmostApplication()
  local bundle = app and app:bundleID()
  if bundle and APPS[bundle] then return APPS[bundle] end
  return nil
end

-- Known apps get the cell from the spec. A dash or "Unbound" cell is nil,
-- so nothing is posted. Any other frontmost app gets Hyper plus the key.
local function deliverApp(produce, key, shift)
  local spec = frontAppSpec()
  if not spec then
    postHyper(key, shift)
    return
  end
  local action = produce(spec)
  if type(action) == "function" then action = action() end
  runAction(action)
end

local OS_ACCENT = { hex = "#8EBEFF" }
local APP_ACCENT = { hex = "#E7C27A" }

local LAYER_ROWS = {
  os = {
    title = "System",
    accent = OS_ACCENT,
    columns = {
      {
        { "Focus tile", "← ↓ ↑ →" },
        { "Move tile", "⇧ ← ↓ ↑ →" },
        { "Zoom tile", "↩" },
        { "Close tile", "X" },
        { "Resize tile", "S then arrows" },
        { "Layout tiles", "L then F A =" },
        { "Join tile", "J then arrow" },
      },
      {
        { "Switch slot", ";  '" },
        { "Jump to slot", "1–8   9" },
        { "Send to slot", "⇧ ; ' 1–9" },
        { "Walk history", "[  ]" },
        { "Run command", "P" },
        { "Open document", "O" },
        { "Focus monitor", "⇥" },
        { "Send slot", "⇧ ⇥" },
      },
    },
  },
  app = {
    title = "App",
    accent = APP_ACCENT,
    columns = {
      {
        { "Focus tile", "← ↓ ↑ →" },
        { "Move tile", "⇧ ← ↓ ↑ →" },
        { "Zoom tile", "↩" },
        { "Close tile", "X" },
        { "Split tile", "\\ then arrow" },
        { "Resize tile", "S then arrows" },
        { "Layout tiles", "L then F =" },
      },
      {
        { "Switch slot", ";  '" },
        { "Jump to slot", "1–8   9" },
        { "Send to slot", "⇧ ; ' 1–9" },
        { "Walk history", "[  ]" },
        { "Run command", "P" },
        { "Open document", "O" },
      },
    },
  },
}

local CHORD_ROWS = {
  resize = {
    title = "Resize",
    rows = {
      { "Shrink width", "←" },
      { "Grow width", "→" },
      { "Grow height", "↓" },
      { "Shrink height", "↑" },
    },
  },
  split = {
    title = "Split",
    rows = {
      { "Left", "←" },
      { "Down", "↓" },
      { "Up", "↑" },
      { "Right", "→" },
    },
  },
  join = {
    title = "Join",
    rows = {
      { "Left", "←" },
      { "Down", "↓" },
      { "Up", "↑" },
      { "Right", "→" },
    },
  },
  layout = {
    title = "Layout",
    rows = {
      { "Flip axis", "F" },
      { "Tiled / accordion", "A" },
      { "Equalize", "=" },
    },
  },
}

local canvas
local pendingOverlay
local resizeTimer

local osDown, appDown = false, false
local lastHeld = nil
local locked = nil
local chord = nil
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

local function cancelPending()
  if pendingOverlay then
    pendingOverlay:stop()
    pendingOverlay = nil
  end
end

local function afterDelay(fn)
  cancelPending()
  pendingOverlay = hs.timer.doAfter(OVERLAY_DELAY, function()
    pendingOverlay = nil
    fn()
  end)
end

local function hideOverlay()
  if canvas then canvas:hide() end
end

local function render(spec)
  local screen = hs.screen.mainScreen()
  if not screen then return end
  local columns = spec.columns
  local rowCount = spec.rows and #spec.rows or 0
  if columns then
    for _, column in ipairs(columns) do
      rowCount = math.max(rowCount, #column)
    end
  end
  local pad, titleH, rowH, footerH, gap = 16, 28, 22, 22, 18
  local colW = columns and 248 or 280
  local nCols = columns and #columns or 1
  local width = pad * 2 + colW * nCols + gap * (nCols - 1)
  local height = pad + titleH + 6 + rowCount * rowH + footerH + 8
  local frame = screen:frame()
  local rect = {
    x = frame.x + (frame.w - width) / 2,
    y = frame.y + frame.h - height - 24,
    w = width,
    h = height,
  }
  if not canvas then
    canvas = hs.canvas.new(rect)
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:clickActivating(false)
    pcall(function()
      local behaviors = hs.canvas.windowBehaviors
      canvas:behavior(behaviors.canJoinAllSpaces | behaviors.stationary | behaviors.ignoresCycle)
    end)
  else
    canvas:frame(rect)
  end

  local accent = spec.accent
  local elements = {
    {
      type = "rectangle",
      action = "fill",
      fillColor = { hex = "#1C1C1E", alpha = 0.94 },
      roundedRectRadii = { xRadius = 14, yRadius = 14 },
      frame = { x = 0, y = 0, w = width, h = height },
    },
    {
      type = "rectangle",
      action = "stroke",
      strokeColor = { white = 1, alpha = 0.08 },
      strokeWidth = 1,
      roundedRectRadii = { xRadius = 14, yRadius = 14 },
      frame = { x = 0.5, y = 0.5, w = width - 1, h = height - 1 },
    },
    {
      type = "text",
      text = spec.title,
      textColor = accent,
      textSize = 15,
      textFont = ".AppleSystemUIFont",
      frame = { x = pad, y = pad, w = width - pad * 2, h = titleH },
    },
  }
  local function addRow(verb, keys, x, y)
    local verbW = math.floor(colW * 0.56)
    elements[#elements + 1] = {
      type = "text",
      text = verb,
      textColor = { white = 0.92 },
      textSize = 13,
      textFont = ".AppleSystemUIFont",
      frame = { x = x, y = y, w = verbW, h = rowH },
    }
    elements[#elements + 1] = {
      type = "text",
      text = keys,
      textColor = accent,
      textSize = 13,
      textFont = ".AppleSystemUIFont",
      textAlignment = "right",
      frame = { x = x + verbW, y = y, w = colW - verbW, h = rowH },
    }
  end
  local top = pad + titleH + 4
  if columns then
    for c, column in ipairs(columns) do
      local x = pad + (c - 1) * (colW + gap)
      for r, row in ipairs(column) do
        addRow(row[1], row[2], x, top + (r - 1) * rowH)
      end
    end
  else
    for r, row in ipairs(spec.rows) do
      addRow(row[1], row[2], pad, top + (r - 1) * rowH)
    end
  end
  elements[#elements + 1] = {
    type = "text",
    text = spec.footer,
    textColor = { white = 0.45 },
    textSize = 12,
    textFont = ".AppleSystemUIFont",
    frame = { x = pad, y = height - footerH - 6, w = width - pad * 2, h = footerH },
  }
  canvas:replaceElements(elements)
  canvas:show()
end

local function showLayerOverlay()
  local layer = locked or layerFromHold()
  local spec = layer and LAYER_ROWS[layer]
  if not spec then return end
  local title = spec.title
  if locked then title = title .. "  ·  locked" end
  render({
    title = title,
    accent = spec.accent,
    columns = spec.columns,
    footer = "space locks      esc clears",
  })
end

local function showChordOverlay()
  if not chord then return end
  local spec = CHORD_ROWS[chord.kind]
  local rows = spec.rows
  if chord.kind == "layout" and chord.layer == "app" then
    rows = {
      { "Flip axis", "F" },
      { "Equalize", "=" },
    }
  end
  render({
    title = spec.title,
    accent = chord.layer == "os" and OS_ACCENT or APP_ACCENT,
    rows = rows,
    footer = "esc cancels",
  })
end

local function scheduleLayerOverlay()
  afterDelay(function()
    if chord then return end
    if locked or layerFromHold() then showLayerOverlay() end
  end)
end

local function scheduleChordOverlay()
  afterDelay(function()
    if chord then showChordOverlay() end
  end)
end

local function stopResizeTimer()
  if resizeTimer then
    resizeTimer:stop()
    resizeTimer = nil
  end
end

local function endChord()
  chord = nil
  stopResizeTimer()
  hideOverlay()
  cancelPending()
  if locked then scheduleLayerOverlay() end
end

local function beginChord(kind, layer)
  chord = { kind = kind, layer = layer }
  hideOverlay()
  cancelPending()
  scheduleChordOverlay()
end

local function noteResize()
  stopResizeTimer()
  resizeTimer = hs.timer.doAfter(RESIZE_IDLE, function()
    resizeTimer = nil
    if chord and chord.kind == "resize" then endChord() end
  end)
  cancelPending()
  showChordOverlay()
end

local function onBinding()
  hideOverlay()
  cancelPending()
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

local function arm(which)
  if which == "os" then osDown = true else appDown = true end
  lastHeld = which
  if chord or locked then return end
  hideOverlay()
  scheduleLayerOverlay()
end

local function release(which)
  if which == "os" then osDown = false else appDown = false end
  if locked or chord then return end
  if layerFromHold() then
    hideOverlay()
    scheduleLayerOverlay()
    return
  end
  cancelPending()
  hideOverlay()
end

local function handleChord(name, shift, flags)
  if name == "escape" and not blocked(flags) then
    endChord()
    return
  end
  if blocked(flags) or shift then
    endChord()
    return
  end
  local kind, layer = chord.kind, chord.layer
  if kind == "resize" and ARROW[name] then
    if layer == "os" then
      local spec = RESIZE[name]
      aero({ "resize", spec[1], spec[2] })
    else
      deliverApp(function(app) return app.resize and app.resize(name) end, name, false)
    end
    noteResize()
    return
  end
  if kind == "join" and ARROW[name] then
    aero({ "join-with", name })
    endChord()
    return
  end
  if kind == "split" and ARROW[name] then
    deliverApp(function(app) return app.split and app.split(name) end, name, false)
    endChord()
    return
  end
  if kind == "layout" and (name == "f" or name == "=" or (layer == "os" and name == "a")) then
    if layer == "os" then
      if name == "f" then aero({ "layout", "horizontal", "vertical" })
      elseif name == "a" then aero({ "layout", "tiles", "accordion" })
      else aero({ "balance-sizes" }) end
    else
      deliverApp(function(app)
        if name == "f" then return app.layoutFlip end
        if name == "=" then return app.layoutEqual end
      end, name, false)
    end
    endChord()
    return
  end
  endChord()
end

local function handleLayer(name, shift, flags)
  local layer = activeLayer()
  if not layer then return end
  if blocked(flags) then return end

  if name == "escape" then
    if locked then
      locked = nil
      if layerFromHold() then
        hideOverlay()
        scheduleLayerOverlay()
      else
        cancelPending()
        hideOverlay()
      end
    end
    return
  end

  if name == "space" and not shift then
    locked = layer
    onBinding()
    return
  end

  if layer == "app" and name == "delete" and not shift then
    postKey({}, "forwarddelete")
    onBinding()
    return
  end

  if layer == "app" and FKEY[name] and not shift then
    postFlippedFunction(name)
    onBinding()
    return
  end

  if not shift then
    local chordKind
    if layer == "os" and (name == "s" or name == "l" or name == "j") then
      chordKind = name == "s" and "resize" or name == "l" and "layout" or "join"
    elseif layer == "app" and (name == "s" or name == "l" or name == "\\") then
      chordKind = name == "s" and "resize" or name == "l" and "layout" or "split"
    end
    if chordKind then
      if layer == "app" and not frontAppSpec() then postHyper(name, false) end
      beginChord(chordKind, layer)
      return
    end
  end

  local n = not blocked(flags) and name:match("^([1-9])$")
  n = n and tonumber(n)

  if ARROW[name] then
    if layer == "os" then
      if shift then moveDir(name) else focusDir(name) end
    else
      deliverApp(function(app)
        if shift then return app.move and app.move(name) end
        return app.focus and app.focus(name)
      end, name, shift)
    end
    onBinding()
    return
  end

  if n then
    if layer == "os" then
      if shift then sendToNumber(n) else jumpWorkspace(n) end
    else
      deliverApp(function(app)
        if shift then return app.sendNumber and app.sendNumber(n) end
        return app.jump and app.jump(n)
      end, name, shift)
    end
    onBinding()
    return
  end

  if name == ";" or name == "'" then
    local dir = name == ";" and "prev" or "next"
    if layer == "os" then
      if shift then sendToWorkspace(dir) else switchWorkspace(dir) end
    else
      deliverApp(function(app)
        if shift then
          return dir == "prev" and app.sendPrev or app.sendNext
        end
        return dir == "prev" and app.switchPrev or app.switchNext
      end, name, shift)
    end
    onBinding()
    return
  end

  if name == "tab" and layer == "os" then
    if shift then
      aero({ "move-workspace-to-monitor", "--wrap-around", "next" })
    else
      aero({ "focus-monitor", "--wrap-around", "next" })
    end
    onBinding()
    return
  end

  if shift then return end

  if name == "return" then
    if layer == "os" then
      aero({ "fullscreen" })
    else
      deliverApp(function(app) return app.zoom end, name, false)
    end
    onBinding()
    return
  end

  if name == "x" then
    if layer == "os" then
      aero({ "close" })
    else
      deliverApp(function(app) return app.close end, name, false)
    end
    onBinding()
    return
  end

  if name == "p" then
    if layer == "os" then
      runAction({ launch = "com.raycast.macos" })
    else
      deliverApp(function(app) return app.command end, name, false)
    end
    onBinding()
    return
  end

  if name == "o" then
    if layer == "os" then
      runAction({ launch = "com.contextsformac.Contexts" })
    else
      deliverApp(function(app) return app.open end, name, false)
    end
    onBinding()
    return
  end

  if name == "[" or name == "]" then
    if layer == "os" then
      walkHistory(name == "[" and -1 or 1)
    else
      deliverApp(function(app)
        return name == "[" and app.back or app.forward
      end, name, false)
    end
    onBinding()
    return
  end
end

local function handle(event)
  if isMarked(event) then return false end
  local code = event:getKeyCode()
  local isDown = event:getType() == hs.eventtap.event.types.keyDown
  local isRepeat = event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 0

  if code == F18 or code == F19 then
    if isRepeat then return true end
    local which = code == F18 and "os" or "app"
    if isDown then arm(which) else release(which) end
    swallowed[code] = nil
    return true
  end

  if not isDown then
    if swallowed[code] then
      swallowed[code] = nil
      return true
    end
    return false
  end

  local armed = activeLayer() ~= nil or chord ~= nil
  if not armed then return false end

  if isRepeat then
    local name = keyName(code)
    local resizing = chord and chord.kind == "resize" and ARROW[name]
    local frow = not chord and activeLayer() == "app" and FKEY[name]
    if not resizing and not frow then
      swallowed[code] = true
      return true
    end
  end

  swallowed[code] = true
  local name = keyName(code)
  if not name then return true end
  local flags = event:getFlags()
  local shift = flags.shift and true or false
  if chord then
    handleChord(name, shift, flags)
  else
    handleLayer(name, shift, flags)
  end
  return true
end

Keybindings = {
  onFocusChanged = onFocusChanged,
}

Keybindings.tap = hs.eventtap.new({
  hs.eventtap.event.types.keyDown,
  hs.eventtap.event.types.keyUp,
}, handle)
Keybindings.tap:start()
