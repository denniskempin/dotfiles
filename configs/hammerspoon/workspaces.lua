-- Workspace map for the operating-system layer.
--
-- A visible workspace is measured from window frames, so a split, a nest,
-- and unequal sizes match the screen. An accordion's real padding is only
-- a few pixels once the workspace is scaled into a thumbnail, so an
-- accordion is redrawn as strips: the focused window open, neighbors on
-- the sides their frames actually occupy.
--
-- A hidden workspace's windows are parked off-screen, and AeroSpace lists
-- windows alphabetically rather than in tree order. Those thumbnails use
-- the layout and share the space evenly.

local aerospace = require("aerospace")

local M = {}

local ACCENT = { hex = "#8EBEFF" }
local FONT = ".AppleSystemUIFont"
local PAD, TITLE_H, GAP = 14, 22, 8
local CARD_PAD, NAME_H, CAPTION_H = 8, 16, 14
local STRIP = 0.18
local MIN_COVER = 0.5

local PALETTE = {
  "4C6A8A",
  "6A5A3C",
  "3E6B52",
  "6A4560",
  "4E5A78",
  "5C5346",
  "3E5E6A",
  "5A6840",
}

local TAB = "%{tab}"
local WORKSPACE_ARGS = {
  "list-workspaces", "--all", "--format",
  "%{workspace}" .. TAB .. "%{monitor-id}" .. TAB .. "%{monitor-name}" .. TAB
    .. "%{workspace-is-focused}" .. TAB .. "%{workspace-is-visible}" .. TAB
    .. "%{workspace-root-container-layout}",
}
local WINDOW_ARGS = {
  "list-windows", "--all", "--format",
  "%{window-id}" .. TAB .. "%{app-name}" .. TAB .. "%{workspace}" .. TAB
    .. "%{monitor-id}" .. TAB .. "%{window-layout}" .. TAB
    .. "%{window-is-fullscreen}" .. TAB .. "%{window-title}",
}

local canvas
local showing = false
local token = 0
local model

