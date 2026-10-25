-- The framework: layer state, chords, the action kinds, the AeroSpace queue,
-- the hotkey pass-through, and the overlay. These run against the made-up
-- grammar in fixture.lua, so a binding change does not touch them; the real
-- bindings are in snapshot.txt. Timing is checked as before and after, not
-- against the exact delays.

local fixture = require("fixture")

local APP, UNLISTED, HYPER = fixture.APP, fixture.UNLISTED, fixture.HYPER
local HOTKEY = "system-events cmd+alt+ctrl+o"

local tests = {}
local function test(name, run) tests[#tests + 1] = { name = name, run = run } end

local function world(t, opts)
  opts = opts or {}
  opts.bindings = fixture.bindings()
  opts.targets = fixture.targets
  return t.world(opts)
end

test("the real config loads without warnings", function(t)
  t.world()
end)

-- Layers

test("keys pass through with no layer held", function(t)
  local w = world(t, { front = APP })
  local down, up = w:press("left")
  t.eq(down and up, true, "left reaches the app")
  t.expect(w, {})
end)

test("Right Option sends the verb to the operating system", function(t)
  local w = world(t, { front = APP })
  t.eq(w:down("f19"), false, "F19 swallowed")
  local down, up = w:press("left")
  t.eq(down or up, false, "left swallowed")
  w:up("f19")
  t.expect(w, { "aerospace go left" })
end)

test("Right Command sends the verb to the front app", function(t)
  local w = world(t, { front = APP })
  w:down("f18")
  w:press("left")
  w:up("f18")
  t.expect(w, { "press cmd+left" })
end)

test("Shift selects the Shift row", function(t)
  local w = world(t, { front = APP })
  w:down("f19")
  w:press("left", { shift = true })
  w:up("f19")
  t.expect(w, { "aerospace carry left" })
end)

test("an app with no entry ignores the App layer but still swallows keys", function(t)
  local w = world(t, { front = UNLISTED })
  w:down("f18")
  t.eq((w:press("left")), false, "left swallowed")
  w:up("f18")
  t.expect(w, {})
end)

test("unbound keys are swallowed and do nothing while a layer is held", function(t)
  local w = world(t, { front = APP })
  w:down("f19")
  t.eq((w:press("z")), false, "z swallowed")
  w:up("f19")
  t.expect(w, {})
end)

test("Command combinations are swallowed and do nothing while a layer is held", function(t)
  local w = world(t, { front = APP })
  w:down("f19")
  t.eq((w:press("left", { cmd = true })), false, "cmd+left swallowed")
  t.eq((w:press("left", { ctrl = true })), false, "ctrl+left swallowed")
  w:up("f19")
  t.expect(w, {})
end)

test("autorepeat runs nothing", function(t)
  local w = world(t)
  w:down("f19")
  w:down("left")
  t.eq(w:autorepeat("left"), false, "repeat swallowed")
  w:autorepeat("left")
  w:up("left")
  w:up("f19")
  t.expect(w, { "aerospace go left" })
end)

test("a key held across the layer release keeps its key-up swallowed", function(t)
  local w = world(t)
  w:down("f19")
  w:down("left")
  w:up("f19")
  t.eq(w:up("left"), false, "left up after release")
  local down, up = w:press("left")
  t.eq(down and up, true, "next left passes")
  t.expect(w, { "aerospace go left" })
end)

test("Space locks the layer and Escape unlocks it", function(t)
  local w = world(t)
  w:down("f19")
  w:press("space")
  w:up("f19")
  t.eq((w:press("left")), false, "left while locked")
  t.expect(w, { "aerospace go left" })
  w:press("escape")
  t.eq((w:press("left")), true, "left after unlock")
  t.expect(w, {})
end)

test("with both layers held, the last one pressed wins", function(t)
  local w = world(t, { front = APP })
  w:down("f19")
  w:down("f18")
  w:press("left")
  t.expect(w, { "press cmd+left" }, "App layer")
  w:up("f18")
  w:press("left")
  w:up("f19")
  t.expect(w, { "aerospace go left" }, "back to the OS layer")
end)

-- Chords

test("a chord takes one key, then the layer is back", function(t)
  local w = world(t)
  w:down("f19")
  w:press("s")
  w:press("right")
  w:press("right")
  w:up("f19")
  t.expect(w, { "aerospace pick right", "aerospace go right" })
end)

test("a chord runs on the layer that started it", function(t)
  local w = world(t, { front = APP })
  w:down("f18")
  w:press("s")
  w:press("right")
  w:up("f18")
  t.expect(w, { "press alt+right" })
end)

test("an unbound key, Shift, or Escape ends a chord with no action", function(t)
  for _, ender in ipairs({ { "z" }, { "right", { shift = true } }, { "escape" } }) do
    local w = world(t)
    w:down("f19")
    w:press("s")
    w:press(ender[1], ender[2])
    w:press("right")
    w:up("f19")
    t.expect(w, { "aerospace go right" }, "chord ended by " .. ender[1])
  end
end)

test("a chord takes its key after the layer is released", function(t)
  local w = world(t)
  w:down("f19")
  w:press("s")
  w:up("f19")
  t.eq((w:press("right")), false, "chord key swallowed")
  t.eq((w:press("right")), true, "next key passes")
  t.expect(w, { "aerospace pick right" })
end)

-- Action kinds

test("posted keys are marked, so the tap lets them through", function(t)
  local w = world(t, { front = APP })
  w:down("f18")
  w:press("left")
  w:up("f18")
  t.expect(w, { "press cmd+left" })
  t.eq(#w.problems, 0, "posted keys swallowed")
end)

test("a sequence posts its strokes in order, with a gap between", function(t)
  local w = world(t, { front = APP })
  w:down("f18")
  w:press("k")
  t.expectNow(w, { "press cmd+k" }, "first stroke right away")
  w:up("f18")
  t.expect(w, { "press cmd+j" }, "second stroke later")
end)

test("menu actions run after the tap returns, trying each path in order", function(t)
  local w = world(t, { front = APP })
  w:down("f18")
  w:press("m")
  t.expectNow(w, {}, "nothing inside the tap")
  w:up("f18")
  t.expect(w, { "menu Edit > First", "menu Edit > Second", "menu Third" })
end)

test("menu actions stop at the first path that exists", function(t)
  local w = world(t, { front = APP, menus = { ["Edit > Second"] = true } })
  w:down("f18")
  w:press("m")
  w:up("f18")
  t.expect(w, { "menu Edit > First", "menu Edit > Second" })
end)

test("a launch action reopens the app by bundle id", function(t)
  local w = world(t)
  w:down("f19")
  w:press("p")
  w:up("f19")
  w:settle()
  local effects = w:effects()
  t.eq(#effects, 1, "one effect")
  t.eq(effects[1]:match("^open .*com%.example%.Launcher$") ~= nil, true, "opens the launcher: " .. tostring(effects[1]))
end)

-- AeroSpace queue

test("AeroSpace commands run one at a time, in order", function(t)
  local w = world(t, { latency = 1 })
  w:down("f19")
  w:press("left")
  w:press("right")
  w:up("f19")
  t.expectNow(w, { "aerospace go left" }, "second waits")
  t.expect(w, { "aerospace go right" }, "second runs after the first exits")
end)

test("a hung AeroSpace command is terminated and the queue moves on", function(t)
  local w = world(t, { hang = function(_, args) return args[#args] == "left" end })
  w:down("f19")
  w:press("left")
  w:press("right")
  w:up("f19")
  t.expectNow(w, { "aerospace go left" })
  t.expect(w, { "terminate aerospace go left", "aerospace go right" })
  t.eq(#w:takeWarnings(), 1, "warnings about the hung command")
end)

-- Hotkeys through System Events

test("a hotkey gets past the layer that is still held", function(t)
  local w = world(t)
  w:down("f19")
  w:press("o")
  w:advance(0.5)
  t.expectNow(w, { HOTKEY }, "delivered while F19 is down")
  w:up("f19")
end)

test("a hotkey sent twice gets through twice", function(t)
  local w = world(t)
  w:down("f19")
  w:press("o")
  w:press("o")
  w:advance(0.5)
  w:up("f19")
  t.expect(w, { HOTKEY, HOTKEY })
end)

test("the typed key still reaches the layer while its hotkey is expected", function(t)
  local w = world(t, { deliverHotkeys = false })
  w:down("f19")
  w:press("o")
  t.eq((w:press("o")), false, "typed O swallowed by the layer")
  w:up("f19")
  t.expect(w, { HOTKEY, HOTKEY })
end)

test("an expected hotkey that never arrives stops passing", function(t)
  local w = world(t, { deliverHotkeys = false })
  w:down("f19")
  w:press("o")
  t.eq(w:down("o", HYPER), true, "passes soon after")
  w:up("o", HYPER)
  w:press("o")
  w:advance(30)
  t.eq(w:down("o", HYPER), false, "swallowed much later")
  w:up("f19")
end)

-- Overlay

test("the overlay appears after a delay and hides on release", function(t)
  local w = world(t)
  w:down("f19")
  w:advance(0)
  t.eq(w.overlay.visible, false, "not right away")
  w:advance(1)
  t.eq(w.overlay.visible, true, "after the delay")
  t.eq(w.overlay.title, "OS", "title")
  w:up("f19")
  t.eq(w.overlay.visible, false, "after release")
end)

test("a quick press never shows the overlay", function(t)
  local w = world(t)
  w:down("f19")
  w:press("left")
  w:up("f19")
  w:settle()
  t.eq(w.overlay.shows, 0, "times shown")
  w:effects()
end)

test("a locked layer keeps its overlay up, marked locked", function(t)
  local w = world(t)
  w:down("f19")
  w:press("space")
  w:up("f19")
  w:advance(1)
  t.eq(w.overlay.visible, true, "shown")
  t.eq(w.overlay.title:find("^OS.*locked") ~= nil, true, "title: " .. tostring(w.overlay.title))
  w:press("left")
  w:advance(1)
  t.eq(w.overlay.visible, true, "shown again after a binding")
  w:press("escape")
  t.eq(w.overlay.visible, false, "hidden after unlock")
  w:effects()
end)

test("a chord shows its own overlay", function(t)
  local w = world(t)
  w:down("f19")
  w:press("s")
  w:advance(1)
  t.eq(w.overlay.title, "Pick", "title")
  w:press("escape")
  t.eq(w.overlay.visible, false, "hidden when the chord ends")
  w:up("f19")
end)

-- Window search. Fn focuses. The fixture's B brings the window here.

local WINDOWS = {
  { id = "2", app = "Cursor", title = "Agents", workspace = "1" },
  { id = "5", app = "Chrome", title = "Inbox", workspace = "4" },
}

local function install(w)
  w.modules.switcher.install(WINDOWS)
end

test("the window list parses aerospace columns and ranks prefixes", function(t)
  local w = world(t)
  local parsed = w.modules.switcher.parse("5 ::: Chrome ::: 4 ::: Inbox (19)\n2 ::: Cursor ::: 1 ::: Agents\n")
  t.eq(parsed[1].id, "5", "id")
  t.eq(parsed[1].app, "Chrome", "app")
  t.eq(parsed[1].workspace, "4", "workspace")
  t.eq(parsed[1].title, "Inbox (19)", "title")
  t.eq(w.modules.switcher.rank(parsed, "age")[1].id, "2", "word prefix")
  t.eq(w.modules.switcher.rank(parsed, "ch")[1].id, "5", "app prefix beats a later row")
end)

test("holding Fn and typing focuses the match when Fn is released", function(t)
  local w = world(t)
  install(w)
  t.eq(w:down("c", { fn = true }), false, "letter swallowed")
  t.expectNow(w, {}, "no focus until release")
  w:up("c", { fn = true })
  w:press("h", { fn = true })
  w:up("fn")
  t.expect(w, { "aerospace focus --window-id 5" })
end)

test("releasing Fn without a query focuses nothing", function(t)
  local w = world(t)
  install(w)
  w:down("fn")
  w:advance(1)
  t.eq(w.overlay.visible, true, "the list is up")
  t.eq(w.overlay.title, "Windows", "title")
  w:up("fn")
  t.eq(w.overlay.visible, false, "hidden")
  t.expect(w, {})
end)

test("a tap of Fn does not show the list", function(t)
  local w = world(t)
  install(w)
  w:down("fn")
  w:up("fn")
  w:advance(1)
  t.eq(w.overlay.shows, 0, "times shown")
  t.expect(w, {})
end)

test("Fn and an arrow still reach the system", function(t)
  local w = world(t)
  install(w)
  t.eq(w:down("left", { fn = true }), true, "arrow passes")
  w:up("left", { fn = true })
  w:up("fn")
  t.expect(w, {})
end)

test("escape cancels the Fn search before release", function(t)
  local w = world(t)
  install(w)
  w:press("c", { fn = true })
  w:press("escape", { fn = true })
  w:up("fn")
  t.expect(w, {})
end)

test("releasing the globe key is a flags change", function(t)
  local w = world(t)
  install(w)
  w:down("fn")
  w:press("c", { fn = true })
  w:press("h", { fn = true })
  t.eq(w:flags({}), true, "the flags change reaches the system")
  t.eq(w.overlay.visible, false, "hidden")
  t.expect(w, { "aerospace focus --window-id 5" })
end)

test("escape closes the Fn search after Fn is already up", function(t)
  local w = world(t)
  install(w)
  w:down("fn")
  w:press("c", { fn = true })
  w:press("escape")
  t.eq(w.overlay.visible, false, "hidden")
  w:up("fn")
  t.expect(w, {})
end)

test("Fn search stays out of the way while a layer is held", function(t)
  local w = world(t)
  install(w)
  w:down("f19")
  w:press("c", { fn = true })
  w:up("f19")
  w:up("fn")
  t.expect(w, {})
end)

test("the window search keeps typing after the layer key comes up", function(t)
  local w = world(t, {
    stdout = function(args)
      if args[1] == "list-workspaces" then return "1\n" end
    end,
  })
  install(w)
  w:down("f19")
  w:press("b")
  w:up("f19")
  w:press("i")
  w:press("n")
  w:press("return")
  t.expect(w, {
    "aerospace list-workspaces --focused --format %{workspace}",
    "aerospace move-node-to-workspace --focus-follows-window --window-id 5 1",
  })
end)

test("a window already on this workspace is focused", function(t)
  local w = world(t, {
    stdout = function(args)
      if args[1] == "list-workspaces" then return "1\n" end
    end,
  })
  install(w)
  w:down("f19")
  w:press("b")
  w:press("a")
  w:press("g")
  w:press("e")
  w:press("return")
  w:up("f19")
  t.expect(w, {
    "aerospace list-workspaces --focused --format %{workspace}",
    "aerospace focus --window-id 2",
  })
end)

test("down picks the next window", function(t)
  local w = world(t, {
    stdout = function(args)
      if args[1] == "list-workspaces" then return "9\n" end
    end,
  })
  install(w)
  w:down("f19")
  w:press("b")
  w:press("down")
  w:press("return")
  w:up("f19")
  t.expect(w, {
    "aerospace list-workspaces --focused --format %{workspace}",
    "aerospace move-node-to-workspace --focus-follows-window --window-id 5 9",
  })
end)

test("escape cancels the window search", function(t)
  local w = world(t)
  install(w)
  w:down("f19")
  w:press("b")
  w:press("escape")
  w:press("return")
  w:up("f19")
  t.expect(w, {})
end)

return tests
