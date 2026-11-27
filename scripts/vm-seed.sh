#!/usr/bin/env bash
# Seed an isolated dev VM with per-VM scoped credentials from the 1Password
# `Dev` vault (never exposing personal vaults or write access to ~/dotfiles).
#
# Usage:
#   ./scripts/vm-seed.sh <local|dev-local|remote|dev-remote> [--clone-repos]
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/vm-seed.sh <local|dev-local|remote|dev-remote> [--clone-repos]

Expected items in your 1Password "Dev" vault (override via env vars):
  GitHub PAT (fine-grained, repo-scoped, excluding dotfiles):
    OP_GH_PAT_LOCAL   (default: "op://Dev/GitHub PAT (dev-local)/token")
    OP_GH_PAT_REMOTE  (default: "op://Dev/GitHub PAT (dev-remote)/token")
  Optional read-only 1Password Service Account for `op run` inside VMs:
    OP_SERVICE_ACCT_REF (default: "op://Dev/Service Account (Dev)/credential")
EOF
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage >&2
  exit 1
fi

target_arg="$1"
clone_repos=false
if [ "${2:-}" = "--clone-repos" ]; then
  clone_repos=true
elif [ -n "${2:-}" ]; then
  usage >&2
  exit 1
fi

case "${target_arg}" in
  local | dev-local)
    vm_name="${ORB_VM_NAME:-dev-local}"
    pat_ref="${OP_GH_PAT_LOCAL:-op://Dev/GitHub PAT (dev-local)/token}"
    exec_cmd=(orb -m "${vm_name}" bash -lc)
    ;;
  remote | dev-remote)
    vm_name="${SPRITE_NAME:-dev-remote}"
    pat_ref="${OP_GH_PAT_REMOTE:-op://Dev/GitHub PAT (dev-remote)/token}"
    exec_cmd=(sprite exec -s "${vm_name}" -- bash -lc)
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

sa_ref="${OP_SERVICE_ACCT_REF:-op://Dev/Service Account (Dev)/credential}"
op_bin="$(command -v op || echo /usr/local/bin/op)"
if [ ! -x "${op_bin}" ]; then
  echo "1Password CLI (op) not found." >&2
  exit 1
fi

if ! "${op_bin}" account list >/dev/null 2>&1; then
  cat >&2 <<'EOF'
1Password CLI integration is not active on this host.
Enable "Integrate with 1Password CLI" in 1Password -> Settings -> Developer,
then re-run this script.
EOF
  exit 1
fi

echo "Reading scoped GitHub PAT for ${vm_name} from 1Password (${pat_ref})..."
if ! gh_pat="$("${op_bin}" read "${pat_ref}")"; then
  echo "Failed to read ${pat_ref}. Create a fine-grained PAT (excluding dotfiles) in the Dev vault first." >&2
  exit 1
fi

sa_token=""
if sa_token="$("${op_bin}" read "${sa_ref}" 2>/dev/null)"; then
  echo "Read optional 1Password Service Account token (${sa_ref})."
else
  sa_token=""
  echo "Note: ${sa_ref} not found; skipping OP_SERVICE_ACCOUNT_TOKEN."
fi

# Authenticate gh inside the VM over stdin (never passing the secret via argv).
# shellcheck disable=SC2016
printf '%s\n' "${gh_pat}" | "${exec_cmd[@]}" '
  set -euo pipefail
  export PATH="${HOME}/.nix-profile/bin:${PATH}"
  gh auth login --hostname github.com --git-protocol https --with-token
  gh auth setup-git
'

if [ -n "${sa_token}" ]; then
  # shellcheck disable=SC2016
  printf '%s' "${sa_token}" | "${exec_cmd[@]}" '
    set -euo pipefail
    mkdir -p "${HOME}/.config/dev-vm"
    chmod 700 "${HOME}/.config/dev-vm"
    install -m 600 /dev/stdin "${HOME}/.config/dev-vm/op-service-account-token"
    cat > "${HOME}/.config/dev-vm/env.fish" <<'"'"'EOF'"'"'
if test -r ~/.config/dev-vm/op-service-account-token
    set -gx OP_SERVICE_ACCOUNT_TOKEN (string trim < ~/.config/dev-vm/op-service-account-token)
end
EOF
    chmod 600 "${HOME}/.config/dev-vm/env.fish"
  '
fi

# Generate VM-local commit signing key and configure git local overrides.
"${exec_cmd[@]}" "
  set -euo pipefail
  mkdir -p \"\${HOME}/.ssh\" \"\${HOME}/.config/git\"
  chmod 700 \"\${HOME}/.ssh\"
  key=\"\${HOME}/.ssh/id_ed25519_signing\"
  if [ ! -f \"\${key}\" ]; then
    ssh-keygen -t ed25519 -N \"\" -C \"${vm_name}-signing\" -f \"\${key}\"
  fi
  cat > \"\${HOME}/.config/git/config.local\" <<EOF
[user]
	signingkey = \${key}.pub

[gpg]
	format = ssh

[commit]
	gpgsign = true
EOF
"

if [ "${clone_repos}" = true ]; then
  # shellcheck disable=SC2016
  "${exec_cmd[@]}" '
    set -euo pipefail
    mkdir -p "${HOME}/workspace"
    repos_file="${HOME}/dotfiles/vm/repos.txt"
    if [ ! -f "${repos_file}" ]; then
      echo "Missing ${repos_file}" >&2
      exit 1
    fi
    while IFS=" " read -r url rel; do
      [ -z "${url}" ] && continue
      case "${url}" in \#*) continue ;; esac
      dest="${HOME}/workspace/${rel}"
      if [ ! -d "${dest}/.git" ]; then
        mkdir -p "$(dirname "${dest}")"
        git clone "${url}" "${dest}"
      fi
    done < "${repos_file}"
  '
fi

echo "Seeded ${vm_name} cleanly."
