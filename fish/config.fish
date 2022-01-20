starship init fish | source
zoxide init fish | source

alias ls="exa"
alias ll="exa -l"
alias la="exa -la"

# Use hyper+t and hyper+s for history and directory search
fzf_configure_bindings --history=\e\ct --directory=\e\cs --git_status --git_log

set PATH $PATH $HOME/.cargo/bin

