# Links each directory under configs/ to where its app reads it. Keep
# configs/README.md in step: it lists the same destinations for installing
# without Nix. CLI links live in links-cli.nix so devcontainers can reuse them.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  configs = "${config.home.homeDirectory}/dotfiles/configs";
  link = rel: config.lib.file.mkOutOfStoreSymlink "${configs}/${rel}";

  # Where Electron apps like Cursor and VS Code keep per-user settings.
  appConfig = if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".config";
in
{
  imports = [ ./links-cli.nix ];

  home.file = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    ".hammerspoon".source = link "hammerspoon";
    ".ssh/config".source = link "ssh/config";
    "${appConfig}/Code/User/settings.json".source = link "vscode/settings.json";
    "${appConfig}/Code/User/keybindings.json".source = link "vscode/keybindings.json";
  };

  # Apps that write state next to their config (Karabiner, OmniWM) get file
  # links; the rest get the whole directory. git/config stays out of
  # links-cli.nix because it points ssh signing at 1Password on macOS.
  xdg.configFile = {
    "git/config".source = link "git/config";
    "zed/settings.json".source = link "zed/settings.json";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    "1Password/ssh/agent.toml".source = link "1password/agent.toml";
    "direnv/direnv.toml".source = link "direnv/direnv.toml";
    "ghostty".source = link "ghostty";
    "karabiner/karabiner.json".source = link "karabiner/karabiner.json";
    "omniwm/settings.toml".source = link "omniwm/settings.toml";
  };

  # Left as machine state in ~/.config: raycast, jj, kache, and the unlinked
  # git/ignore.
}
