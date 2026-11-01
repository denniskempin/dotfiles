## Specification

This spec defines consistent bindings for frequently used navigation actions across OS and apps. 

The same keys are used for the same actions. There are two layer keys, one to target the OS and one to target the foreground app. 

An overlay window showing possible bindings is used to help navigate the system. 

### Shared nouns

To use the same keys for the same actions, we need to define abstract nouns for things that have similar concepts at the OS level and app level.


| Noun     | What it is                                                        | Operating system              | App                                                       |
| -------- | ----------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------- |
| Tile     | The 2D unit you focus and move in a direction                     | Window, in a column of the strip | Pane: an editor group, a terminal split, a note tab group |
| Slot     | An item in the ordered list you step through or jump to by number | Workspace                     | Tab                                                       |
| History  | A stack you walk backward and forward                             | The window and the workspace focused before this one | That app's own back and forward stack                     |
| Command  | A named action                                                    | The system command launcher   | The app's command palette                                 |
| Document | A thing you open                                                  | OmniWM's window list          | Webpages, files, notes, terminal sessions                 |


### Layers

There are two layer keys:


| Role             | Key                |
| ---------------- | ------------------ |
| Operating system | Hold Right Option  |
| App              | Hold Right Command |


`Layer Key + space` will trigger the layer to be locked. The layer key can then be released and all bindings can be used until escape is pressed. Open document, the quake terminal, and Overview end the lock, because what they open takes the keys typed next.

Left Command and Left Option stay modifiers. Fn is the globe key. Caps Lock is Escape.

### The operating system's layout

Windows are laid out the way niri lays them out. Each workspace is a horizontal strip of columns that scrolls sideways and can be wider than the screen. A column holds one window, or several stacked top to bottom, or several as tabs. A monitor's workspaces stack top to bottom.

The arrows follow that shape. Left and right move along the strip. Up and down move through the column, and past its top or bottom to the workspace above or below. Switch slot steps through the same stack of workspaces without going through the column.

### The map

#### Tiles


| Verb + noun  | Key                        | Operating system                                                                                                                                                                   | App                                                                                                         |
| ------------ | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Focus tile   | arrows                     | Left and right focus the column on that side, and the strip scrolls to show it. At the end of the strip, focus crosses to the next monitor. Up and down focus the window above or below in the column. Past the top or bottom of the column, they focus the workspace above or below | Focus the pane in that direction                                                                            |
| Move tile    | Shift+arrows               | Left and right move the column one place along the strip. At the end of the strip, the column moves to the next monitor. Up and down move the window within its column. Past the top or bottom of the column, the window moves to the workspace above or below, and focus follows it | Carry the tab, or in a terminal the pane, into the tile in that direction, creating it when there is none   |
| Zoom tile    | Enter                      | The window fills the screen. Enter again puts it back                                                                                                                              | The pane fills the window                                                                                   |
| Close tile   | `X`                        | Close the window                                                                                                                                                                   | Close the pane. In an editor, the tabs inside it close with it. In a terminal, the last pane closes the tab |
| Split tile   | `\` then an arrow          | —                                                                                                                                                                                  | A new pane on that side. An editor has all four directions. A terminal and a notes app have down and right  |
| Resize tile  | `S` then an arrow          | Left narrows the column, right widens it, by a tenth of the screen. Down makes the window taller within its column, up makes it shorter. One step per chord                       | Left shrinks the width, right grows it. Down grows the height, up shrinks it, on the pane                   |
| Layout tiles | `L` then a letter          | `W` steps the column through a third, half, and two thirds of the screen. `F` toggles the column between the full screen width and its own width. `A` toggles the column between stacked and tabbed. `C` centers the column on the screen. `=` evens out the sizes in the workspace | `F` flips the axis. `=` makes sibling panes the same size                                                   |
| Join tile    | `J` then `←` or `→`        | A window alone in its column joins the column on that side. A window that shares a column leaves it, as a new column on that side | —                                                                                                           |


#### Slots


| Verb + noun       | Key                                 | Operating system                                                                                                                                                                                            | App                                                    |
| ----------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| Switch slot       | `;` previous, `'` next              | The workspace above or below on this monitor, wrapping around. Empty workspaces are included                                                                                                                | The previous or next tab                               |
| Jump to slot      | `1`–`9`; in apps `9` is last        | Workspace 1 through 9, on whichever monitor holds it                                                                                                                                                        | Tab 1 through 8. `9` is the last tab                   |
| Send tile to slot | Shift+`;`, Shift+`'`, Shift+`1`–`9` | Move the window to the workspace above, below, or with that number, and follow it                                                                                                                           | Move the tab one step, to that position, or to the end |
| Send column to slot | `J` then `↑` or `↓`               | Move the whole column, every window in it, to the workspace above or below, and follow it                                                                                                                 | —                                                      |


