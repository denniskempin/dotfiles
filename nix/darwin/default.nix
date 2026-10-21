# Shared by every Mac. Per-machine settings live in hosts/<hostname>.nix.
{
  inputs,
  config,
  pkgs,
  ...
}:
let
  user = config.system.primaryUser;

  # Taps beyond homebrew/core and homebrew/cask that brew refuses to load until
  # trusted. Keys are nix-homebrew tap names.
  trustedTaps = [ "nikitabobko/homebrew-tap" ];
in
{
  imports = [
    ./defaults.nix
    ./homebrew.nix
  ];

  nixpkgs.config.allowUnfree = true;

  system.primaryUser = "denniskempin";
  time.timeZone = "America/Los_Angeles";

  # nix-darwin only manages users listed in users.knownUsers, and the admin
  # user should not be one. Only `home` is read here, by home-manager. The
  # login shell is Homebrew fish, set once by hand on a new Mac:
  #   chsh -s /opt/homebrew/bin/fish
  # programs.fish stays off so nix-darwin does not install a second fish.
  users.users.${user}.home = "/Users/${user}";
  environment.shells = [ "/opt/homebrew/bin/fish" ];

  # Written to /etc/pam.d/sudo_local, which survives macOS updates.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Installs op at /usr/local/bin/op, the only path the 1Password app's CLI
  # integration accepts.
  programs._1password.enable = true;

  # Matches the Nix the installer put in /nix/var/nix/profiles/default.
  nix.package = pkgs.nixVersions.latest;
  # Flakes only. Disabling this does not delete root's existing channels.
  nix.channel.enable = false;

  # nix-darwin already adds cache.nixos.org. The devenv cache came from the
  # Nov 2022 ~/.config/nix/nix.conf.
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [ "https://devenv.cachix.org" ];
    trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };
  # Scheduled instead of auto-optimise-store, which nix-darwin rejects on macOS.
  nix.optimise.automatic = true;

  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    inherit user;
    autoMigrate = true;
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "nikitabobko/homebrew-tap" = inputs.aerospace-tap;
    };
    trust.taps = trustedTaps;
  };

  # brew bundle cleanup rewrites the trust store from these flags, so they
  # must agree with nix-homebrew.trust.taps.
  homebrew.taps = map (name: {
    inherit name;
    trusted = builtins.elem name trustedTaps;
  }) (builtins.attrNames config.nix-homebrew.taps);

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    # Replace an old .backup instead of failing on a second collision.
    overwriteBackup = true;
    users.${user}.imports = [
      ../home
      ../home/darwin.nix
    ];
  };
}
