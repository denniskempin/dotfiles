-- The framework: layer state, chords, the action kinds, the OmniWM queue,
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
  t.expect(w, { "omniwmctl go left" })
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
  t.expect(w, { "omniwmctl carry left" })
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
  t.expect(w, { "omniwmctl go left" })
end)

test("a key held across the layer release keeps its key-up swallowed", function(t)
  local w = world(t)
  w:down("f19")
  w:down("left")
  w:up("f19")
  t.eq(w:up("left"), false, "left up after release")
  local down, up = w:press("left")
  t.eq(down and up, true, "next left passes")
  t.expect(w, { "omniwmctl go left" })
end)

test("Space locks the layer and Escape unlocks it", function(t)
  local w = world(t)
  w:down("f19")
  w:press("space")
  w:up("f19")
  t.eq((w:press("left")), false, "left while locked")
  t.expectNow(w, { "omniwmctl go left" })
  w:press("escape")
  t.eq((w:press("left")), true, "left after unlock")
  t.expect(w, {})
end)

test("a key that opens a panel ends the lock, so the panel gets the next keys", function(t)
  local w = world(t)
  w:down("f19")
  w:press("space")
  w:up("f19")
  t.eq((w:press("u")), false, "U runs on the locked layer")
  t.expectNow(w, { "omniwmctl panel" })
  t.eq((w:press("left")), true, "left reaches the panel")
  w:advance(1)
  t.eq(w.overlay.visible, false, "overlay stays hidden")
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
  t.expect(w, { "omniwmctl go left" }, "back to the OS layer")
end)

-- Chords

test("a chord takes one key, then the layer is back", function(t)
  local w = world(t)
  w:down("f19")
  w:press("s")
  w:press("right")
  w:press("right")
  w:up("f19")
  t.expect(w, { "omniwmctl pick right", "omniwmctl go right" })
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
    t.expect(w, { "omniwmctl go right" }, "chord ended by " .. ender[1])
  end
end)

test("a chord started with Shift takes its key with or without Shift", function(t)
  local w = world(t)
  w:down("f19")
  w:press("s", { shift = true })
  w:press("right", { shift = true })
  w:press("s", { shift = true })
  w:press("left")
  w:press("s")
  w:press("down", { shift = true })
  w:up("f19")
  t.expect(w, { "omniwmctl place right", "omniwmctl place left" })
end)

