# CLI dev utilities shared across main systems and devcontainers.
{ pkgs, ... }:
{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    bat
    bottom
    delta
    direnv
    eza
    fd
    fzf
    gh
    git
    grc
    helix
    jq
    jujutsu
    less
    neovim
    procs
    ripgrep
    rsync
    starship
    tldr
    wget
    zoxide
  ];
}
