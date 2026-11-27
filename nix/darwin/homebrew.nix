# Desired Homebrew state. onActivation.cleanup is "check", so darwin-rebuild
# refuses to finish while undeclared formulae, casks or taps remain.
# upgrade and autoUpdate stay off so a rebuild does not float versions.
# scripts/upgrade-apps.sh moves formulae, casks, and Mac App Store apps.
#
# Removing a tap takes two switches. The check runs before nix-homebrew
# relinks Library/Taps, so it still sees the old tap. Switch once with
# cleanup = "none", then put "check" back.
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "check";
    };

    # Shared CLI tools come from nixpkgs in nix/home/default.nix. fish stays
    # here as the login shell.
    brews = [
      "fish"
    ];

    casks = [
      # Scrolling tiling WM (niri layout). Driven by Hammerspoon through
      # omniwmctl, which the cask links into /opt/homebrew/bin.
      "omniwm"

      # GUI apps that are actually on disk
      "1password"
      "contexts"
      "google-chrome"
      "ghostty"
      "google-gemini"
      "hammerspoon"
      "karabiner-elements"
      "kicad"
      "linear"
      "marta"
      "obsidian"
      "prusaslicer"
      "raspberry-pi-imager"
      "raycast"
      "signal"
      "todoist-app"
      "topnotch"
      "visual-studio-code"
      "zed"
    ];

    # Apps with an App Store receipt on 19 Oct 2026. mas needs an App Store
    # sign-in before it can install any of these.
    masApps = {
      "1Password for Safari" = 1569813296;
      "Amazon Kindle" = 302584613;
      "HazeOver" = 430798174;
      "NordVPN" = 905953485;
      "Say No to Notch" = 1639306886;
      "The Unarchiver" = 425424353;
      "Vimari" = 1480933944;
      "Wipr 2" = 1662217862;
      "Yoink" = 457622435;
    };
  };
}
