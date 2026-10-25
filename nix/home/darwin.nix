# macOS-only home configuration. File links for every platform are in links.nix.
{ config, pkgs, ... }:
let
  # Sparkle reads these from the app's defaults domain. Checks and silent
  # installs both stay off.
  sparkleOff = {
    SUEnableAutomaticChecks = false;
    SUAutomaticallyUpdate = false;
  };
  keyagent = pkgs.callPackage ../packages/keyagent.nix { };
in
{
  # The 1Password CLI comes from programs._1password in nix/darwin.
  home.packages = [
    pkgs.nerd-fonts.monaspace
    keyagent
  ];

  # User agent, so the session event tap runs in the Aqua session. The
  # executable is the one inside the bundle: a raw binary gets a new cdhash
  # on every build and macOS drops the Accessibility grant.
  launchd.agents."com.denniskempin.keyagent" = {
    enable = true;
    config = {
      Label = "com.denniskempin.keyagent";
      ProgramArguments = [
        "${keyagent}/Applications/Keyagent.app/Contents/MacOS/keyagent"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/keyagent.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/keyagent.log";
    };
  };

  # iTerm writes its plist itself. Point it at the repo copy instead of
  # copying the plist into the Nix store. The Sparkle keys stay here too,
  # because Sparkle reads the defaults domain rather than that plist.
  targets.darwin.defaults = {
    "com.contextsformac.Contexts" = sparkleOff;
    "com.googlecode.iterm2" = sparkleOff // {
      PrefsCustomFolder = "${config.home.homeDirectory}/dotfiles/configs/iterm2";
      LoadPrefsFromCustomFolder = true;
    };
    "org.pqrs.Karabiner-Elements.Settings" = sparkleOff;
    "org.yanex.marta" = sparkleOff;
    "pl.maketheweb.TopNotch" = sparkleOff;
  };
}
