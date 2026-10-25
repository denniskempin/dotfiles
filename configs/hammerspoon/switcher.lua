-- Window search for the operating-system layer and for Fn.
--
-- The list comes from AeroSpace. Matching is a prefix of the app name, a
-- prefix of the title, or a prefix of a word in either. Earlier rows win
-- ties, and the caller puts the most recently focused windows first.
--
-- `install` freezes the list. Tests use it so a key does not start a query.

local aerospace = require("aerospace")

local M = {}

local LIST_FORMAT = "%{window-id} ::: %{app-name} ::: %{workspace} ::: %{window-title}"
local LIST_ARGS = { "list-windows", "--all", "--format", LIST_FORMAT }
local WORKSPACE_ARGS = { "list-workspaces", "--focused", "--format", "%{workspace}" }

local VISIBLE = 8

local windows = {}
local frozen = false

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

function M.parse(text)
  local out = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local id, app, workspace, title = line:match("^(%d+) ::: (.-) ::: (.-) ::: (.*)$")
    if id then
      out[#out + 1] = { id = id, app = app, workspace = workspace, title = title }
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
    return a.id < b.id
  end)
  return list
end

function M.refresh()
  if frozen then return end
  aerospace.query(LIST_ARGS, function(code, out)
    if code ~= 0 then return end
    windows = orderByMru(M.parse(out))
    if M.updated then M.updated() end
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

function M.focus(window)
  aerospace.command({ "focus", "--window-id", tostring(window.id) })
end

-- Moves the window onto the focused workspace. A window already there is focused.
function M.bring(window)
  aerospace.query(WORKSPACE_ARGS, function(code, out)
    if code ~= 0 then return end
    local workspace = out:match("%S+")
    if not workspace then return end
    local id = tostring(window.id)
    if window.workspace == workspace then
      aerospace.command({ "focus", "--window-id", id })
    else
      aerospace.command({
        "move-node-to-workspace", "--focus-follows-window", "--window-id", id, workspace,
      })
    end
  end)
end

return M
