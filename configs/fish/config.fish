set dotfiles_dir (realpath (dirname (realpath (status --current-filename)))/../..)

# Nix and Homebrew paths are set earlier, in conf.d/00-paths.fish.
# Append user-writable bin dirs at the end so they cannot shadow system or Nix tools.
fish_add_path -P -a -m ~/go/bin
fish_add_path -P -a -m ~/.cargo/bin
fish_add_path -P -a -m ~/.local/bin

starship init fish | source

if command -v zoxide &>/dev/null
    zoxide init fish | source
end

if command -v eza &>/dev/null
    alias ls="eza"
    alias ll="eza -l"
    alias la="eza -la"
end

if command -v batcat &>/dev/null
    alias bat="batcat"
end

# Universal key bindings (Same key bindings shared with other apps)
if type -q fzf_configure_bindings
    fzf_configure_bindings --history=\e\cp --process=  # hyper-p: fuzzy search history
end
bind \e\cf 'zi' # hypert-f: fuzzy search recent directories
bind \ej 'prevd; commandline -f repaint' # alt-j: Hammerspoon sends it for Back in Ghostty
bind \ek 'nextd; commandline -f repaint' # alt-k: Hammerspoon sends it for Forward in Ghostty


# Enable mouse scrolling in less output
export LESS="--mouse"

# Use hx as default editor if not already set
[ -z "$EDITOR" ] && export EDITOR=hx
[ -z "$GIT_EDITOR" ] && export GIT_EDITOR=hx

# Enable true color support
export COLORTERM="truecolor"

# extend 'git push origin' abbreviation for gerrit
alias gpom="git push origin HEAD:refs/for/main"
alias gpoc="git push origin HEAD:refs/for/chromeos"

alias gcob="git checkout --track origin/main -b "

# git 'uncommit' - along the lines of 'hg uncommit'
alias guc="git reset HEAD~ && git commit --reuse-message=HEAD@{1} --allow-empty"


function git_amend_to
    if git log HEAD..@{u} --oneline | grep '' >/dev/null
        echo 'Branch needs to rebase first.'
        return
    end

    set branch (git rev-parse --abbrev-ref HEAD)
    set target (git log @{u}..HEAD --oneline | fzf | awk '{print $1}')
    echo 'Amending to:'
    echo
    git log -n 1 --color $target
    echo
    echo 'Amending with'
    echo
    git diff
    git diff --cached
    echo

    git stash -q
    git checkout -q "$target"
    if ! git stash apply -q
        echo 'Diff does not apply cleanly. Reverting.'
        git checkout -fq "$branch"
        git stash pop -q
    end

    git commit --amend -a --no-edit
    git rebase --onto HEAD $target $branch
    git stash drop -q
end

alias gat="git_amend_to"

direnv hook fish | source

string match -q "$TERM_PROGRAM" "vscode"
and . (code --locate-shell-integration-path fish)
