{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # First nix-darwin generation for this machine. Do not bump this to chase
  # upstream; it freezes defaults that would otherwise migrate under us.
  system.stateVersion = 7;

  networking.computerName = "Dennis’s MacBook Pro";
  networking.hostName = "Denniss-MacBook-Pro";
  networking.localHostName = "Denniss-MacBook-Pro";
}
