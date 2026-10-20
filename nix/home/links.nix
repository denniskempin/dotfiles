# Links each directory under configs/ to where its app reads it. Keep
# configs/README.md in step: it lists the same destinations for installing
# without Nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Every machine keeps the checkout at ~/dotfiles. Out-of-store links keep
  # edits live without a rebuild.
  configs = "${config.home.homeDirectory}/dotfiles/configs";
  link = rel: config.lib.file.mkOutOfStoreSymlink "${configs}/${rel}";

  # Where Electron apps like Cursor and VS Code keep per-user settings.
  appConfig = if pkgs.stdenv.isDarwin then "Library/Application Support" else ".config";
in
{
  home.file = {
    ".bashrc".source = link "bash/bashrc";
    ".zshrc".source = link "bash/bashrc";
    "${appConfig}/Cursor/User/settings.json".source = link "cursor/settings.json";
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    ".hammerspoon".source = link "hammerspoon";
    "${appConfig}/Code/User/settings.json".source = link "vscode/settings.json";
    "${appConfig}/Code/User/keybindings.json".source = link "vscode/keybindings.json";
  };

  # Apps that write state next to their config (fish, gh, Karabiner) get
  # file links; the rest get the whole directory.
  xdg.configFile = {
    "fish/config.fish".source = link "fish/config.fish";
    "fish/fish_plugins".source = link "fish/fish_plugins";
    "gh/config.yml".source = link "gh/config.yml";
    "git/config".source = link "git/config";
    "helix".source = link "helix";
    "nvim".source = link "nvim";
    "starship.toml".source = link "starship/starship.toml";
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    "aerospace".source = link "aerospace";
    "karabiner/karabiner.json".source = link "karabiner/karabiner.json";
  };
}
