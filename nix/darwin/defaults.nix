# Only keys that were actually set on this Mac on 6 Oct 2026.
# Unset keys stay unset. 557 preference domains exist; this is the allowlist.
{
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      NSAutomaticSpellingCorrectionEnabled = true;
    };

    dock = {
      autohide = true;
      tilesize = 48;
      # Spaces stay in creation order.
      mru-spaces = false;
    };

    finder = {
      FXPreferredViewStyle = "Nlsv";
      ShowStatusBar = false;
    };

    trackpad.Clicking = false;
  };

  # Login items have no nix-darwin option. Recorded so a later reconcile can
  # see them: Contexts, Keyagent, TopNotch, Raycast, Gemini, Todoist.
  #
  # ~/Library/LaunchAgents/com.google.GoogleUpdater.wake.plist belongs to
  # Chrome, which rewrites it on update.
}
