# macOS-only home configuration. Shared files and packages are in home/.
{
  config,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  link = rel: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${rel}";
in
{
  home.file = {
    ".aerospace.toml".source = link "aerospace.toml";
    ".hammerspoon".source = link "keybindings/hammerspoon";
    ".skhdrc".source = link "skhdrc";

    "Library/Application Support/Code/User/settings.json".source = link "vscode/settings.json";
    "Library/Application Support/Code/User/keybindings.json".source = link "vscode/keybindings.json";
  };

  xdg.configFile = {
    # Adopted from ~/.config on 6 Oct 2026. Not previously in git.
    "karabiner/karabiner.json".source = link "keybindings/karabiner.json";
  };

  # iTerm writes this plist itself. Point it at the repo copy instead of
  # copying the plist into the Nix store.
  targets.darwin.defaults."com.googlecode.iterm2" = {
    PrefsCustomFolder = "${dotfiles}/iterm2";
    LoadPrefsFromCustomFolder = true;
  };
}
