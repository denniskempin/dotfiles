# App configs

Each directory holds one app's config, named as the app expects. To install
one by hand, symlink it to the destination below. `nix/home/links.nix` makes
the same links; keep the two in step.

Where an app writes its own state next to the config, only the files are
linked, not the directory.

| Directory | Destination | Platforms |
| --- | --- | --- |
| `1password/agent.toml` | `~/.config/1Password/ssh/agent.toml`, file only | macOS |
| `bash/bashrc` | `~/.bashrc` and `~/.zshrc`. Starts fish for interactive shells | all |
| `direnv/direnv.toml` | `~/.config/direnv/direnv.toml`, file only | macOS |
| `fish/config.fish`, `fish/conf.d/00-paths.fish` | `~/.config/fish/`, files only, same relative paths | all |
| `gh/config.yml` | `~/.config/gh/config.yml`, file only. `hosts.yml` stays local | all |
| `ghostty/` | `~/.config/ghostty` | macOS |
| `git/config` | `~/.config/git/config`. Remove any `~/.gitconfig` | all |
| `hammerspoon/` | `~/.hammerspoon`. See `hammerspoon/AGENTS.md` for tests | macOS |
| `helix/` | `~/.config/helix` | all |
| `karabiner/karabiner.json` | `~/.config/karabiner/karabiner.json`, file only | macOS |
| `nvim/` | `~/.config/nvim` | all |
| `omniwm/settings.toml` | `~/.config/omniwm/settings.toml`, file only | macOS |
| `ssh/config` | `~/.ssh/config`, file only | macOS |
| `starship/starship.toml` | `~/.config/starship.toml` | all |
| `vscode/settings.json`, `vscode/keybindings.json` | `~/Library/Application Support/Code/User/` | macOS |
| `zed/settings.json` | `~/.config/zed/settings.json`, file only | all |