local function fields(line)
  local out = {}
  for field in (line .. "\t"):gmatch("(.-)\t") do out[#out + 1] = field end
  return out
end

local function lines(text)
  local out = {}
  for line in ((text or "") .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then out[#out + 1] = line end
  end
  return out
end

function M.parseWorkspaces(text)
  local out = {}
  for _, line in ipairs(lines(text)) do
    local f = fields(line)
    if f[1] and f[1] ~= "" then
      out[#out + 1] = {
        name = f[1],
        monitor = f[2] or "",
        monitorName = f[3] or "",
        focused = f[4] == "true",
        visible = f[5] == "true",
        layout = f[6] or "",
      }
    end
  end
  return out
end

function M.parseWindows(text)
  local out = {}
  for _, line in ipairs(lines(text)) do
    local f = fields(line)
    if f[1] and f[1]:match("^%d+$") then
      out[#out + 1] = {
        id = f[1],
        app = f[2] or "",
        workspace = f[3] or "",
        monitor = f[4] or "",
        layout = f[5] or "",
        fullscreen = f[6] == "true",
        title = table.concat(f, "\t", 7),
      }
    end
  end
  return out
end

local function coverage(frame, screen)
  if not frame or not screen or frame.w <= 0 or frame.h <= 0 or screen.w <= 0 or screen.h <= 0 then
    return 0
  end
  local x1 = math.max(frame.x, screen.x)
  local y1 = math.max(frame.y, screen.y)
  local x2 = math.min(frame.x + frame.w, screen.x + screen.w)
  local y2 = math.min(frame.y + frame.h, screen.y + screen.h)
  if x2 <= x1 or y2 <= y1 then return 0 end
  return ((x2 - x1) * (y2 - y1)) / (frame.w * frame.h)
end

local function framesFit(windows, frames, screen)
  if not frames or not screen then return false end
  for _, window in ipairs(windows) do
    if coverage(frames[window.id], screen) < MIN_COVER then return false end
  end
  return true
end

local function equalUnits(count, horizontal)
  local rects = {}
  for i = 1, count do
    local pos, size = (i - 1) / count, 1 / count
    if horizontal then
      rects[i] = { x = pos, y = 0, w = size, h = 1 }
    else
      rects[i] = { x = 0, y = pos, w = 1, h = size }
    end
  end
  return rects
end

local function accordionUnits(count, focus, horizontal)
  local strips = math.max(count - 1, 0)
  local strip = strips == 0 and 0 or math.min(STRIP, 0.5 / strips)
  local main = 1 - strip * strips
  local rects, cursor = {}, 0
  for i = 1, count do
    local size = i == focus and main or strip
    if horizontal then
      rects[i] = { x = cursor, y = 0, w = size, h = 1 }
    else
      rects[i] = { x = 0, y = cursor, w = 1, h = size }
    end
    cursor = cursor + size
  end
  return rects
end

local function gridUnits(count)
  local cols = math.max(1, math.ceil(math.sqrt(count)))
  local rows = math.ceil(count / cols)
  local rects = {}
  for i = 1, count do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    rects[i] = { x = col / cols, y = row / rows, w = 1 / cols, h = 1 / rows }
  end
  return rects
end

local function chooseLayout(workspace)
  local layout = nil
  for _, window in ipairs(workspace.windows) do
    if window.layout and window.layout ~= "" then
      if not layout then
        layout = window.layout
      elseif layout ~= window.layout then
        layout = nil
        break
      end
    end
  end
  return layout or workspace.layout or "h_tiles"
end

local function schematic(windows, layout)
  local focus = 1
  for i, window in ipairs(windows) do
    if window.focused then focus = i break end
  end
  if layout == "v_tiles" then return equalUnits(#windows, false) end
  if layout == "v_accordion" then return accordionUnits(#windows, focus, false) end
  if layout == "h_accordion" then return accordionUnits(#windows, focus, true) end
  if layout == "floating" then return gridUnits(#windows) end
  return equalUnits(#windows, true)
end

local function clampUnit(frame, screen)
  local x = (frame.x - screen.x) / screen.w
  local y = (frame.y - screen.y) / screen.h
  local x2 = math.min(1, math.max(0, x + frame.w / screen.w))
  local y2 = math.min(1, math.max(0, y + frame.h / screen.h))
  x, y = math.max(0, x), math.max(0, y)
  return { x = x, y = y, w = math.max(0, x2 - x), h = math.max(0, y2 - y) }
end

-- Which side of the open window this frame peeks out of. Overlapping
-- accordion windows share almost the same origin, so the side is the
-- overhang, not the center.
local function side(frame, open, horizontal)
  local start, finish, openStart, openFinish
  if horizontal then
    start, finish = frame.x, frame.x + frame.w
    openStart, openFinish = open.x, open.x + open.w
  else
    start, finish = frame.y, frame.y + frame.h
    openStart, openFinish = open.y, open.y + open.h
  end
  local before = start < openStart - 1
  local after = finish > openFinish + 1
  if before and not after then return "before" end
  if after and not before then return "after" end
  if before and after then
    return (openStart - start) >= (finish - openFinish) and "before" or "after"
  end
  local mid = (start + finish) / 2
  local openMid = (openStart + openFinish) / 2
  return mid <= openMid and "before" or "after"
end

local function accordionFrames(windows, frames, horizontal)
  local openAt = nil
  for i, window in ipairs(windows) do
    if window.focused then openAt = i break end
  end
  if not openAt then
    local best = math.huge
    for i, window in ipairs(windows) do
      local z = frames[window.id].z or i
      if z < best then best, openAt = z, i end
    end
  end
  local open = frames[windows[openAt].id]
  local before, after = {}, {}
  for i, window in ipairs(windows) do
    if i ~= openAt then
      local bucket = side(frames[window.id], open, horizontal) == "before" and before or after
      bucket[#bucket + 1] = i
    end
  end
  local function coord(i)
    local frame = frames[windows[i].id]
    return horizontal and frame.x or frame.y
  end
  table.sort(before, function(a, b) return coord(a) < coord(b) end)
  table.sort(after, function(a, b) return coord(a) < coord(b) end)
  local order = {}
  for _, i in ipairs(before) do order[#order + 1] = i end
  local focusPos = #order + 1
  order[#order + 1] = openAt
  for _, i in ipairs(after) do order[#order + 1] = i end
  local units = accordionUnits(#order, focusPos, horizontal)
  local rects = {}
  for pos, index in ipairs(order) do rects[index] = units[pos] end
  return rects
end

local function sharedAccordion(windows)
  local layout = nil
  for _, window in ipairs(windows) do
    if window.layout ~= "h_accordion" and window.layout ~= "v_accordion" then return nil end
    if layout and layout ~= window.layout then return nil end
    layout = window.layout
  end
  return layout
end

function M.arrange(workspace, frames, screen)
  local windows = workspace.windows or {}
  local rects = {}
  if #windows == 0 then return rects end
  local fullscreen = false
  for _, window in ipairs(windows) do
    if window.fullscreen then fullscreen = true break end
  end
  if fullscreen then
    for i, window in ipairs(windows) do
      rects[i] = window.fullscreen and { x = 0, y = 0, w = 1, h = 1 } or nil
    end
    return rects
  end
  if workspace.visible and framesFit(windows, frames, screen) then
    local accordion = sharedAccordion(windows)
    if accordion then return accordionFrames(windows, frames, accordion == "h_accordion") end
    for i, window in ipairs(windows) do rects[i] = clampUnit(frames[window.id], screen) end
    return rects
  end
  return schematic(windows, chooseLayout(workspace))
end

local function byName(a, b)
  local na, nb = tonumber(a.name), tonumber(b.name)
  if na and nb then return na < nb end
  if na then return true end
  if nb then return false end
  return a.name < b.name
end

function M.build(workspaceRows, windowRows, opts)
  opts = opts or {}
  local focused = opts.focused and tostring(opts.focused) or nil
  local frames = opts.frames or {}
  local screens = opts.screens or {}
  local grouped = {}
  for _, window in ipairs(windowRows) do
    local copy = {
      id = window.id,
      app = window.app or "",
      title = window.title or "",
      layout = window.layout or "",
      fullscreen = window.fullscreen == true,
      focused = focused ~= nil and window.id == focused,
      monitor = window.monitor or "",
    }
    local name = window.workspace or ""
    grouped[name] = grouped[name] or {}
    grouped[name][#grouped[name] + 1] = copy
  end

  local monitors, index, seen = {}, {}, {}
  local function monitor(id, name)
    local found = index[id]
    if found then return found end
    found = { id = id, name = name or "", workspaces = {} }
    local screen = screens[id]
    if screen and screen.w and screen.h and screen.h > 0 then found.aspect = screen.w / screen.h end
    index[id] = found
    monitors[#monitors + 1] = found
    return found
  end
  local function place(mon, row, windows)
    local ws = {
      name = row.name,
      focused = row.focused == true,
      visible = row.visible == true,
      layout = row.layout or "",
      windows = windows,
    }
    local rects = M.arrange(ws, frames, screens[mon.id])
    for i, window in ipairs(windows) do
      window.rect = rects[i]
      local frame = frames[window.id]
      window.z = window.focused and 0 or (frame and frame.z) or i
    end
    mon.workspaces[#mon.workspaces + 1] = ws
    seen[row.name] = true
  end

  for _, row in ipairs(workspaceRows) do
    place(monitor(row.monitor, row.monitorName), row, grouped[row.name] or {})
  end
  for name, windows in pairs(grouped) do
    if not seen[name] then
      local id = windows[1].monitor ~= "" and windows[1].monitor or "1"
      place(monitor(id, ""), {
        name = name,
        focused = false,
        visible = false,
        layout = windows[1].layout,
      }, windows)
    end
  end
  table.sort(monitors, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
  for _, mon in ipairs(monitors) do table.sort(mon.workspaces, byName) end
  return { monitors = monitors }
end

local function displayName(window)
  if window.app and window.app ~= "" then return window.app end
  if window.title and window.title ~= "" then return window.title end
  return "Window"
end

local function shorten(text, pixels, size)
  local maxChars = math.floor(pixels / (size * 0.56))
  if maxChars < 2 then return nil end
  local ok, n = pcall(utf8.len, text)
  if not ok or not n then
    if #text <= maxChars then return text end
    return text:sub(1, maxChars - 1) .. "…"
  end
  if n <= maxChars then return text end
  local cutOk, cut = pcall(utf8.offset, text, maxChars)
  if not cutOk or not cut then return text:sub(1, maxChars - 1) .. "…" end
  return text:sub(1, cut - 1) .. "…"
end

local function fillFor(name)
  local hash = 0
  for i = 1, #name do hash = (hash + name:byte(i) * i) % #PALETTE end
  return { hex = "#" .. PALETTE[hash + 1] }
end

local function grid(count, innerMax)
  if count <= 0 then return 0, 0, 0 end
  local minCard = 124
  local maxCols = math.max(1, math.floor((innerMax + GAP) / (minCard + GAP)))
  local cols = math.min(count, maxCols)
  local rows = math.ceil(count / cols)
  cols = math.ceil(count / rows)
  local cardW = math.min(240, (innerMax - GAP * (cols - 1)) / cols)
  return cols, rows, cardW
end

-- Empty workspaces stay narrow so a workspace that has windows can show its
-- layout. When every workspace has windows, or the wide cards would not fit,
-- they share the row evenly and wrap.
local function rowPlan(workspaces, innerMax)
  local count = #workspaces
  if count == 0 then return {}, 0, 0, 0, 0, 0 end
  local occupied = 0
  for _, ws in ipairs(workspaces) do
    if #ws.windows > 0 then occupied = occupied + 1 end
  end
  local empty = count - occupied
  local gaps = GAP * math.max(count - 1, 0)
  if occupied == 0 then
    local w = math.min(64, (innerMax - gaps) / count)
    local widths = {}
    for i = 1, count do widths[i] = w end
    return widths, count, 1, w, count * w + gaps, 0
  end
  local emptyW = 56
  local room = innerMax - gaps - empty * emptyW
  local occupiedW = room / occupied
  if occupiedW >= 160 then
    occupiedW = math.min(280, occupiedW)
    local widths, gridW, maxW = {}, 0, 0
    for i, ws in ipairs(workspaces) do
      local w = #ws.windows > 0 and occupiedW or emptyW
      widths[i] = w
      gridW = gridW + w
      if w > maxW then maxW = w end
    end
    return widths, count, 1, maxW, gridW + gaps, occupied
  end
  local cols, rows, cardW = grid(count, innerMax)
  local widths = {}
  for i = 1, count do widths[i] = cardW end
  return widths, cols, rows, cardW, cols * cardW + GAP * (cols - 1), occupied
end

local function placeRect(unit, area)
  local rect = {
    x = area.x + unit.x * area.w,
    y = area.y + unit.y * area.h,
    w = unit.w * area.w,
    h = unit.h * area.h,
  }
  if rect.w > 8 and rect.h > 8 then
    rect.x, rect.y = rect.x + 1, rect.y + 1
    rect.w, rect.h = rect.w - 2, rect.h - 2
  end
  return rect
end

local function readingOrder(windows)
  local idx = {}
  for i = 1, #windows do idx[i] = i end
  table.sort(idx, function(a, b)
    local left, right = windows[a].rect, windows[b].rect
    if not left then return false end
    if not right then return true end
    if math.abs(left.x - right.x) > 0.02 then return left.x < right.x end
    return left.y < right.y
  end)
  local names = {}
  for _, i in ipairs(idx) do names[#names + 1] = displayName(windows[i]) end
  return table.concat(names, " · ")
end

function M.draw(model, screen)
  screen = screen or { x = 0, y = 0, w = 1440, h = 900 }
  local innerMax = math.max(280, screen.w - 32 - PAD * 2)
  local sections = {}
  local width = 280
  for _, mon in ipairs(model.monitors or {}) do
    local widths, cols, rows, cardW, gridW, occupied = rowPlan(mon.workspaces, innerMax)
    local aspect = mon.aspect or (screen.h > 0 and screen.w / screen.h or 1.6)
    local layoutH, cardH = 0, 0
    if #mon.workspaces > 0 then
      if occupied == 0 then
        layoutH = 22
        cardH = CARD_PAD + NAME_H + layoutH + CARD_PAD
      else
        layoutH = math.max(72, math.min(120, (cardW - CARD_PAD * 2) / aspect))
        cardH = CARD_PAD + NAME_H + layoutH + 4 + CAPTION_H + CARD_PAD
      end
    end
    local label = #(model.monitors or {}) > 1 and mon.name ~= "" and mon.name or nil
    width = math.max(width, gridW + PAD * 2)
    sections[#sections + 1] = {
      mon = mon,
      cols = cols,
      rows = rows,
      widths = widths,
      cardH = cardH,
      layoutH = layoutH,
      label = label,
      gridW = gridW,
    }
  end

  local height = PAD + TITLE_H + PAD
  for _, section in ipairs(sections) do
    if section.label then height = height + 18 end
    if section.rows > 0 then
      height = height + section.rows * section.cardH + (section.rows - 1) * GAP
    end
    height = height + 8
  end
  if #sections == 0 then height = PAD + TITLE_H + PAD end

  local rect = {
    x = screen.x + (screen.w - width) / 2,
    y = screen.y + 16,
    w = width,
    h = height,
  }
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
      text = "Workspaces",
      textColor = ACCENT,
      textSize = 15,
      textFont = FONT,
      frame = { x = PAD, y = PAD, w = width - PAD * 2, h = TITLE_H },
    },
  }

  local y = PAD + TITLE_H + 6
  for _, section in ipairs(sections) do
    if section.label then
      elements[#elements + 1] = {
        type = "text",
        text = section.label,
        textColor = { white = 0.45 },
        textSize = 12,
        textFont = FONT,
        frame = { x = PAD, y = y, w = width - PAD * 2, h = 16 },
      }
      y = y + 18
    end
    local originX = (width - section.gridW) / 2
    for i, ws in ipairs(section.mon.workspaces) do
      local col = (i - 1) % section.cols
      local row = math.floor((i - 1) / section.cols)
      local cardX = originX
      if section.rows == 1 then
        for n = 1, i - 1 do cardX = cardX + section.widths[n] + GAP end
      else
        cardX = originX + col * (section.widths[i] + GAP)
      end
      local card = {
        x = cardX,
        y = y + row * (section.cardH + GAP),
        w = section.widths[i],
        h = section.cardH,
      }
      elements[#elements + 1] = {
        type = "rectangle",
        action = "fill",
        fillColor = { white = 1, alpha = ws.focused and 0.07 or 0.035 },
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
        frame = card,
      }
      elements[#elements + 1] = {
        type = "rectangle",
        action = "stroke",
        strokeColor = ws.focused and ACCENT or { white = 1, alpha = 0.1 },
        strokeWidth = ws.focused and 2 or 1,
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
        frame = card,
      }
      elements[#elements + 1] = {
        type = "text",
        text = ws.name,
        textColor = ws.focused and ACCENT or { white = 0.8 },
        textSize = 12,
        textFont = FONT,
        textAlignment = "center",
        frame = { x = card.x, y = card.y + 4, w = card.w, h = NAME_H },
      }
      local area = {
        x = card.x + CARD_PAD,
        y = card.y + CARD_PAD + NAME_H,
        w = card.w - CARD_PAD * 2,
        h = section.layoutH,
      }
      elements[#elements + 1] = {
        type = "rectangle",
        action = "fill",
        fillColor = { white = 1, alpha = 0.04 },
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
        frame = area,
      }
      local panes = {}
      for _, window in ipairs(ws.windows) do
        if window.rect then panes[#panes + 1] = window end
      end
      table.sort(panes, function(a, b) return (a.z or 0) > (b.z or 0) end)
      local labeled = 0
      for _, window in ipairs(panes) do
        local pane = placeRect(window.rect, area)
        local name = displayName(window)
        elements[#elements + 1] = {
          type = "rectangle",
          action = "fill",
          fillColor = fillFor(name),
          roundedRectRadii = { xRadius = 4, yRadius = 4 },
          frame = pane,
        }
        elements[#elements + 1] = {
          type = "rectangle",
          action = "stroke",
          strokeColor = window.focused and ACCENT or { white = 1, alpha = 0.18 },
          strokeWidth = window.focused and 2 or 1,
          roundedRectRadii = { xRadius = 4, yRadius = 4 },
          frame = pane,
        }
        local shown = shorten(name, pane.w - 8, 11)
        if shown and pane.h >= 16 then
          local title = nil
          if pane.h >= 40 and window.title and window.title ~= "" and window.title ~= window.app then
            title = shorten(window.title, pane.w - 8, 10)
          end
          local linesN = title and 2 or 1
          local textY = pane.y + math.max(0, (pane.h - linesN * 13) / 2)
          elements[#elements + 1] = {
            type = "text",
            text = shown,
            textColor = { white = 0.96 },
            textSize = 11,
            textFont = FONT,
            textAlignment = "center",
            frame = { x = pane.x, y = textY, w = pane.w, h = 13 },
          }
          if title then
            elements[#elements + 1] = {
              type = "text",
              text = title,
              textColor = { white = 0.72 },
              textSize = 10,
              textFont = FONT,
              textAlignment = "center",
              frame = { x = pane.x, y = textY + 13, w = pane.w, h = 12 },
            }
          end
          labeled = labeled + 1
        end
      end
      if #ws.windows > 0 and labeled < #ws.windows then
        local text = shorten(readingOrder(ws.windows), card.w - 12, 11)
        if text then
          elements[#elements + 1] = {
            type = "text",
            text = text,
            textColor = { white = 0.62 },
            textSize = 11,
            textFont = FONT,
            textAlignment = "center",
            frame = {
              x = card.x + 4,
              y = area.y + area.h + 3,
              w = card.w - 8,
              h = CAPTION_H,
            },
          }
        end
      end
    end
    if section.rows > 0 then y = y + section.rows * section.cardH + (section.rows - 1) * GAP end
    y = y + 8
  end
  return rect, elements
end

local function focusedWindowId()
  local ok, win = pcall(function() return hs.window.focusedWindow() end)
  if not ok or not win then return nil end
  local idOk, id = pcall(function() return win:id() end)
  if idOk and id then return tostring(id) end
  return nil
end

local function windowFrames()
  local frames = {}
  local ok, wins = pcall(function() return hs.window.orderedWindows() end)
  if not ok or type(wins) ~= "table" then return frames end
  for i, win in ipairs(wins) do
    local idOk, id = pcall(function() return win:id() end)
    local frameOk, frame = pcall(function() return win:frame() end)
    if idOk and frameOk and id and frame then
      frames[tostring(id)] = { x = frame.x, y = frame.y, w = frame.w, h = frame.h, z = i }
    end
  end
  return frames
end

local function monitorScreens()
  local screens = {}
  local ok, list = pcall(function() return hs.screen.allScreens() end)
  if not ok or type(list) ~= "table" then return screens end
  local frames = {}
  for _, screen in ipairs(list) do
    local frameOk, frame = pcall(function() return screen:frame() end)
    if frameOk and frame then frames[#frames + 1] = frame end
  end
  table.sort(frames, function(a, b) return a.x < b.x end)
  for i, frame in ipairs(frames) do screens[tostring(i)] = frame end
  return screens
end

local function render(nextModel)
  local screen = hs.screen.mainScreen()
  if not screen then return end
  local rect, elements = M.draw(nextModel, screen:frame())
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
  canvas:replaceElements(elements)
  canvas:show()
end

function M.refresh(callback)
  aerospace.query(WORKSPACE_ARGS, function(code, wsOut)
    if code ~= 0 then callback(nil) return end
    aerospace.query(WINDOW_ARGS, function(code2, winOut)
      if code2 ~= 0 then callback(nil) return end
      callback(M.build(M.parseWorkspaces(wsOut), M.parseWindows(winOut), {
        focused = focusedWindowId(),
        frames = windowFrames(),
        screens = monitorScreens(),
      }))
    end)
  end)
end

function M.show()
  showing = true
  token = token + 1
  local mine = token
  if model then render(model) end
  M.refresh(function(nextModel)
    if not showing or mine ~= token or not nextModel then return end
    model = nextModel
    render(model)
  end)
end

function M.hide()
  showing = false
  token = token + 1
  if canvas then canvas:hide() end
end

return M
