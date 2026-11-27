#!/usr/bin/env bash
# Idempotent bootstrap for isolated Linux dev VMs (OrbStack and Fly.io Sprites).
# Clones ~/dotfiles over read-only HTTPS, installs single-user Nix if missing,
# and applies homeConfigurations#dev-vm-<arch>.
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/denniskempin/dotfiles.git}"
DOTFILES_DIR="${HOME}/dotfiles"

# Ensure base primitives exist on minimal Ubuntu/Debian images.
missing_pkgs=()
command -v curl >/dev/null 2>&1 || missing_pkgs+=(curl)
command -v git >/dev/null 2>&1 || missing_pkgs+=(git)
command -v xz >/dev/null 2>&1 || missing_pkgs+=(xz-utils)
if [ "${#missing_pkgs[@]}" -gt 0 ] && command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends ca-certificates "${missing_pkgs[@]}"
fi

# Always keep ~/dotfiles pointed at read-only HTTPS inside dev VMs.
if [ ! -d "${DOTFILES_DIR}/.git" ]; then
  git clone "${DOTFILES_REPO}" "${DOTFILES_DIR}"
else
  git -C "${DOTFILES_DIR}" remote set-url origin "${DOTFILES_REPO}"
  git -C "${DOTFILES_DIR}" pull --ff-only
fi

if ! command -v nix >/dev/null 2>&1; then
  for profile in \
    "${HOME}/.nix-profile/etc/profile.d/nix.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; do
    if [ -r "${profile}" ]; then
      # shellcheck disable=SC1090
      . "${profile}"
      break
    fi
  done
fi

if ! command -v nix >/dev/null 2>&1; then
  curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --yes
  # shellcheck disable=SC1091
  . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
fi

mkdir -p "${HOME}/.config/nix"
cat > "${HOME}/.config/nix/nix.conf" <<'EOF'
experimental-features = nix-command flakes
substituters = https://cache.nixos.org
EOF

case "$(uname -m)" in
  x86_64)
    target="dev-vm-x86_64"
    ;;
  aarch64 | arm64)
    target="dev-vm-aarch64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

nix --extra-experimental-features 'nix-command flakes' \
  run home-manager -- switch --impure -b backup --flake "${DOTFILES_DIR}#${target}"

export PATH="${HOME}/.nix-profile/bin:${PATH}"

if command -v rustup >/dev/null 2>&1; then
  if ! rustup show active-toolchain >/dev/null 2>&1; then
    rustup toolchain install stable --profile default
  fi
fi

echo "Bootstrapped ${target} cleanly."
