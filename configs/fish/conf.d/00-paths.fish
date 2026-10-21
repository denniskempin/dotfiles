# Sorts ahead of the fisher plugins in conf.d, which check for grc, tldr and
# friends when they load. Nix profiles go ahead of Homebrew and distro
# packages. Homebrew fish does not read the /etc/fish config nix-darwin writes,
# so nothing else adds these. Missing directories are skipped.
fish_add_path -P -m /opt/homebrew/bin /opt/homebrew/sbin
fish_add_path -P -m ~/.nix-profile/bin /etc/profiles/per-user/$USER/bin /run/current-system/sw/bin /nix/var/nix/profiles/default/bin
