# Home configuration shared by every machine, macOS and Linux.
{ pkgs, ... }:
{
  imports = [ ./links.nix ];

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    bat
    bottom
    delta
    direnv
    eza
    fd
    fzf
    grc
    helix
    jq
    less
    procs
    ripgrep
    rsync
    starship
    tldr
    wget
    zoxide
  ];
}