#### Other


| Verb + noun   | Key                   | Operating system                                                                                                                           | App                                         |
| ------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| Walk history  | `[` back, `]` forward | `[` focuses the window focused before this one. `]` returns to the workspace this monitor showed before this one. Each keeps one step, so pressing it again goes back | Back and forward in that app                |
| Run command   | `P`                   | Open the command launcher                                                                                                                  | Open the command palette                    |
| Open document | `O`                   | Open OmniWM's window list, most recently focused first. Return goes to the chosen window. Shift+Return brings it here, as a new column right of the focused one. Chrome tabs are not listed; the Fn search has them | Open the switcher for documents in this app |
| Quake terminal | `T`                  | Show or hide OmniWM's quake terminal                                                                                         | —                                           |
| Overview      | `V`                   | Zoom out to every workspace and its columns. Arrows move the selection, Return goes to the selected window, Escape closes it | —                                           |
| Focus monitor        | Tab               | Focus the next monitor. With two monitors, that is the other one |
| Send slot to monitor | Shift+Tab         | Move the current workspace to the next monitor                   |


### Overlay Window

An overlay window showing possible layer bindings is shown after a short delay when a layer key is held or locked. It disappears once a binding is selected.

When another key is expected in a sequence, a similar overlay window is shown after a delay with possible follow up keys. 

## Implementation

Karabiner translates two layer keys and maps Caps Lock to Escape. Hammerspoon dispatches the grammar, draws the overlay, and runs the commands. The window manager is OmniWM, a scrolling tiler with niri's layout, configured by `configs/omniwm/settings.toml`. Its own hotkeys are off (`hotkeysEnabled = false`, `hotkeys = []`) and its IPC server is on (`ipcEnabled = true`), so every key goes through Hammerspoon and `omniwmctl`. skhd is not used.

### Karabiner


Caps Lock is a simple modification to Escape. It is Escape while held and when tapped.


| From          | Held          | Alone | Timeout |
| ------------- | ------------- | ----- | ------- |
| Right Command | F18, via `to` | —     | —       |
| Right Option  | F19, via `to` | —     | —       |


F18 and F19 are the interface between the two tools. Each goes down with the physical key and stays down until Right Command or Right Option is released. A tap is that key-down and key-up with no other key. The brief press is a no-op. Leave key repeat enabled on these two. With `repeat` set to `false`, Karabiner posts the key-up at the same time as the key-down, and the layer disarms before the next key.

Fn is not remapped. A tap changes the input source, and Fn+arrow is Home, End, Page Up, and Page Down.

### Hammerspoon

`configs/hammerspoon/bindings.lua` holds the grammar as rows: key, Shift, verb or chord, and the overlay line. `configs/hammerspoon/targets.lua` says what each verb does on the operating system and in each app. `init.lua` runs the tap and the layer state, and needs no edit to change a binding.

One event tap watches key down and key up.