test("a chord takes its key after the layer is released", function(t)
  local w = world(t)
  w:down("f19")
  w:press("s")
  w:up("f19")
  t.eq((w:press("right")), false, "chord key swallowed")
  t.eq((w:press("right")), true, "next key passes")
  t.expect(w, { "omniwmctl pick right" })
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

test("a call action runs after the tap returns", function(t)
  local w = world(t)
  w:down("f19")
  w:press("y")
  t.expectNow(w, {}, "nothing inside the tap")
  w:up("f19")
  t.expect(w, { "omniwmctl called" })
end)

-- OmniWM queue

local json = require("world").json

local function replies(map)
  return function(args)
    local reply = map[table.concat(args, " ")]
    return reply and json.encode({ ok = true, result = { kind = args[2], payload = reply } }) or ""
  end
end

test("query results are decoded from the reply's payload", function(t)
  local w = world(t, {
    stdout = replies({ ["query workspaces --current"] = { workspaces = { { rawName = "3" } } } }),
  })
  local got
  w.modules.omniwm.query({ "workspaces", "--current" }, function(payload) got = payload end)
  w:settle()
  t.eq(got and got.workspaces[1].rawName, "3", "payload")
  local failed = "unset"
  w.modules.omniwm.query({ "windows" }, function(payload) failed = payload end)
  w:settle()
  t.eq(failed, nil, "an empty reply is nil")
  w:effects()
end)

test("the next monitor's direction follows left-to-right order and wraps", function(t)
  local w = world(t)
  local direction = w.modules.omniwm.nextMonitorDirection
  local left = { frame = { x = -1920, y = 0, width = 1920, height = 1080 } }
  local main = { frame = { x = 0, y = 0, width = 1800, height = 1130 } }
  local above = { frame = { x = 0, y = 1130, width = 1800, height = 1130 } }
  main.isCurrent = true
  t.eq(direction({ main, left }), "left", "wraps from the rightmost to the leftmost")
  main.isCurrent, left.isCurrent = false, true
  t.eq(direction({ main, left }), "right", "steps right")
  left.isCurrent, main.isCurrent = false, true
  t.eq(direction({ main, above }), "up", "AppKit y grows upward")
  t.eq(direction({ main }), nil, "one monitor")
end)

test("sending the workspace to the next monitor names it and the direction", function(t)
  local w = world(t, {
    stdout = replies({
      ["query displays --fields frame,is-current"] = {
        displays = {
          { isCurrent = true, frame = { x = 0, y = 0, width = 1800, height = 1130 } },
          { isCurrent = false, frame = { x = 1800, y = 0, width = 2560, height = 1440 } },
        },
      },
      ["query workspaces --current --fields raw-name"] = { workspaces = { { rawName = "2" } } },
    }),
  })
  w.modules.omniwm.sendWorkspaceToNextMonitor()
  t.expect(w, {
    "omniwmctl query displays --fields frame,is-current",
    "omniwmctl query workspaces --current --fields raw-name",
    "omniwmctl workspace move-to-monitor 2 right --force",
  })
end)

test("OmniWM commands run one at a time, in order", function(t)
  local w = world(t, { latency = 1 })
  w:down("f19")
  w:press("left")
  w:press("right")
  w:up("f19")
  t.expectNow(w, { "omniwmctl go left" }, "second waits")
  t.expect(w, { "omniwmctl go right" }, "second runs after the first exits")
end)

test("a hung OmniWM command is terminated and the queue moves on", function(t)
  local w = world(t, { hang = function(_, args) return args[#args] == "left" end })
  w:down("f19")
  w:press("left")
  w:press("right")
  w:up("f19")
  t.expectNow(w, { "omniwmctl go left" })
  t.expect(w, { "terminate omniwmctl go left", "omniwmctl go right" })
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
  t.expect(w, {}, "showing the overlay runs nothing")
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
  w:effects()
end)

test("the overlay groups its columns and uses the app's legend", function(t)
  local bindings = {
    title = { os = "OS", app = "App" },
    layer = {
      {
        name = "Tiles",
        { keys = "a", verb = "focus", label = "Focus tile", hint = "A" },
        { keys = "b", layer = "os", verb = "zoom", label = "Zoom tile", hint = "B" },
        { keys = "s", chord = "resize", label = "Resize tile", hint = "S" },
        { keys = "\\", layer = "app", chord = "split", label = "Split tile", hint = "\\ then arrow" },
      },
      {
        name = "Slots",
        { keys = "c", verb = "switch", label = "Switch slot", hint = "C" },
      },
      {
        name = "Other",
        { keys = "d", verb = "command", label = "Run command", hint = "D" },
      },
    },
    chords = {
      resize = {
        title = "Resize",
        rows = {
          { keys = "left", verb = "resize", label = "Shrink", hint = "←" },
        },
      },
      split = {
        title = "Split",
        rows = {
          { keys = "left", verb = "split", label = "Left", hint = "←" },
          { keys = "right", verb = "split", label = "Right", hint = "→" },
        },
      },
    },
  }
  local function targets(actions)
    local stroke = actions.stroke
    return {
      system = {
        focus = actions.wm("focus"),
        zoom = actions.wm("zoom"),
        resize = actions.wm("resize"),
        switch = actions.wm("switch"),
        command = actions.wm("command"),
      },
      apps = {
        ["com.example.App"] = {
          legend = {
            focus = "Focus pane",
            switch = { label = "Switch tab", hint = "C'" },
            split = "Split pane",
          },
          focus = stroke({ "cmd" }, "a"),
          switch = stroke({ "cmd" }, "c"),
          split = { right = stroke({ "cmd" }, "d") },
        },
      },
    }
  end
  local function open(front, frontName)
    return t.world({
      bindings = bindings,
      targets = targets,
      front = front,
      frontName = frontName,
    })
  end

  local app = open("com.example.App", "Example")
  app:down("f18")
  app:advance(1)
  t.eq(app.overlay.texts, {
    "App  ·  Example",
    "Tiles",
    "Focus pane",
    "A",
    "Split pane",
    "\\ then arrow",
    "Slots",
    "Switch tab",
    "C'",
    "space locks      esc clears",
  }, "app legend")
  app:press("s")
  app:advance(1)
  t.eq(app.overlay.title, "App  ·  Example", "a chord the app cannot run does not start")
  app:press("\\")
  app:advance(1)
  t.eq(app.overlay.texts, {
    "Split",
    "Right",
    "→",
    "esc cancels",
  }, "only the directions the app has")
  app:press("escape")
  app:up("f18")
  app:effects()

  local os = open("com.example.App", "Example")
  os:down("f19")
  os:advance(1)
  t.eq(os.overlay.texts, {
    "OS",
    "Tiles",
    "Focus tile",
    "A",
    "Zoom tile",
    "B",
    "Resize tile",
    "S",
    "Slots",
    "Switch slot",
    "C",
    "Other",
    "Run command",
    "D",
    "space locks      esc clears",
  }, "system legend")
  os:press("s")
  os:advance(1)
  t.eq(os.overlay.title, "Resize", "the system chord still starts")
  os:press("escape")
  os:up("f19")
  os:effects()

  local none = open("com.example.Unlisted", "Notes")
  none:down("f18")
  none:advance(1)
  t.eq(none.overlay.texts, {
    "App  ·  Notes",
    "No bindings",
    "space locks      esc clears",
  }, "an app with no entry")
  none:up("f18")
  none:effects()
end)

-- Fn window search. Right Option+O is OmniWM's own list, so it is a plain
-- command in the snapshot.

local WINDOWS = {
  { id = "2", handle = "ow_2", app = "Cursor", title = "Agents", workspace = "1" },
  { id = "5", handle = "ow_5", app = "Chrome", title = "Inbox", workspace = "4" },
}

local function install(w, list)
  w.modules.switcher.install(list or WINDOWS)
end

test("chrome tabs replace their window, active tab first", function(t)
  local w = world(t)
  local switcher = w.modules.switcher
  local tabs = switcher.parseTabs(
    "99\t2\t0\t0\t0\t100\t100\tLater\n99\t1\t1\t0\t0\t100\t100\tInbox\n"
  )
  local windows = {
    { id = "5", app = "Google Chrome", workspace = "4", title = "Inbox - Google Chrome" },
    { id = "2", app = "Cursor", workspace = "1", title = "Agents" },
  }
  local frames = { ["5"] = { x = 0, y = 0, w = 100, h = 100 } }
  local list = switcher.expand(windows, switcher.groupTabs(windows, tabs, frames))
  t.eq(#list, 3, "two tabs and Cursor")
  t.eq(list[1].title, "Inbox", "active tab first")
  t.eq(list[1].tab, 1, "tab index")
  t.eq(list[1].chrome, "99", "chrome window")
  t.eq(list[1].app, "Google Chrome", "same app name as the window")
  t.eq(list[2].title, "Later", "the other tab")
  t.eq(list[3].app, "Cursor", "other windows stay")
  local unmatched = switcher.expand(windows, switcher.groupTabs(windows, tabs, {}))
  t.eq(#unmatched, 2, "no bounds match keeps the window")
  t.eq(unmatched[1].tab, nil, "not a tab")
end)

test("focusing a chrome tab selects the tab and the window", function(t)
  local w = world(t)
  install(w, {
    { id = "5", handle = "ow_5", app = "Google Chrome", title = "Inbox", workspace = "4", tab = 2, chrome = "99", order = 1 },
  })
  w:down("fn")
  w:press("i", { fn = true })
  w:up("fn")
  t.expect(w, {
    'osascript -e tell application "Google Chrome" to set active tab index of window id 99 to 2',
    "omniwmctl window navigate ow_5",
  })
end)

test("the window list parses OmniWM windows and ranks prefixes", function(t)
  local w = world(t)
  local parsed = w.modules.switcher.parse({
    windows = {
      { id = "ow_a", windowId = 5, app = { name = "Chrome" }, workspace = { rawName = "4" }, title = "Inbox (19)" },
      { id = "ow_b", windowId = 2, app = { name = "Cursor" }, workspace = { rawName = "1" }, title = "Agents" },
      { id = "ow_c", app = { name = "No window id" }, workspace = { rawName = "1" } },
    },
  })
  t.eq(#parsed, 2, "rows without a macOS window id are skipped")
  t.eq(parsed[1].id, "5", "macOS window id")
  t.eq(parsed[1].handle, "ow_a", "OmniWM id")
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
  t.expect(w, { "omniwmctl window navigate ow_5" })
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
  t.expect(w, { "omniwmctl window navigate ow_5" })
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

return tests
