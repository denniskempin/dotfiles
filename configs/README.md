# App configs

Each directory holds one app's config, named as the app expects. To install
one by hand, symlink it to the destination below. `nix/home/links.nix` makes
the same links; keep the two in step.

Where an app writes its own state next to the config, only the files are
linked, not the directory.

| Directory | Destination | Platforms |
| --- | --- | --- |
| `aerospace/` | `~/.config/aerospace` | macOS |
| `bash/bashrc` | `~/.bashrc` and `~/.zshrc`. Starts fish for interactive shells | all |
| `cursor/settings.json` | `~/Library/Application Support/Cursor/User/settings.json` on macOS, `~/.config/Cursor/User/settings.json` on Linux | all |
| `fish/config.fish`, `fish/fish_plugins`, `fish/conf.d/00-paths.fish` | `~/.config/fish/`, files only, same relative paths. Run `fisher update` afterwards | all |
| `gh/config.yml` | `~/.config/gh/config.yml`, file only. `hosts.yml` stays local | all |
| `git/config` | `~/.config/git/config`. Remove any `~/.gitconfig` | all |
| `helix/` | `~/.config/helix` | all |
| `iterm2/` | Not linked. Point iTerm at it: `defaults write com.googlecode.iterm2 PrefsCustomFolder -string ~/dotfiles/configs/iterm2` and `defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true` | macOS |
| `karabiner/karabiner.json` | `~/.config/karabiner/karabiner.json`, file only | macOS |
| `keyagent/` | `~/.config/keyagent`. See `keyagent/AGENTS.md` for tests | macOS |
| `nvim/` | `~/.config/nvim` | all |
| `starship/starship.toml` | `~/.config/starship.toml` | all |
| `vscode/settings.json`, `vscode/keybindings.json` | `~/Library/Application Support/Code/User/` | macOS |
