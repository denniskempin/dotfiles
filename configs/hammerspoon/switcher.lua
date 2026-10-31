-- Window search for Fn. Right Option+O opens OmniWM's own window list
-- instead, which has no Chrome tabs.
--
-- The list comes from OmniWM. Each tab of a Google Chrome window is its
-- own row, with that window's app name and the tab's title. Chrome's
-- scripting id is not the macOS window id, so a tab is matched to its
-- window by the window's bounds. Choosing the row focuses that window and
-- selects the tab.
--
-- Matching is a prefix of the app name, a prefix of the title, or a prefix
-- of a word in either. Earlier rows win ties, and the caller puts the most
-- recently focused windows first. Tabs of one window stay together, with
-- the active tab first.
--
-- `install` freezes the list. Tests use it so a key does not start a query.

local omniwm = require("omniwm")

local M = {}

local LIST_ARGS = { "windows", "--fields", "id,window-id,app,workspace,title" }

local VISIBLE = 8
local BOUNDS_SLOP = 4

-- `tab` inside a Chrome tell is Chrome's tab class, not the tab character.
local TAB_LIST = [[
set nl to ASCII character 10
set sep to ASCII character 9
on clean(value)
  set saved to AppleScript's text item delimiters
  set AppleScript's text item delimiters to {ASCII character 9, ASCII character 10, ASCII character 13}
  set pieces to text items of (value as text)
  set AppleScript's text item delimiters to " "
  set value to pieces as text
  set AppleScript's text item delimiters to saved
  return value
end clean
tell application "System Events" to set chromeOn to exists process "Google Chrome"
if chromeOn is false then return ""
tell application "Google Chrome"
  set out to ""
  repeat with w in windows
    try
      set b to bounds of w
      set wid to id of w as text
      set activeIndex to active tab index of w
      set n to 0
      repeat with t in tabs of w
        set n to n + 1
        set flag to "0"
        if n is activeIndex then set flag to "1"
        set out to out & wid & sep & (n as text) & sep & flag & sep & ((item 1 of b) as integer as text) & sep & ((item 2 of b) as integer as text) & sep & ((item 3 of b) as integer as text) & sep & ((item 4 of b) as integer as text) & sep & my clean(title of t) & nl
      end repeat
    end try
  end repeat
  return out
end tell
]]

local windows = {}
local frozen = false
local token = 0

