## Specification

This spec defines consistent bindings for frequently used navigation actions across OS and apps. 

The same keys are used for the same actions. There are two layer keys, one to target the OS and one to target the foreground app. 

An overlay window showing possible bindings is used to help navigate the system. 

### Shared nouns

To use the same keys for the same actions, we need to define abstract nouns for things that have similar concepts at the OS level and app level.


| Noun     | What it is                                                        | Operating system              | App                                                       |
| -------- | ----------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------- |
| Tile     | The 2D unit you focus and move in a direction                     | Window                        | Pane: an editor group, a terminal split, a note tab group |
| Slot     | An item in the ordered list you step through or jump to by number | Workspace                     | Tab                                                       |
| History  | A stack you walk backward and forward                             | —                             | That app's own back and forward stack                     |
| Command  | A named action                                                    | The system command launcher   | The app's command palette                                 |
| Document | A thing you open                                                  | The system window switcher    | Webpages, files, notes, terminal sessions                 |


### Layers

There are two layer keys:


| Role             | Key                                                         |
| ---------------- | ----------------------------------------------------------- |
| Operating system | Hold Caps Lock. A tap sends Escape                          |
| App              | Hold Fn. A tap performs the native action (language change) |


`Layer Key + space` will trigger the layer to be locked. The layer key can then be released and all bindings can be used until escape is pressed.

### The map

#### Tiles


| Verb + noun  | Key                        | Operating system                                                                                                                                                                   | App                                                                                                         |
| ------------ | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Focus tile   | arrows                     | Focus the window in that direction. At the edge of the screen, focus crosses to the next monitor                                                                                   | Focus the pane in that direction                                                                            |
| Move tile    | Shift+arrows               | Move the window that way. A new split is created when that direction has no neighbor. At the edge of the screen, the window moves to the next monitor                              | Carry the tab, or in a terminal the pane, into the tile in that direction, creating it when there is none   |
| Zoom tile    | Enter                      | The window fills the workspace. Focusing another window there restores the others                                                                                                  | The pane fills the window                                                                                   |
| Close tile   | `X`                        | Close the window                                                                                                                                                                   | Close the pane. In an editor, the tabs inside it close with it. In a terminal, the last pane closes the tab |
| Split tile   | `\` then an arrow          | —                                                                                                                                                                                  | A new pane on that side. An editor has all four directions. A terminal and a notes app have down and right  |
| Resize tile  | `S` then an arrow          | Left shrinks the width, right grows it. Down grows the height, up shrinks it. One step per chord                                                                                   | The same, on the pane                                                                                       |
| Layout tiles | `L` then `F`, `A`, or `=`  | `F` flips side-by-side and stacked, and leaves tiled-versus-accordion as it is. `A` flips tiled and accordion, and leaves the axis as it is. `=` makes every sibling the same size | `F` flips the axis. `=` makes sibling panes the same size                                                   |
| Join tile            | `J` then an arrow | The window joins the neighbor in that direction                  |


#### Slots


| Verb + noun       | Key                                 | Operating system                                                                                                                                                                                            | App                                                    |
| ----------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| Switch slot       | `;` previous, `'` next              | The previous or next workspace on this monitor, wrapping around                                                                                                                                             | The previous or next tab                               |
| Jump to slot      | `1`–`9`; in apps `9` is last        | Workspace 1 through 9, creating it if needed                                                                                                                                                                | Tab 1 through 8. `9` is the last tab                   |
| Send tile to slot | Shift+`;`, Shift+`'`, Shift+`1`–`9` | Move the window to that workspace and follow it. The step follows the same sequence as Switch. The number creates the workspace if needed                                                                    | Move the tab one step, to that position, or to the end |


#### Other


| Verb + noun   | Key                   | Operating system                                                                                                                           | App                                         |
| ------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| Walk history  | `[` back, `]` forward | —                                                                                                                                          | Back and forward in that app                |
| Run command   | `P`                   | Open the command launcher                                                                                                                  | Open the command palette                    |
| Open document | `O`                   | Open the document switcher                                                                                                                 | Open the switcher for documents in this app |
| Focus monitor        | Tab               | Focus the next monitor. With two monitors, that is the other one |
| Send slot to monitor | Shift+Tab         | Move the current workspace to the next monitor                   |


### Overlay Window

An overlay window showing possible layer bindings is shown after a short delay when a layer key is held or locked. It disappears once a binding is selected. 

When another key is expected in a sequence, a similar overlay window is shown after a delay with possible follow up keys. 

## Implementation

Karabiner translates two keys. Keyagent dispatches the grammar, draws the overlay, and runs the commands. The window manager is AeroSpace, left in `main` with an empty `[mode.main.binding]` table. skhd is not used.

### Karabiner


| From      | Held                       | Alone         | Timeout |
| --------- | -------------------------- | ------------- | ------- |
| Caps Lock | F18, via `to` | Escape        | 250 ms  |
| Fn        | F19, via `to` | the globe key | 250 ms  |


F18 and F19 are the interface between the two tools. Each goes down with the physical key and stays down until Caps Lock or Fn is released. A release within the timeout is a tap: Karabiner posts that key-up, then Escape or the globe key. The brief F18 or F19 press is a no-op. Leave key repeat enabled. With `repeat` set to `false`, Karabiner posts the key-up at the same time as the key-down, and the layer disarms before the next key. The globe key is the native Fn tap, so macOS changes the input source. Karabiner consumes Fn while it is held, so Fn+arrow never becomes Home, End, or Page Up/Down.

### Keyagent

