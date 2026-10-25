# Personal dotfiles

Configuration for macOS and Linux machines.

## Layout

- `configs/` has one directory per app, holding its config files under the
  names the app expects. Nothing in it depends on Nix.
  [configs/README.md](configs/README.md) lists where each one goes.
- `nix/` installs packages and links `configs/` into place:
  - `nix/home/` is home-manager config. `links.nix` holds every link,
    `default.nix` the CLI packages shared by all machines, and `darwin.nix`
    and `linux.nix` the platform extras.
  - `nix/darwin/` is nix-darwin config shared by every Mac: Homebrew, system
    defaults, and the user account.
  - `nix/hosts/` has one file per Mac with its hostname and state version.
- `docs/` has the keybinding spec that covers Karabiner, Keyagent,
  AeroSpace, and app shortcuts.

Every machine keeps this checkout at `~/dotfiles`. Run `git add` on new `.nix`
files first, because flakes only see files git tracks.

## Setup

macOS: add `nix/hosts/<hostname>.nix` and a matching line in `flake.nix`,
then run `darwin-rebuild switch --flake ~/dotfiles`.

Linux: install Nix with flakes enabled, then run
`nix run home-manager -- switch --flake ~/dotfiles`. Later switches can use
`home-manager switch --flake ~/dotfiles`. For a different user, home
directory, or architecture, add a `mkHome` entry in `flake.nix`. To install
the fish plugins, run
`fish -c "curl -sL https://git.io/fisher | source && fisher update"` once.

Without Nix: symlink the directories as listed in
[configs/README.md](configs/README.md) and install the apps yourself.

## Key bindings

See [docs/keybindings.md](docs/keybindings.md).
