# Shared by every Mac. Per-machine settings live in hosts/<hostname>.nix.
{
  inputs,
  config,
  ...
}:
{
  imports = [
    ./defaults.nix
    ./homebrew.nix
  ];

  nixpkgs.config.allowUnfree = true;

  system.primaryUser = "denniskempin";
  time.timeZone = "America/Los_Angeles";

  users.users.denniskempin = {
    gid = 20;
    description = "Dennis Kempin";
    home = "/Users/denniskempin";
    isHidden = false;
    # Homebrew fish, matching UserShell today. programs.fish stays off so
    # nix-darwin does not install a second fish from nixpkgs.
    shell = "/opt/homebrew/bin/fish";
    ignoreShellProgramCheck = true;
  };
  environment.shells = [ "/opt/homebrew/bin/fish" ];

  # Adopted from ~/.config/nix/nix.conf (devenv cache, Nov 2022) plus flakes.
  nix.settings = {
    experimental-features = "nix-command flakes";
    substituters = "https://cache.nixos.org https://devenv.cachix.org";
    trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
  };

  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    user = "denniskempin";
    autoMigrate = true;
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-services" = inputs.homebrew-services;
      "nikitabobko/homebrew-tap" = inputs.aerospace-tap;
      "1password/homebrew-tap" = inputs.onepassword-tap;
    };
    # brew currently refuses these taps until they are trusted.
    trust.taps = [
      "nikitabobko/tap"
      "1password/tap"
    ];
  };

  homebrew.taps = builtins.attrNames config.nix-homebrew.taps;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.denniskempin.imports = [
      ../home
      ../home/darwin.nix
    ];
  };
}
