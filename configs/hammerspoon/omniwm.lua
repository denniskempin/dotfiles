-- Runs omniwmctl commands without blocking.
--
-- A blocking call inside the event tap holds every key on the system until
-- it returns, and OmniWM can take a while when an app is slow to answer it.
-- Commands run through hs.task, one at a time in the order they were
-- queued.
--
-- omniwmctl needs OmniWM running with IPC on. configs/omniwm/settings.toml
-- sets ipcEnabled. Without it every command exits 2.

local log = hs.logger.new("keybindings", "warning")

local M = {}

local TIMEOUT = 5

local function binaryPath()
  for _, path in ipairs({ "/opt/homebrew/bin/omniwmctl", "/Applications/OmniWM.app/Contents/MacOS/omniwmctl" }) do
    if hs.fs.attributes(path) then return path end
  end
  log.w("omniwmctl not found")
  return nil
end

local BINARY = binaryPath()

local queue = {}
local running

local pump

-- Exit 1 is OmniWM declining: no window to act on, or nothing to change.
-- Only a failure to reach OmniWM, or a bad argument, is worth a warning.
local function finish(job, code, stdout)
  if job.timer then
    job.timer:stop()
    job.timer = nil
  end
  if code ~= 0 and code ~= 1 then log.w("omniwmctl " .. job.id) end
  local callback = job.callback
  running = nil
  if callback then callback(code, stdout or "") end
  pump()
end

-- A command still running after TIMEOUT is terminated, so a hung OmniWM
-- cannot stall the queue.
pump = function()
  if running or #queue == 0 then return end
  local job = table.remove(queue, 1)
  running = job
  job.task = hs.task.new(BINARY, function(code, stdout) finish(job, code, stdout) end, job.args)
  if not job.task or not job.task:start() then
    finish(job, -1)
    return
  end
  job.timer = hs.timer.doAfter(TIMEOUT, function()
    job.timer = nil
    job.task:terminate()
  end)
end

local function enqueue(args, callback)
  local id = table.concat(args, " ")
  if not BINARY then
    log.w("omniwmctl " .. id)
    if callback then callback(-1, "") end
    return
  end
  queue[#queue + 1] = { id = id, args = args, callback = callback }
  pump()
end

function M.command(args)
  enqueue(args)
end

-- Like command, and the callback receives the exit code and stdout. It runs
-- before the next queued command, so the callback may enqueue a follow-up.
function M.run(args, callback)
  enqueue(args, callback)
end

-- `omniwmctl query <name> ...`. The callback receives the result payload, a
-- table such as { windows = {...} }, or nil when the query failed.
function M.query(args, callback)
  local full = { "query" }
  for _, arg in ipairs(args) do full[#full + 1] = arg end
  enqueue(full, function(code, stdout)
    if code ~= 0 then callback(nil) return end
    local ok, decoded = pcall(hs.json.decode, stdout)
    local result = ok and type(decoded) == "table" and decoded.result
    callback(type(result) == "table" and result.payload or nil)
  end)
end

local function center(frame)
  return frame.x + frame.width / 2, frame.y + frame.height / 2
end

-- OmniWM moves a workspace or window to a monitor by direction only. The
-- next monitor is the one after the current one in left-to-right order, as
-- `focus-monitor next` steps, and the direction is the way its center lies.
local function nextMonitorDirection(displays)
  local list = {}
  for _, display in ipairs(displays or {}) do
    if type(display.frame) == "table" then list[#list + 1] = display end
  end
  if #list < 2 then return nil end
  table.sort(list, function(a, b)
    if a.frame.x ~= b.frame.x then return a.frame.x < b.frame.x end
    return a.frame.y < b.frame.y
  end)
  local current
  for i, display in ipairs(list) do
    if display.isCurrent then current = i end
  end
  if not current then return nil end
  local here, there = list[current], list[current % #list + 1]
  local x1, y1 = center(here.frame)
  local x2, y2 = center(there.frame)
  local dx, dy = x2 - x1, y2 - y1
  if math.abs(dx) >= math.abs(dy) then return dx < 0 and "left" or "right" end
  -- Display frames use AppKit coordinates, where y grows upward.
  return dy > 0 and "up" or "down"
end

M.nextMonitorDirection = nextMonitorDirection

function M.sendWorkspaceToNextMonitor()
  M.query({ "displays", "--fields", "frame,is-current" }, function(payload)
    local dir = payload and nextMonitorDirection(payload.displays)
    if not dir then return end
    M.query({ "workspaces", "--current", "--fields", "raw-name" }, function(result)
      local workspace = result and result.workspaces and result.workspaces[1]
      if not workspace or not workspace.rawName then return end
      M.command({ "workspace", "move-to-monitor", workspace.rawName, dir, "--force" })
    end)
  end)
end

return M
