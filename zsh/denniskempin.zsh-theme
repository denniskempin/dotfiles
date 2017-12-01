google3_prompt_info() {
  if [[ $PWD =~ '/google/src/cloud/[^/]+/(.+)/google3(.*)' ]]; then
    print -r -- "%{$fg_bold[green]%}($match[1]) %{$fg_bold[blue]%}//${match[2]#/}"
  else
    echo "%{$fg_bold[blue]%}$(print -P %~)"
  fi
}

 directory_name() {
    if [[ -d $(git rev-parse --show-toplevel 2>/dev/null) ]]; then
        # We're in a git repo.
        ANDROID_BRANCH=$(pwd | awk -F/ '/workspace\/android/ { print "[" $4 "] " }')
        BASE=$(basename $(git rev-parse --show-toplevel))
        PATH_TO_CURRENT="${$(pwd -P)#$(git rev-parse --show-toplevel)}"
        echo "%{$fg_bold[yellow]%}${ANDROID_BRANCH}%{$fg_bold[blue]%}-/${BASE}$(git_super_status)%{$fg_bold[blue]%}${PATH_TO_CURRENT}"
    else
        # Not in a git repo
        google3_prompt_info
    fi
}
PROMPT='%{$fg_bold[${SHELLCOLOR}]%}${SHELLNAME} $(directory_name) %{$fg[green]%}➜ %{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[green]%}("
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg_bold[green]%})%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_BRANCH="%{$fg_bold[green]%}"
ZSH_THEME_GIT_PROMPT_SEPARATOR="%{$fg_bold[green]%}|"
