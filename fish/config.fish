set dotfiles_dir (realpath (dirname (realpath (status --current-filename)))/..)

fish_add_path -P ~/go/bin
fish_add_path -P ~/.cargo/bin
fish_add_path -P ~/.local/bin

starship init fish | source

if command -v zoxide &>/dev/null
    zoxide init fish | source
end

if command -v exa &>/dev/null
    alias ls="exa"
    alias ll="exa -l"
    alias la="exa -la"
end

if command -v batcat &>/dev/null
    alias bat="batcat"
end

# Universal key bindings (Same key bindings shared with other apps)
fzf_configure_bindings --history=\e\cp --process=  # hyper-p: fuzzy search history
bind \e\cf 'zi' # hypert-f: fuzzy search recent directories
bind \ej 'prevd; commandline -f repaint' # alt-j: usually cmd-[, remapped by skhd
bind \ek 'nextd; commandline -f repaint' # alt-k: usually cmd-], remapped by skhd


# Enable mouse scrolling in less output
export LESS="--mouse"

# Use nvim as default editor
export EDITOR="hx"

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
