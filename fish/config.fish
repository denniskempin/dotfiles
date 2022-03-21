set dotfiles_dir (realpath (dirname (realpath (status --current-filename)))/..)

starship init fish | source

if command -v zoxide &> /dev/null
    zoxide init fish | source
end

source {$dotfiles_dir}/fish/iterm2_shell_integration.fish

if command -v exa &> /dev/null
    alias ls="exa"
    alias ll="exa -l"
    alias la="exa -la"
end

# Use hyper+t and hyper+s for history and directory search
fzf_configure_bindings --history=\e\ct --directory=\e\cs --git_status --git_log

# Enable mouse scrolling in less output
export LESS="--mouse"

# Use nvim as default editor
export EDITOR="nvim"

set PATH $PATH $HOME/go/bin
set PATH $PATH $HOME/.cargo/bin
set PATH $PATH $dotfiles_dir/containers
