# Home configuration for devcontainers: CLI dev utilities and CLI configs only.
{ ... }:
{
  imports = [
    ./cli.nix
    ./linux.nix
    ./links-cli.nix
  ];
}
