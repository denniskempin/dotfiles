 directory_name() {
    if [[ -d $(git rev-parse --show-toplevel 2>/dev/null) ]]; then
        # We're in a git repo.
        BASE=$(basename $(git rev-parse --show-toplevel))
        PATH_TO_CURRENT="${$(pwd -P)#$(git rev-parse --show-toplevel)}"
        echo "%{$fg_bold[blue]%}-/${BASE}$(git_prompt_info)%{$fg_bold[blue]%}${PATH_TO_CURRENT}"
    else
        # Not in a git repo
        echo "%{$fg_bold[blue]%}$(print -P %~)"
    fi
}
PROMPT='%{$fg_bold[${SHELLCOLOR}]%}${SHELLNAME} $(directory_name) %{$fg[green]%}➜ %{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}("
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[yellow]%}✗%{$fg[green]%})%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[green]%})"
