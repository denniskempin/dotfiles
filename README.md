# Personal dotfiles

Configuration for macOS and Linux machines.

## Layout

- `configs/` has one directory per app, holding its config files under the
  names the app expects. Nothing in it depends on Nix.
  [configs/README.md](configs/README.md) lists where each one goes.
- `nix/` installs packages and links `configs/` into place:
  - `nix/home/` is home-manager config:
    - `cli.nix` holds the shared CLI dev utilities and `links-cli.nix` the CLI
      config links.
    - `default.nix` and `links.nix` add the main-system configs (GUI apps,
      editors, git signing), with `darwin.nix` and `linux.nix` for platform
      extras.
    - `devcontainer.nix` combines `cli.nix`, `linux.nix`, and `links-cli.nix`
      for devcontainers.
  - `nix/darwin/` is nix-darwin config shared by every Mac: Homebrew, system
    defaults, and the user account.
  - `nix/hosts/` has one file per Mac with its hostname and state version.
- `docs/` has the keybinding spec that covers Karabiner, Hammerspoon,
  OmniWM, and app shortcuts.

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

Devcontainers: point the devcontainers `dotfiles` feature at this repo. It
will automatically run [`install.sh`](install.sh), which bootstraps single-user
Nix and applies `devcontainer-x86_64` or `devcontainer-aarch64`.

## Key bindings

See [docs/keybindings.md](docs/keybindings.md).
