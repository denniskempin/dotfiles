# macOS-only home configuration. File links for every platform are in links.nix.
{ config, pkgs, ... }:
let
  # Sparkle reads these from the app's defaults domain. Checks and silent
  # installs both stay off.
  sparkleOff = {
    SUEnableAutomaticChecks = false;
    SUAutomaticallyUpdate = false;
  };
in
{
  # The 1Password CLI comes from programs._1password in nix/darwin.
  home.packages = with pkgs; [
    nerd-fonts.monaspace
  ];

  # iTerm writes its plist itself. Point it at the repo copy instead of
  # copying the plist into the Nix store. The Sparkle keys stay here too,
  # because Sparkle reads the defaults domain rather than that plist.
  targets.darwin.defaults = {
    "com.contextsformac.Contexts" = sparkleOff;
    "com.googlecode.iterm2" = sparkleOff // {
      PrefsCustomFolder = "${config.home.homeDirectory}/dotfiles/configs/iterm2";
      LoadPrefsFromCustomFolder = true;
    };
    "org.hammerspoon.Hammerspoon" = sparkleOff;
    "org.pqrs.Karabiner-Elements.Settings" = sparkleOff;
    "org.yanex.marta" = sparkleOff;
    "pl.maketheweb.TopNotch" = sparkleOff;
  };
}
