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
  # see them. Present and wanted: Contexts, TopNotch, Raycast, Gemini, Todoist.
  # Present and stale (app path missing): Notion, Warp, Notion Calendar.
  #
  # ~/Library/LaunchAgents/homebrew.mxcl.borders.plist points at a borders
  # binary that is not installed. It is not redeclared here.
}
