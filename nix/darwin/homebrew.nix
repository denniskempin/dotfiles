# Desired Homebrew state. Activation is intentionally not idempotent with the
# live prefix until the drift list at the bottom is resolved: onActivation.cleanup
# is "check", so a future darwin-rebuild will refuse to finish while extras remain.
# upgrade and autoUpdate stay off so a rebuild does not float versions.
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "check";
    };

    # Shared CLI tools come from nixpkgs in nix/home/default.nix. These stay here:
    # fish is the login shell, and nixpkgs dropped thefuck in May 2025.
    brews = [
      "fish"
      "fisher"
      "thefuck"
    ];

    casks = [
      # Tiling WM. Lives in nikitabobko/tap, which brew will not load until trusted.
      "nikitabobko/tap/aerospace"

      # CLI casks
      "1password/tap/1password-cli"

      # GUI apps that are actually on disk
      "1password"
      "contexts"
      "cursor"
      "docker-desktop"
      "gemini"
      "google-chrome"
      "iterm2"
      "karabiner-elements"
      "kicad"
      "linear"
      "marta"
      "nordvpn"
      "obsidian"
      "prusaslicer"
      "raspberry-pi-imager"
      "raycast"
      "signal"
      "the-unarchiver"
      "todoist-app"
      "topnotch"
      "visual-studio-code"
      "yoink"

      # Fonts. homebrew/cask-fonts is a legacy tap and is not declared.
      "font-monaspice-nerd-font"
    ];

    # Receipts from pkgutil on 6 Oct 2026. Ids are the long-standing App Store ids.
    masApps = {
    };
  };
}
