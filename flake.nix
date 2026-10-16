{
  description = "Dotfiles for macOS (nix-darwin) and Linux (standalone home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-services = {
      url = "github:Homebrew/homebrew-services";
      flake = false;
    };
    aerospace-tap = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    skhd-tap = {
      url = "github:asmvik/homebrew-formulae";
      flake = false;
    };
    onepassword-tap = {
      url = "github:1password/homebrew-tap";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      # A Mac is darwin/hosts/<hostname>.nix plus one line below.
      mkDarwin =
        hostname:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./darwin
            ./darwin/hosts/${hostname}.nix
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
          ];
        };

      # Non-NixOS Linux. Apply with `home-manager switch --flake ~/dotfiles#<name>`.
      mkHome =
        {
          system,
          username ? "denniskempin",
          homeDirectory ? "/home/${username}",
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          modules = [
            ./home
            ./linux/home.nix
            { home = { inherit username homeDirectory; }; }
          ];
        };
    in
    {
      darwinConfigurations = {
        "Denniss-MacBook-Pro" = mkDarwin "Denniss-MacBook-Pro";
      };

      # home-manager looks up "$USER@$(hostname)" first, then "$USER", so the
      # plain entry covers any x86_64 machine with a /home/denniskempin home.
      homeConfigurations = {
        "denniskempin" = mkHome { system = "x86_64-linux"; };
      };
    };
}
