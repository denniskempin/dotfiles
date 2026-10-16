# Standalone home-manager on a non-NixOS distro.
{ pkgs, ... }:
{
  # macOS gets fish from Homebrew. Here the distro's login shell runs
  # ~/.bashrc, which execs this fish for interactive sessions.
  home.packages = [ pkgs.fish ];

  targets.genericLinux.enable = true;
  programs.home-manager.enable = true;
}
