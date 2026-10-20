# macOS-only home configuration. File links for every platform are in links.nix.
{ config, ... }:
{
  # iTerm writes this plist itself. Point it at the repo copy instead of
  # copying the plist into the Nix store.
  targets.darwin.defaults."com.googlecode.iterm2" = {
    PrefsCustomFolder = "${config.home.homeDirectory}/dotfiles/configs/iterm2";
    LoadPrefsFromCustomFolder = true;
  };
}
