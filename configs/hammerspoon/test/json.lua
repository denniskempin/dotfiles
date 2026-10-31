-- A JSON decoder for the fake hs.json. Like Hammerspoon's, it raises an
-- error on bad input and decodes null as nil.

local M = {}

local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function fail(text, i, what)
  error(("json: %s at %d near %q"):format(what, i, text:sub(i, i + 10)), 0)
end

local value

local function skip(text, i)
  return text:find("[^ \t\r\n]", i) or #text + 1
end

local function str(text, i)
  local out, j = {}, i + 1
  while true do
    local c = text:sub(j, j)
    if c == "" then fail(text, i, "unterminated string") end
    if c == '"' then return table.concat(out), j + 1 end
    if c == "\\" then
      local e = text:sub(j + 1, j + 1)
      if e == "u" then
        local hex = text:sub(j + 2, j + 5)
        if not hex:match("^%x%x%x%x$") then fail(text, j, "bad escape") end
        out[#out + 1] = utf8.char(tonumber(hex, 16))
        j = j + 6
      elseif ESCAPES[e] then
        out[#out + 1] = ESCAPES[e]
        j = j + 2
      else
        fail(text, j, "bad escape")
      end
    else
      out[#out + 1] = c
      j = j + 1
    end
  end
end

local function list(text, i)
  local out = {}
  i = skip(text, i + 1)
  if text:sub(i, i) == "]" then return out, i + 1 end
  while true do
    local v
    v, i = value(text, i)
    out[#out + 1] = v
    i = skip(text, i)
    local c = text:sub(i, i)
    if c == "]" then return out, i + 1 end
    if c ~= "," then fail(text, i, "expected , or ]") end
    i = skip(text, i + 1)
  end
end

local function object(text, i)
  local out = {}
  i = skip(text, i + 1)
  if text:sub(i, i) == "}" then return out, i + 1 end
  while true do
    if text:sub(i, i) ~= '"' then fail(text, i, "expected a key") end
    local k
    k, i = str(text, i)
    i = skip(text, i)
    if text:sub(i, i) ~= ":" then fail(text, i, "expected :") end
    local v
    v, i = value(text, skip(text, i + 1))
    out[k] = v
    i = skip(text, i)
    local c = text:sub(i, i)
    if c == "}" then return out, i + 1 end
    if c ~= "," then fail(text, i, "expected , or }") end
    i = skip(text, i + 1)
  end
end

value = function(text, i)
  i = skip(text, i)
  local c = text:sub(i, i)
  if c == "{" then return object(text, i) end
  if c == "[" then return list(text, i) end
  if c == '"' then return str(text, i) end
  for word, v in pairs({ ["true"] = true, ["false"] = false }) do
    if text:sub(i, i + #word - 1) == word then return v, i + #word end
  end
  if text:sub(i, i + 3) == "null" then return nil, i + 4 end
  local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
  if num and num ~= "" and num ~= "-" then return math.tointeger(tonumber(num)) or tonumber(num), i + #num end
  fail(text, i, "unexpected input")
end

function M.decode(text)
  if type(text) ~= "string" then error("json: not a string", 0) end
  local v, i = value(text, 1)
  if skip(text, i) <= #text then fail(text, i, "trailing input") end
  return v
end

-- For tests that build stdout from tables. Keys are sorted so output is stable.
function M.encode(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" or t == "number" then return tostring(v) end
  if t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c)
      if c == '"' then return '\\"' end
      if c == "\\" then return "\\\\" end
      return ("\\u%04x"):format(c:byte())
    end) .. '"'
  end
  if #v > 0 or next(v) == nil then
    local out = {}
    for i, item in ipairs(v) do out[i] = M.encode(item) end
    return "[" .. table.concat(out, ",") .. "]"
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = M.encode(k) .. ":" .. M.encode(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end

return M
