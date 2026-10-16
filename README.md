# Personal dotfiles

Contains configuration for iterm2 and vscode on OSX, as well as fish shell configuration.

## Layout

- `home/` is home-manager config shared by every machine: CLI packages and
  dotfile links for fish, git, helix, and nvim.
- `darwin/` is nix-darwin config shared by every Mac. Each Mac also has a
  `darwin/hosts/<hostname>.nix` with its hostname and state version.
- `linux/` is the extra home-manager config for non-NixOS Linux.

Every machine keeps this checkout at `~/dotfiles`. Run `git add` on new `.nix`
files first, because flakes only see files git tracks.

## Setup

macOS: add `darwin/hosts/<hostname>.nix` and a matching line in `flake.nix`,
then run `darwin-rebuild switch --flake ~/dotfiles`.

Linux: install Nix with flakes enabled, then run
`nix run home-manager -- switch --flake ~/dotfiles`. Later switches can use
`home-manager switch --flake ~/dotfiles`. For a different user, home
directory, or architecture, add a `mkHome` entry in `flake.nix`. To install
the fish plugins, run
`fish -c "curl -sL https://git.io/fisher | source && fisher update"` once.

## Key bindings

See [keybindings.md](keybindings.md).
