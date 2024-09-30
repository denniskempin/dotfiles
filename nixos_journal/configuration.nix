{ config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz";
in
{
  imports =
    [
      ./hardware-configuration.nix
      (import "${home-manager}/nixos")
    ];

  ################################################################################
  # Basic system configuration
  ################################################################################
  system.stateVersion = "24.05";
  nixpkgs.config.allowUnfree = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;
  networking.hostName = "aurelius";

  # Locale
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # SSH with key auth only
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Power Management
  powerManagement.enable = true;
  services.tlp.enable = true;

  # Allows home manager to overwrite files
  home-manager.backupFileExtension = "backup";

  # Globally installed packages
  environment.systemPackages = with pkgs; [
    vim
    obsidian
    kitty
  ];

  ################################################################################
  # Samsung Galaxy Chromebook specific configuration
  ################################################################################

  # Prevent noisy touchpad from waking the system
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="i2c", DRIVER=="i2c_hid_acpi", ATTR{power/wakeup}="disabled"
  '';

  ################################################################################
  # UI
  ################################################################################

  # Enable GDM for login-screen
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;

  # Enable Hyprland for user session
  programs.hyprland.enable = true;

  # Electron apps use this variable to prefer Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  ################################################################################
  # Configure user account
  ################################################################################
  users.users.dennis = {
    isNormalUser = true;
    description = "Dennis";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDVPb79dGEzbk2v5A2v3TXNPKOn8QHT0f9+rS/urD+AAaGWwQrfrA7n0o81OZz0HUICQPNLuN6yaRob51l6eXNlJ5WL8pbV2XYz+Rc8oqEiopDtR/c9O9gbEl6MrxUGLe5BlhS/7skYo7IwL/1BEl3C6auWw6+RjJMNBWCB4WlLEcFlcc3F/042OX8mADxbCTKZpGtalrypibx47q5DDYhuIVmYS+GdfUp9MNEbNeogwdWzvXJPsATjDxBBIoa9F9eFFoK/iD4USECiSskDTVQ1ky/1nkU3Mw41RrJ7cFWvSg71H68nbZW5pt8jMj1gskrz+st85MpOPbJsHZRQbn5vtYlDgCxsn4LrJCzdMn6+yH2X9PrWRAZmYusAyeeHpS99jC3KOWepSAewAu3nxUdWjCH1m9norYDzhIgZe2iBGoEH1VwYAHp+Kl6syTj9DTRmF4JxgvLYVPFHp3644CB07lp+ngOLnWwzP1OhoqaSmt/vNjLVKqe0WBuUoHG/Sh8= denniskempin@macbook-pro.lan"
    ];
  };

  # Setup user configuration files via home-manager.
  home-manager.users.dennis = {
    # Keep in sync with system.stateVersion
    home.stateVersion = "24.05";

    # Use home-manager module to setup hyprland config.
    wayland.windowManager.hyprland = {
      enable = true;
      # Don't configure systemd. We start hyrpland via GDM.
      systemd.enable = false;
      settings = {
        "$mod" = "SUPER";
        # Auto-start obsidian
        exec-once = [
          "obsidian"
        ];
        bind =
          [
            "$mod, O, exec, obsidian"
          ];
      };
    };
  };
}
