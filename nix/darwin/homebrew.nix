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
      # One switch only: drops 1password/tap and homebrew/services.
      cleanup = "none";
    };

    # Shared CLI tools come from nixpkgs in nix/home/default.nix. These stay here:
    # fish is the login shell, and nixpkgs dropped thefuck in May 2025.
    # fisher manages itself as a fish plugin (configs/fish/fish_plugins).
    brews = [
      "fish"
      "thefuck"
    ];

    casks = [
      # Tiling WM. Lives in nikitabobko/tap, which brew will not load until trusted.
      "nikitabobko/tap/aerospace"

      # GUI apps that are actually on disk
      "1password"
      "contexts"
      "cursor"
      "docker-desktop"
      "google-chrome"
      "google-gemini"
      "iterm2"
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
