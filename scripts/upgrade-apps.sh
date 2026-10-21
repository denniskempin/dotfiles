#!/usr/bin/env bash
# Move Homebrew formulae, casks, and Mac App Store apps to the newest versions.
#
# A rebuild will not do this. homebrew.onActivation.upgrade stays false, and
# the cask list records names only. The version a cask would install lives in
# the tap, and nix-homebrew pins those taps to flake.lock. Updating the pins
# and relinking them has to happen before Homebrew will see a newer version.
# Packages installed from nixpkgs are left on their current pin.
set -euo pipefail

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:${PATH}"

repo="${DOTFILES:-${HOME}/dotfiles}"
cd "${repo}"

echo "Updating Homebrew tap pins..."
nix flake update homebrew-core homebrew-cask aerospace-tap

echo "Relinking taps..."
sudo darwin-rebuild switch --flake "${repo}"

echo "Upgrading formulae and casks..."
# --greedy includes casks that update themselves. brew upgrade skips those,
# and it quits a running app so the new copy can replace it.
brew upgrade --greedy

echo "Upgrading Mac App Store apps..."
if command -v mas >/dev/null 2>&1; then
  mas upgrade
else
  nix shell nixpkgs#mas -c mas upgrade
fi

echo "Tap pins in flake.lock changed. Review the diff and commit it when you want this machine to keep these versions."
