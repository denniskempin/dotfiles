-- The bindings overlay: a non-activating hs.canvas at the bottom of the
-- main screen. A spec has `layer`, `title`, `footer`, and either `columns`
-- (a list of row lists) or `rows`. A row is a bindings.lua row.

local M = {}

local DELAY = 0.25

local ACCENT = {
  os = { hex = "#8EBEFF" },
  app = { hex = "#E7C27A" },
}

local canvas
local pending

local function cancel()
  if pending then
    pending:stop()
    pending = nil
  end
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

  local accent = ACCENT[spec.layer]
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
  local function addRow(row, x, y)
    local verbW = math.floor(colW * 0.56)
    elements[#elements + 1] = {
      type = "text",
      text = row.label,
      textColor = { white = 0.92 },
      textSize = 13,
      textFont = ".AppleSystemUIFont",
      frame = { x = x, y = y, w = verbW, h = rowH },
    }
    elements[#elements + 1] = {
      type = "text",
      text = row.hint,
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
        addRow(row, x, top + (r - 1) * rowH)
      end
    end
  else
    for r, row in ipairs(spec.rows) do
      addRow(row, pad, top + (r - 1) * rowH)
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

function M.show(spec)
  cancel()
  render(spec)
end

function M.hide()
  cancel()
  if canvas then canvas:hide() end
end

-- Runs `fn` after the overlay delay, unless show, hide, or later comes first.
function M.later(fn)
  cancel()
  pending = hs.timer.doAfter(DELAY, function()
    pending = nil
    fn()
  end)
end

return M
