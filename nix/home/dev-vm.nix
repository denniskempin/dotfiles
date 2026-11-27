# Home configuration for isolated Linux dev VMs (OrbStack and Fly.io Sprites).
{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./cli.nix
    ./linux.nix
    ./links-cli.nix
  ];

  home.packages = with pkgs; [
    # Rust toolchain and helpers moved off the macOS host.
    cargo-deny
    cargo-nextest
    cargo-vet
    kache
    rustup
    sccache
    trunk

    # Dev VM utilities.
    _1password-cli
    docker-client
    mosh
    nodejs_22
    openssh
    python3
    tmux
  ];

  # Linux-safe git config (avoids macOS op-ssh-sign and includes ~/.config/git/config.local).
  xdg.configFile."git/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/git/config-vm";

  # Shared tmux config with OSC 52 clipboard passthrough for Ghostty over SSH.
  xdg.configFile."tmux/tmux.conf".text = ''
    set -g default-shell "${pkgs.fish}/bin/fish"
    set -g default-terminal "tmux-256color"
    set -as terminal-features ",xterm-256color:RGB,xterm-ghostty:RGB"
    set -g mouse on
    set -s set-clipboard on
    set -g history-limit 50000
    set -g escape-time 10
  '';

  # Block automatic lifecycle scripts (postinstall) across npm/pnpm inside the VM.
  home.file.".npmrc".text = ''
    ignore-scripts=true
  '';
}
