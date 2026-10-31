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

    # "Displays have separate Spaces" on. OmniWM will not manage windows
    # without it. Changing it takes a logout.
    spaces.spans-displays = false;

    trackpad.Clicking = false;
  };

  # Login items have no nix-darwin option. Recorded so a later reconcile can
  # see them: Contexts, Hammerspoon, TopNotch, Raycast, Gemini, Todoist, and
  # OmniWM (its Start at Login switch, which settings.toml does not hold).
  #
  # ~/Library/LaunchAgents/com.google.GoogleUpdater.wake.plist belongs to
  # Chrome, which rewrites it on update.
}
