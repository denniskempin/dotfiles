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

local function finish(job, code)
  if job.timer then
    job.timer:stop()
    job.timer = nil
  end
  if code ~= 0 then log.w("aerospace " .. job.id) end
  running = nil
  pump()
end

-- A command still running after TIMEOUT is terminated, so a hung AeroSpace
-- cannot stall the queue.
pump = function()
  if running or #queue == 0 then return end
  local job = table.remove(queue, 1)
  running = job
  job.task = hs.task.new(BINARY, function(code) finish(job, code) end, job.args)
  if not job.task or not job.task:start() then
    finish(job, -1)
    return
  end
  job.timer = hs.timer.doAfter(TIMEOUT, function()
    job.timer = nil
    job.task:terminate()
  end)
end

function M.command(args)
  local id = table.concat(args, " ")
  if not BINARY then
    log.w("aerospace " .. id)
    return
  end
  queue[#queue + 1] = { id = id, args = args }
  pump()
end

return M
