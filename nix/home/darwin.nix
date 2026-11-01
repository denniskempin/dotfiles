# macOS-only home configuration. File links for every platform are in links.nix.
{ pkgs, ... }:
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

  # Ghostty turns Sparkle off in its own config (auto-update = off).
  targets.darwin.defaults = {
    "com.contextsformac.Contexts" = sparkleOff;
    "org.hammerspoon.Hammerspoon" = sparkleOff;
    "org.pqrs.Karabiner-Elements.Settings" = sparkleOff;
    "org.yanex.marta" = sparkleOff;
    "pl.maketheweb.TopNotch" = sparkleOff;
  };
}