`configs/keyagent/bindings.ron` holds the grammar as rows: key, Shift, verb or chord, and the overlay line. `configs/keyagent/targets.ron` says what each verb does on the operating system and in each app. The agent loads both at start and again when either file changes, so a binding edit does not rebuild it. `keyagent/` is the tap and the layer state.

One modifying session event tap watches key down and key up.

- F18 down arms the operating-system layer. F19 down arms the App layer. Key repeat is ignored, and both keys are swallowed. Key up disarms a layer that is not locked.
- Space, while a layer is armed and no chord is pending, locks that layer. The layer key can come up and the layer stays armed. Escape, with no chord pending, clears the lock.
- While a layer is armed, every other key is swallowed. A listed key runs its verb. Shift is read off the event flags. Command combinations are swallowed with the rest.
- F19+Delete is posted as forward delete. F19+F1 through F12 are unbound, so the Fn-flipped F row is not available.
- A layer that is held or locked shows its overlay after 250 ms. The overlay hides once a binding is selected, and on key up when the layer is not locked. While the layer stays locked, the 250 ms timer starts again after the binding. The overlay is a non-activating panel on the focused screen. Nothing goes to Notification Center.
- `\`, `S`, and `L` on the App layer, and `S`, `L`, and `J` on the operating-system layer, start a chord. The layer overlay hides and a follow-up overlay lists the keys that chord accepts. Split, join, and resize accept an arrow. Layout accepts `F` and `=` on the App layer, and `F`, `A`, and `=` on the operating-system layer.
- While a chord is waiting, the tap keeps swallowing keys after the layer key comes up. A lock stays in force. The pending verb wins over the layer, so an arrow with Caps Lock still down is the argument. F18 and F19 are not arguments. One argument clears the verb. Escape and any unlisted key clear the chord and leave a lock in place. Key repeat is swallowed, including inside a chord.

AeroSpace commands run on a worker queue, one at a time in key order, so the tap never waits on AeroSpace.

Posted shortcuts re-enter the tap. Keyagent stamps them with `kCGEventSourceUserData` `0x4B424C31` and ignores them on the way back. A two-stroke shortcut is two marked keystrokes.

With Keyagent not running, or in a password field, a Caps Lock tap still sends Escape, a Fn tap still changes the input source, and typed characters are unchanged. The lock and Fn+Delete stop, because those need the tap.

### Operating system

Each operating-system key runs `aerospace`.


| Verb                 | Command                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------ |
| Focus tile           | `focus --boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors <dir>` |
| Move tile            | `move --boundaries all-monitors-outer-frame --boundaries-action create-implicit-container <dir>` |
| Zoom tile            | `fullscreen`                                                                                     |
| Switch slot          | `workspace --no-stdin --wrap-around prev` / `next`                                               |
| Jump to slot         | `workspace 1` … `workspace 9`                                                                    |
| Send tile to slot    | `move-node-to-workspace --no-stdin --focus-follows-window --wrap-around prev` / `next`, or `N`   |
| Focus monitor        | `focus-monitor --wrap-around next`                                                               |
| Send slot to monitor | `move-workspace-to-monitor --wrap-around next`                                                   |
| Close tile           | `close`                                                                                          |
| Join tile            | `join-with <dir>`                                                                                |
| Resize tile          | `resize width -100` / `+100` on left / right, `resize height +100` / `-100` on down / up         |
| Layout flip          | `layout horizontal vertical`                                                                     |
| Layout accordion     | `layout tiles accordion`                                                                         |
| Layout equalize      | `balance-sizes`                                                                                  |
| Run command          | `open -g -b com.raycast.macos`, which shows Raycast's search bar                                 |
| Open document        | Hyper+`O`, Contexts' hotkey, sent through System Events                                          |


`layout horizontal vertical` picks the first argument that is not the current layout, so the axis flips and tiled-versus-accordion stays. `layout tiles accordion` toggles the other way and keeps the axis. `balance-sizes` equalizes every window in the current workspace, including windows nested by Join.

When the direction has no neighbor inside the workspace, `create-implicit-container` builds the new split. When that move meets the edge of the screen and a monitor lies that way, the window moves to that monitor.

`focus` with `wrap-around-all-monitors` crosses to the window on the next monitor, and from the outer edge continues onto the monitor at the opposite side.

`fullscreen` fills the workspace. Focusing another tiling window there exits fullscreen and restores the others.

Switch and Send-by-step step through `list-workspaces --monitor focused`. AeroSpace drops a workspace once it is empty and not visible, except for workspaces named in `aerospace.toml`, which stay in the list even when empty. With the empty `[mode.main.binding]` table, the sequence is the workspaces that have windows plus the one you are on.

Cross-monitor Focus and Move require "Displays have separate Spaces" off.

### App integration

Keyagent names the frontmost app and delivers that app's own shortcut, or selects a menu item when the action has no shortcut. The apps keep the bindings they already have. The translation lives in Keyagent.

An app with no row below ignores the App layer.

Walk history in iTerm posts Option+J and Option+K, which fish binds to `prevd` and `nextd`. iTerm's Option keys send Esc+, so fish sees `\ej` and `\ek`.

## Per-app delivery

A cell is the shortcut Keyagent posts. A `menu` cell is the item it selects. A dash means the app has neither.

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

- **Displays have separate Spaces.** Off. System Settings > Desktop & Dock. Cross-monitor Focus and Move depend on it.
- **Globe key.** System Settings > Keyboard > "Press 🌐 key to": Change Input Source. Karabiner posts the globe key on a Fn tap, and this is the language change.
- **VoiceOver.** Not a concern. Control+Option is not used.

