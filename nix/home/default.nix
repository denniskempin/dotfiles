# Home configuration for main systems (thin-client macOS host and workstations).
# Language toolchains and build helpers live in dev-vm.nix.
{ ... }:
{
  imports = [
    ./cli.nix
    ./links.nix
  ];
}
