-- Runs AeroSpace commands without blocking.
--
-- A blocking call inside the event tap holds every key on the system until
-- it returns, and AeroSpace can take seconds when an app is slow to answer
-- it. Commands run through hs.task, one at a time in the order they were
-- queued.

local log = hs.logger.new("keybindings", "warning")

local M = {}

local TIMEOUT = 5

local function binaryPath()
  for _, path in ipairs({ "/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace" }) do
    if hs.fs.attributes(path) then return path end
  end
  log.w("aerospace not found")
  return nil
end

local BINARY = binaryPath()

local queue = {}
local running

local pump

local function finish(job, code, stdout)
  if job.timer then
    job.timer:stop()
    job.timer = nil
  end
  if code ~= 0 then log.w("aerospace " .. job.id) end
  local callback = job.callback
  running = nil
  if callback then callback(code, stdout or "") end
  pump()
end

-- A command still running after TIMEOUT is terminated, so a hung AeroSpace
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
    log.w("aerospace " .. id)
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
function M.query(args, callback)
  enqueue(args, callback)
end

return M
