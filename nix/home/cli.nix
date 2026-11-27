# CLI dev utilities shared across main systems and devcontainers.
{ lib, pkgs, ... }:
let
  fishPlugins = with pkgs.fishPlugins; [
    # nixpkgs marks fzf-fish broken on Darwin due to checkPhase's `script` wrapper.
    (fzf-fish.overrideAttrs (old: {
      doCheck = false;
      meta = old.meta // {
        broken = false;
      };
    }))
    colored-man-pages
    grc
    plugin-git
    fish-you-should-use
  ];
in
{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    antigravity-cli
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

  # Load Nix-pinned fish plugins without enabling programs.fish (macOS keeps Homebrew fish).
  xdg.configFile."fish/conf.d/10-nix-plugins.fish".text = lib.concatMapStringsSep "\n" (p: ''
    if test -d ${p}/share/fish/vendor_functions.d
      and not contains ${p}/share/fish/vendor_functions.d $fish_function_path
      set -p fish_function_path ${p}/share/fish/vendor_functions.d
    end
    if test -d ${p}/share/fish/vendor_completions.d
      and not contains ${p}/share/fish/vendor_completions.d $fish_complete_path
      set -p fish_complete_path ${p}/share/fish/vendor_completions.d
    end
    if test -d ${p}/share/fish/vendor_conf.d
      for f in ${p}/share/fish/vendor_conf.d/*.fish
        source $f
      end
    end
  '') fishPlugins;
}
