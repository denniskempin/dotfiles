# Home configuration for main systems (macOS and Linux workstations).
{ pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./links.nix
  ];

  home.packages = with pkgs; [
    # Rust toolchain and helpers for sres development.
    cargo-nextest
    rustup
    sccache
    trunk
  ];
}