- F18 down arms the App layer. F19 down arms the operating-system layer. Key repeat is ignored, and both keys are swallowed. Key up disarms a layer that is not locked.
- Space, while a layer is armed and no chord is pending, locks that layer. The layer key can come up and the layer stays armed. Escape, with no chord pending, clears the lock. A row marked `unlocks`, Open document, the quake terminal, and Overview, clears it too.
- While a layer is armed, every other key is swallowed. A listed key runs its verb. Shift is read off the event flags. Command combinations are swallowed with the rest.
- Delete on the App layer is posted as forward delete.
- A layer that is held or locked shows its overlay after 250 ms. The overlay hides once a binding is selected, and on key up when the layer is not locked. While the layer stays locked, the 250 ms timer starts again after the binding. The overlay is an `hs.canvas` on the focused screen, non-activating. Nothing goes to Notification Center.
- `\`, `S`, and `L` on the App layer, and `S`, `L`, and `J` on the operating-system layer, start a chord. The layer overlay hides and a follow-up overlay lists the keys that chord accepts. Split, resize, and the column chord accept an arrow. Layout accepts `F` and `=` on the App layer, and `W`, `F`, `A`, `C`, and `=` on the operating-system layer.
- While a chord is waiting, the tap keeps swallowing keys after the layer key comes up. A lock stays in force. The pending verb wins over the layer, so an arrow with the layer key still down is the argument. F18 and F19 are not arguments. One argument clears the verb. Escape and any unlisted key clear the chord and leave a lock in place. Key repeat is swallowed, including inside a chord.

OmniWM commands run through `hs.task` on a queue, one at a time in key order, so the tap never waits on OmniWM.

Posted shortcuts re-enter the tap. Hammerspoon marks its own events and ignores them on the way back. A two-stroke shortcut is two marked keystrokes.

With Hammerspoon not running, or in a password field, Caps Lock still sends Escape. Right Command and Right Option still become F18 and F19, and those keys do nothing without the tap. Fn still changes the input source. Typed characters are unchanged. The lock, the Fn window search, and App-layer Delete stop, because those need the tap.

### Operating system

Each operating-system key runs `omniwmctl`, usually `omniwmctl command <name>`.


| Verb                 | Command                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------ |
| Focus tile           | `focus left` / `right`; `focus-window-or-workspace-up` / `-down`                                 |
| Move tile            | `move-column left` / `right`; `move-window-up-or-to-workspace-up` / `move-window-down-or-to-workspace-down` |
| Zoom tile            | `toggle-fullscreen`                                                                              |
| Switch slot          | `switch-workspace prev` / `next`                                                                 |
| Jump to slot         | `switch-workspace 1` … `switch-workspace 9`                                                      |
| Send tile to slot    | `move-to-workspace up` / `down`, or `N`                                                          |
| Focus monitor        | `focus-monitor next`                                                                             |
| Send slot to monitor | `query displays`, then `workspace move-to-monitor <name> <direction> --force`                    |
| Close tile           | `close-focused-window`                                                                           |
| Join tile            | `consume-or-expel-window-left` / `-right`                                                        |
| Send column to slot  | `move-column-to-workspace up` / `down`                                                           |
| Walk history         | `focus previous`; `switch-workspace back-and-forth`                                              |
| Quake terminal       | `toggle-quake-terminal`                                                                          |
| Overview             | `toggle-overview`                                                                                |
| Resize tile          | `set-container-primary-span -10%` / `+10%` on left / right, `set-window-secondary-span +10%` / `-10%` on down / up |
| Layout width         | `cycle-size forward`                                                                             |
| Layout full width    | `toggle-container-full-primary-span`                                                             |
| Layout tabbed        | `toggle-column-tabbed`                                                                           |
| Layout center        | `center-column`                                                                                  |
| Layout equalize      | `balance-sizes`                                                                                  |
| Run command          | `open -g -b com.raycast.macos`, which shows Raycast's search bar                                 |
| Open document        | `open-command-palette windows`. The palette handles its own keys. Shift+Return on an empty workspace moves the window there, since there is no column to place it beside |


Holding Fn and typing focuses a window without moving it. This search is Hammerspoon's, not OmniWM's, because it acts when Fn is released and lists Chrome tabs. The letters are a prefix of the app name, the title, or a word in either, and releasing Fn runs `window navigate <id>` on the first match, which switches to its workspace. Each tab of a Google Chrome window is a row of its own, with that window's app name and the tab's title. Releasing Fn on a tab focuses the window and selects the tab. Fn itself is not swallowed: a tap still changes the input source, and Fn with an arrow is still Home, End, Page Up, or Page Down. The list appears on the first letter, or after the overlay delay when Fn is held with no letter yet. Releasing Fn with an empty query focuses nothing.

`focus.crossesMonitorAtEdge` and `focus.moveCrossesMonitorAtEdge` carry Focus and Move across monitors at the ends of the strip. `focus.followsWindowToMonitor` makes Send tile to slot and Send column to slot follow to the new workspace.

Focus up and down do not wrap: at the top workspace up stops, and at the bottom down stops. Switch slot wraps from the last workspace to the first. Both include empty workspaces, because `workspaceBar.hideEmptyWorkspaces` is off.

OmniWM moves a workspace to a monitor by direction, not by "next". Send slot to monitor sorts the displays left to right, as `focus-monitor next` steps, takes the one after the current display, and passes the direction its center lies in.

Workspaces are defined in `settings.toml`, so all nine always exist. 1 through 5, 8, and 9 belong to the main display, and 6 and 7 to the secondary one, as in OmniWM's defaults.

OmniWM requires "Displays have separate Spaces" on.

### App integration

Hammerspoon names the frontmost app and delivers that app's own shortcut, or selects a menu item when the action has no shortcut. The apps keep the bindings they already have. The translation lives in Hammerspoon.

An app with no row below ignores the App layer.

Walk history in iTerm posts Option+J and Option+K, which fish binds to `prevd` and `nextd`. iTerm's Option keys send Esc+, so fish sees `\ej` and `\ek`.

## Per-app delivery

A cell is the shortcut Hammerspoon posts. A `menu` cell is the item it selects. A dash means the app has neither.

Where the delivered action cannot do what the specification says, the cell says so. Cursor uses the VS Code column.

| Verb + noun               | Chrome                                                | VS Code                                                                                                                                                  | iTerm2                                                                                                                                                                                          | Obsidian                                                                                          |
| ------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Focus tile                | —                                                     | `Command+K` then `Command+←` / `↓` / `↑` / `→`                                                                                                          | menu Select Split Pane > Select Pane Left / Below / Above / Right                                                                                                                              | Unbound                                                                                           |
| Move tile                 | —                                                     | Unbound. The commands create a group when there is none                                                                                                 | Unbound. The key action swaps two panes and does nothing when that direction has no pane                                                                                                       | —                                                                                                 |
| Zoom tile                 | —                                                     | `Command+K` then `Command+M`                                                                                                                             | menu Maximize Active Pane                                                                                                                                                                       | —                                                                                                 |
| Switch slot               | `Command+Shift+[` , `Command+Shift+]`                 | `Command+K` then `Command+Option+←` / `→`                                                                                                                | `Command+←` / `Command+→`                                                                                                                                                                       | `Command+Shift+[` , `Command+Shift+]`                                                             |
| Jump to slot              | `Command+1`–`9`. `Command+9` is the last tab          | `Control+1`–`8`. Jump `9` posts `Command+9`, the last tab                                                                                                | `Command+1`–`8`. `Command+9` selects the ninth tab                                                                                                                                              | `Command+1`–`8`. `Command+9` is the last tab                                                      |
| Send tile to slot, step   | `Control+Shift+PageUp`, `Control+Shift+PageDown`      | `Command+K` then `Command+Shift+←` / `→`                                                                                                                 | `Command+Shift+←` / `Command+Shift+→`                                                                                                                                                           | —                                                                                                 |
| Send tile to slot, number | —                                                     | Unbound. Each position needs its own argument                                                                                                            | —                                                                                                                                                                                               | —                                                                                                 |
| Walk history              | `Command+[` , `Command+]`                             | `Control+-` , `Control+Shift+-`                                                                                                                          | `Option+J` / `Option+K`, fish's `prevd` / `nextd`                                                                                                                                               | `Command+Option+←` , `Command+Option+→`                                                           |
| Close tile                | —                                                     | `Command+W` closes the active editor. Closing the group is unbound                                                                                      | `Command+W`. The last pane closes the tab                                                                                                                                                       | `Command+W` closes the active tab. Closing the group is unbound                                  |
| Run command               | `Command+Shift+/` (Help menu search)                  | `Command+Shift+P`                                                                                                                                        | `Command+Shift+/` (Help menu search)                                                                                                                                                            | `Command+P`                                                                                       |
| Open document             | `Command+Shift+A` (Search tabs)                       | `Command+P`                                                                                                                                              | menu Open Quickly                                                                                                                                                                               | `Command+O`                                                                                       |
| Split tile ← ↓ ↑ →        | —                                                     | `Command+\` splits along the current layout                                                                                                              | —, `Command+Shift+D`, —, `Command+D`                                                                                                                                                            | —, menu Split down, —, menu Split right                                                           |
| Resize tile ← ↓ ↑ →       | —                                                     | Unbound. The commands resize the editor against the sidebar and panel                                                                                   | menu Move Divider Left / Down / Up / Right. The divider moves, and the focused pane grows or shrinks from the side the divider is on                                                            | —                                                                                                 |
| Layout flip               | —                                                     | `Command+Option+0`                                                                                                                                       | —                                                                                                                                                                                               | —                                                                                                 |
| Layout equalize           | —                                                     | Unbound                                                                                                                                                  | menu Arrange Split Panes Evenly                                                                                                                                                                 | —                                                                                                 |


## macOS settings

- **Displays have separate Spaces.** On. System Settings > Desktop & Dock. OmniWM will not manage windows without it. `nix/darwin/defaults.nix` sets it, and a change takes a logout.
- **Globe key.** System Settings > Keyboard > "Press 🌐 key to": Change Input Source. Fn is not remapped, and this setting is the language change.
- **VoiceOver.** Not a concern. Control+Option is not used.

