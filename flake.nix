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
    aerospace-tap = {
      url = "github:nikitabobko/homebrew-tap";
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
      # A Mac is nix/hosts/<hostname>.nix plus one line below.
      mkDarwin =
        hostname:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./nix/darwin
            ./nix/hosts/${hostname}.nix
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
          ];
        };

      # Non-NixOS Linux. Apply with `home-manager switch --flake ~/dotfiles#<name>`.
      # Standalone home-manager does not write nix.conf, so the first switch is
      #   nix --extra-experimental-features 'nix-command flakes' \
      #     run home-manager -- switch --flake ~/dotfiles#<name>
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
            ./nix/home
            ./nix/home/linux.nix
            { home = { inherit username homeDirectory; }; }
          ];
        };
    in
    {
      darwinConfigurations = {
        "Denniss-MacBook-Pro" = mkDarwin "Denniss-MacBook-Pro";
      };

      # home-manager looks up "$USER@$(hostname)" first, then "$USER", so the
      # plain entry covers any x86_64 machine with this home directory.
      homeConfigurations = {
        "denniskempin" = mkHome {
          system = "x86_64-linux";
          homeDirectory = "/usr/local/google/home/denniskempin";
        };
      };

      formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );
    };
}
