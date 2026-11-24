#!/usr/bin/env bash
# Bootstrap Nix and apply the devcontainer home-manager configuration.
# Automatically detected by the devcontainers dotfiles feature.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# nix/home/links-cli.nix expects the checkout at ~/dotfiles.
if [ "${SCRIPT_DIR}" != "${HOME}/dotfiles" ] && [ ! -e "${HOME}/dotfiles" ]; then
  ln -s "${SCRIPT_DIR}" "${HOME}/dotfiles"
fi

# Pick up an existing Nix installation if this is a non-login shell.
if ! command -v nix >/dev/null 2>&1; then
  for profile in \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
    "${HOME}/.nix-profile/etc/profile.d/nix.sh"; do
    if [ -r "${profile}" ]; then
      # shellcheck disable=SC1090
      . "${profile}"
      break
    fi
  done
fi

# Single-user Nix avoids requiring systemd inside containers.
if ! command -v nix >/dev/null 2>&1; then
  curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --yes
  # shellcheck disable=SC1091
  . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
fi

mkdir -p "${HOME}/.config/nix"
if ! grep -q "experimental-features" "${HOME}/.config/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "${HOME}/.config/nix/nix.conf"
fi

case "$(uname -m)" in
  x86_64)
    target="devcontainer-x86_64"
    ;;
  aarch64 | arm64)
    target="devcontainer-aarch64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

nix --extra-experimental-features 'nix-command flakes' \
  run home-manager -- switch --impure -b backup --flake "${SCRIPT_DIR}#${target}"
