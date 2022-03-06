starship init fish | source
if command -v zoxide &> /dev/null
    zoxide init fish | source
end

if command -v exa &> /dev/null
    alias ls="exa"
    alias ll="exa -l"
    alias la="exa -la"
end

# Use hyper+t and hyper+s for history and directory search
fzf_configure_bindings --history=\e\ct --directory=\e\cs --git_status --git_log

set PATH $PATH $HOME/.cargo/bin

