# Keyagent

Layer keybindings for AeroSpace and the front app. Karabiner still turns Caps Lock into F18 and Fn into F19. This process is the tap that used to live in Hammerspoon.

`configs/keyagent/bindings.ron` and `configs/keyagent/targets.ron` are the grammar. The agent reads them at start and again when either file's mtime changes, or on `SIGHUP`. A binding edit does not rebuild the binary and does not disturb the privacy grants. A change to the state machine does need a rebuild.

## Tests

```sh
cargo test --manifest-path keyagent/Cargo.toml
```

That is the offline suite: the layer grammar against a fake host, including a snapshot of every real binding. It runs on Linux. Nothing in it needs Accessibility.

The macOS adapter (`src/macos/`) calls AppKit, CoreGraphics, and the accessibility API. It compiles only on a Mac. A live check is: rebuild, grant the prompts below, hold Caps Lock, and confirm the overlay and one AeroSpace binding.

## Permissions

The binary ships inside `Keyagent.app` (`com.denniskempin.keyagent`, `LSUIElement`) so macOS has a stable bundle id to attach grants to. Launchd starts that executable, not a raw `cargo` binary.

- Accessibility. Prompted at launch. Menu presses need it.
- Input Monitoring, for the modifying event tap. Posting shortcuts needs the same trust (Post Event).
- Automation for System Events. The first Contexts hotkey (`osascript`) asks for it.

An ad-hoc signature changes whenever the binary changes. A nix rebuild changes the store path and the cdhash, and macOS drops the Accessibility grant. Re-enable Keyagent in System Settings → Privacy & Security. The bundle id does not change.

Secure input (a password field) still hides keys from the tap. The agent does not query accessibility from the tap callback.
