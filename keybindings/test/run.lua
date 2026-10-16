-- Offline tests for keybindings/hammerspoon. From the repo root:
--
--   lua keybindings/test/run.lua            scenarios, then the snapshot
--   lua keybindings/test/run.lua --update   rewrite snapshot.txt
--
-- A test fails on a failed check, a warning the config logged and the test
-- did not take, or a posted key the config's own tap swallowed.

local TEST_DIR = arg[0]:match("^(.*)/[^/]*$") or "."
package.path = TEST_DIR .. "/?.lua;" .. package.path

local world = require("world")
local snapshot = require("snapshot")

local UPDATE = arg[1] == "--update"
local SNAPSHOT = TEST_DIR .. "/snapshot.txt"

local function show(list)
  if #list == 0 then return "    (nothing)" end
  local out = {}
  for i, v in ipairs(list) do out[i] = "    " .. tostring(v) end
  return table.concat(out, "\n")
end

local function sameList(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local worlds

local t = {}

function t.world(opts)
  local w = world.new(opts)
  worlds[#worlds + 1] = w
  return w
end

function t.eq(actual, expected, what)
  if type(expected) == "table" then
    if not sameList(actual, expected) then
      error(("%s\n  expected:\n%s\n  got:\n%s"):format(what or "lists differ", show(expected), show(actual)), 2)
    end
  elseif actual ~= expected then
    error(("%s: expected %s, got %s"):format(what or "values differ", tostring(expected), tostring(actual)), 2)
  end
end

-- Effects once every timer and process has run.
function t.expect(w, expected, what)
  w:settle()
  local actual = w:effects()
  if not sameList(actual, expected) then
    error(("%s\n  expected:\n%s\n  got:\n%s"):format(what or "effects differ", show(expected), show(actual)), 2)
  end
end

-- Effects so far, without moving the clock.
function t.expectNow(w, expected, what)
  local actual = w:effects()
  if not sameList(actual, expected) then
    error(("%s\n  expected:\n%s\n  got:\n%s"):format(what or "effects differ", show(expected), show(actual)), 2)
  end
end

local failures = 0

local function fail(name, message)
  failures = failures + 1
  print("FAIL " .. name .. "\n  " .. message:gsub("\n", "\n  "))
end

local tests = require("scenarios")
for _, test in ipairs(tests) do
  worlds = {}
  local ok, err = pcall(test.run, t)
  if not ok then
    fail(test.name, tostring(err))
  else
    local leftovers = {}
    for _, w in ipairs(worlds) do
      for _, p in ipairs(w.problems) do leftovers[#leftovers + 1] = p end
      for _, warning in ipairs(w.warnings) do leftovers[#leftovers + 1] = "warning: " .. warning end
    end
    if #leftovers > 0 then
      fail(test.name, show(leftovers))
    end
  end
end
print(("%d scenarios, %d failed"):format(#tests, failures))

-- Line diff over the longest common subsequence, with each change under the
-- section header it falls in.
local function diff(old, new)
  local n, m = #old, #new
  local lcs = {}
  for i = n + 1, 1, -1 do
    lcs[i] = {}
    for j = m + 1, 1, -1 do
      if i > n or j > m then
        lcs[i][j] = 0
      elseif old[i] == new[j] then
        lcs[i][j] = lcs[i + 1][j + 1] + 1
      else
        lcs[i][j] = math.max(lcs[i + 1][j], lcs[i][j + 1])
      end
    end
  end
  local out, header, shown = {}, nil, nil
  local function emit(line)
    if header ~= shown then
      out[#out + 1] = header
      shown = header
    end
    out[#out + 1] = line
  end
  local i, j = 1, 1
  while i <= n or j <= m do
    if i <= n and j <= m and old[i] == new[j] then
      if old[i]:sub(1, 2) == "# " then header = old[i] end
      i, j = i + 1, j + 1
    elseif i <= n and (j > m or lcs[i + 1][j] >= lcs[i][j + 1]) then
      emit("- " .. old[i])
      i = i + 1
    else
      emit("+ " .. new[j])
      j = j + 1
    end
  end
  return out
end

local function lines(text)
  local out = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do out[#out + 1] = line end
  return out
end

local generated, problems = snapshot.generate()
for _, p in ipairs(problems) do fail("snapshot", p) end

if UPDATE then
  local file = assert(io.open(SNAPSHOT, "w"))
  file:write(generated)
  file:close()
  print("wrote " .. SNAPSHOT)
else
  local file = io.open(SNAPSHOT, "r")
  local saved = file and file:read("a") or ""
  if file then file:close() end
  if saved ~= generated then
    failures = failures + 1
    print("FAIL snapshot: the bindings differ from snapshot.txt. If the change is intended, run with --update.")
    print(table.concat(diff(lines(saved), lines(generated)), "\n"))
  else
    print("snapshot matches")
  end
end

os.exit(failures == 0 and 0 or 1)