local function starts(text, query)
  return text:sub(1, #query) == query
end

local function wordStarts(text, query)
  for word in text:gmatch("[%w]+") do
    if starts(word, query) then return true end
  end
  return false
end

local function score(window, query)
  local app = (window.app or ""):lower()
  local title = (window.title or ""):lower()
  if starts(app, query) then return 1 end
  if starts(title, query) then return 2 end
  if wordStarts(app, query) or wordStarts(title, query) then return 3 end
  return nil
end

function M.parseTabs(text)
  local out = {}
  for line in ((text or "") .. "\n"):gmatch("(.-)\n") do
    local id, index, active, left, top, right, bottom, title =
      line:match("^(%d+)\t(%d+)\t([01])\t(-?%d+)\t(-?%d+)\t(-?%d+)\t(-?%d+)\t(.*)$")
    if id then
      out[#out + 1] = {
        chrome = id,
        index = tonumber(index),
        active = active == "1",
        bounds = {
          left = tonumber(left),
          top = tonumber(top),
          right = tonumber(right),
          bottom = tonumber(bottom),
        },
        title = title,
      }
    end
  end
  return out
end

local function nearBounds(frame, bounds)
  return math.abs(frame.x - bounds.left) <= BOUNDS_SLOP
    and math.abs(frame.y - bounds.top) <= BOUNDS_SLOP
    and math.abs((frame.x + frame.w) - bounds.right) <= BOUNDS_SLOP
    and math.abs((frame.y + frame.h) - bounds.bottom) <= BOUNDS_SLOP
end

-- Tabs grouped by macOS window id. A bounds that matches two windows, or
-- none, is left unmatched so the window row stays as OmniWM reported it.
function M.groupTabs(list, tabs, frames)
  local byChrome = {}
  for _, tab in ipairs(tabs or {}) do
    local group = byChrome[tab.chrome]
    if not group then
      group = { bounds = tab.bounds, tabs = {} }
      byChrome[tab.chrome] = group
    end
    group.tabs[#group.tabs + 1] = tab
  end
  local grouped, used = {}, {}
  for _, group in pairs(byChrome) do
    local hits = {}
    for _, window in ipairs(list) do
      local id = tostring(window.id)
      local frame = frames and frames[id]
      if frame and not used[id] and nearBounds(frame, group.bounds) then
        hits[#hits + 1] = id
      end
    end
    if #hits == 1 then
      used[hits[1]] = true
      grouped[hits[1]] = group.tabs
    end
  end
  return grouped
end

-- Replaces each window that has tabs with one row per tab. The active tab
-- comes first. Other windows are unchanged.
function M.expand(list, grouped)
  local out = {}
  for _, window in ipairs(list) do
    local tabs = grouped[tostring(window.id)]
    if not tabs or #tabs == 0 then
      out[#out + 1] = window
    else
      table.sort(tabs, function(a, b)
        if a.active ~= b.active then return a.active end
        return a.index < b.index
      end)
      for i, tab in ipairs(tabs) do
        out[#out + 1] = {
          id = window.id,
          handle = window.handle,
          app = window.app,
          workspace = window.workspace,
          title = tab.title ~= "" and tab.title or window.title,
          tab = tab.index,
          chrome = tab.chrome,
          order = i,
        }
      end
    end
  end
  return out
end

-- `id` is the macOS window id, which hs.window and the Chrome bounds match
-- on. `handle` is OmniWM's id for `window` commands, valid until OmniWM
-- restarts.
function M.parse(payload)
  local out = {}
  local list = type(payload) == "table" and payload.windows or {}
  for _, window in ipairs(list) do
    if type(window) == "table" and window.id and window.windowId then
      local app = type(window.app) == "table" and window.app or {}
      local workspace = type(window.workspace) == "table" and window.workspace or {}
      out[#out + 1] = {
        id = tostring(math.tointeger(window.windowId) or window.windowId),
        handle = window.id,
        app = app.name or "",
        workspace = workspace.rawName,
        title = window.title or "",
      }
    end
  end
  return out
end

function M.rank(list, query)
  local copy = {}
  query = (query or ""):lower()
  if query == "" then
    for i, window in ipairs(list) do copy[i] = window end
    return copy
  end
  local hits = {}
  for index, window in ipairs(list) do
    local value = score(window, query)
    if value then hits[#hits + 1] = { score = value, index = index, window = window } end
  end
  table.sort(hits, function(a, b)
    if a.score ~= b.score then return a.score < b.score end
    return a.index < b.index
  end)
  for i, hit in ipairs(hits) do copy[i] = hit.window end
  return copy
end

function M.matches(query)
  return M.rank(windows, query)
end

local function orderByMru(list)
  local ok, ordered = pcall(function()
    return hs.window.orderedWindows()
  end)
  if not ok or type(ordered) ~= "table" then return list end
  local rank = {}
  for i, window in ipairs(ordered) do
    local idOk, id = pcall(function() return window:id() end)
    if idOk and id then rank[tostring(id)] = i end
  end
  table.sort(list, function(a, b)
    local left, right = rank[a.id] or 100000, rank[b.id] or 100000
    if left ~= right then return left < right end
    if a.id ~= b.id then return a.id < b.id end
    return (a.order or 0) < (b.order or 0)
  end)
  return list
end

local function chromeRunning()
  local ok, app = pcall(function()
    return hs.application.get("com.google.Chrome")
  end)
  return ok and app ~= nil
end

local function windowFrames()
  local frames = {}
  local ok, wins = pcall(function() return hs.window.allWindows() end)
  if not ok or type(wins) ~= "table" then return frames end
  for _, win in ipairs(wins) do
    local idOk, id = pcall(function() return win:id() end)
    local frameOk, frame = pcall(function() return win:frame() end)
    if idOk and frameOk and id and frame then
      frames[tostring(id)] = { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
    end
  end
  return frames
end

local function queryTabs(done)
  local task = hs.task.new("/usr/bin/osascript", function(code, out)
    if code ~= 0 then done(nil) return end
    done(M.parseTabs(out or ""))
  end, { "-e", TAB_LIST })
  if not task or not task:start() then done(nil) end
end

function M.refresh()
  if frozen then return end
  token = token + 1
  local mine = token
  local parsed, tabs, frames
  local function publish()
    if mine ~= token or not parsed then return end
    local list = parsed
    if tabs then list = M.expand(parsed, M.groupTabs(parsed, tabs, frames or {})) end
    windows = orderByMru(list)
    if M.updated then M.updated() end
  end
  omniwm.query(LIST_ARGS, function(payload)
    if mine ~= token or not payload then return end
    parsed = M.parse(payload)
    publish()
  end)
  -- A tell to Chrome launches it when it is not running. Skip the query then.
  if not chromeRunning() then return end
  queryTabs(function(list)
    if mine ~= token then return end
    tabs = list or {}
    frames = windowFrames()
    publish()
  end)
end

function M.install(list)
  windows = list or {}
  frozen = true
end

local function shorten(text)
  text = text or ""
  if #text > 64 then return text:sub(1, 63) .. "..." end
  return text
end

-- Rows for the overlay. `selected` is clamped to the match list.
function M.rows(query, selected)
  local matches = M.matches(query)
  if selected > #matches then selected = #matches end
  if #matches > 0 and selected < 1 then selected = 1 end
  if #matches == 0 then
    return { { label = "No match", hint = "" } }, 0
  end
  local start = 1
  if selected > VISIBLE then start = selected - VISIBLE + 1 end
  local last = math.min(#matches, start + VISIBLE - 1)
  local rows = {}
  for i = start, last do
    local window = matches[i]
    rows[#rows + 1] = {
      label = window.app,
      hint = shorten(window.title),
      selected = i == selected,
    }
  end
  return rows, selected
end

function M.pick(query, selected)
  local matches = M.matches(query)
  if selected < 1 or selected > #matches then return nil end
  return matches[selected]
end

local function afterTab(window, done)
  local chromeId = window.chrome and tostring(window.chrome) or ""
  if not (window.tab and chromeId:match("^%d+$") and type(window.tab) == "number") then
    done()
    return
  end
  local script = ('tell application "Google Chrome" to set active tab index of window id %s to %d'):format(
    chromeId, window.tab
  )
  local task = hs.task.new("/usr/bin/osascript", function()
    done()
  end, { "-e", script })
  if not task or not task:start() then done() end
end

-- Focuses the window where it is, switching to its workspace.
function M.focus(window)
  afterTab(window, function()
    omniwm.command({ "window", "navigate", window.handle })
  end)
end

return M
