 directory_name() {
    if [[ -d $(git rev-parse --show-toplevel 2>/dev/null) ]]; then
        # We're in a git repo.
        BASE=$(basename $(git rev-parse --show-toplevel))
        PATH_TO_CURRENT="${$(pwd -P)#$(git rev-parse --show-toplevel)}"
        echo "%{$fg_bold[green]%}-/${BASE}$(git_prompt_info)%{$fg_bold[green]%}${PATH_TO_CURRENT}"
    else
        # Not in a git repo
        echo "%{$fg_bold[green]%}$(print -P %3~)"
    fi
}
local ret_status="%(?:%{$fg_bold[blue]%}$:%{$fg_bold[red]%}$%s)"

PROMPT='%{$fg_bold[${SHELLCOLOR}]%}${SHELLNAME}%{$fg_bold[red]%}:$(directory_name)${ret_status} %{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[blue]%}(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[yellow]%}✗%{$fg[blue]%})%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"