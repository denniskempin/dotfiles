# Helper for navigating google3
__citc_root() {
  if [[ $PWD =~ '(/google/src/cloud/[^/]+/.+/google3).*' ]]; then
    echo $match[1]
  else
    echo ""
  fi
}

__citc_local_path() {
	if [[ $PWD =~ '/google/src/cloud/[^/]+/.+/google3(.*)' ]]; then
    echo $match[1]
  else
    echo $PWD
  fi
}

__citc_google3_path() {
	local path=$(__citc_local_path)
	if [[ $path =~ '/blaze-bin(.*)' ]]; then
		echo $match[1];
	elif [[ $path =~ '/blaze-genfiles(.*)' ]]; then
		echo $match[1];
	elif [[ $path =~ '/blaze-out(.*)' ]]; then
		echo $match[1];
	else
		echo $path;
	fi
}

bbin() {
	echo $(__citc_root)/blaze-bin$(__citc_google3_path);
}
alias cbbin="cd $(bbin)"

bout() {
	echo $(__citc_root)/blaze-out$(__citc_google3_path);
}
alias cbout="cd $(bout)"

bgen() {
	echo $(__citc_root)/blaze-genfiles$(__citc_google3_path);
}
alias cbgen="cd $(bgen)"

g3() {
	echo $(__citc_root)$(__citc_google3_path);
}
alias cg3="cd $(g3)"

cb() {
	local path=$(__citc_local_path)
	if [[ $path =~ '/blaze-bin.*' ]]; then
		cg3
	else
		cbbin
	fi
}

cg() {
	local path=$(__citc_local_path)
	if [[ $path =~ '/blaze-genfiles.*' ]]; then
		cg3
	else
		cbgen
	fi
}

croot() {
  echo $(__citc_root)
}

# Prompt theme with google3 and fig support
autoload -Uz promptinit
autoload -U colors && colors
promptinit

setopt promptsubst
source /google/src/head/depot/google3/experimental/fig_contrib/prompts/fig_status/zsh/fig_prompt

function get_fig_prompt_template() {
  echo -n ' %F{yellow}FIG_PROMPT_MODIFIED%F{green}FIG_PROMPT_ADDED'
  echo -n '%F{red}FIG_PROMPT_DELETED%F{cyan}FIG_PROMPT_UNKNOWN'
  echo -n '%F{magenta}FIG_PROMPT_HAS_SHELVE%F{white}FIG_PROMPT_CHANGENAME'
  echo -n '%F{green}FIG_PROMPT_UNEXPORTED%F{red}FIG_PROMPT_OBSOLETE'
}

google3_prompt_info() {
  if [[ $PWD =~ '/google/src/cloud/[^/]+/(.+)/google3(.*)' ]]; then
	  print -r -- "%{$fg_bold[green]%}($match[1]$(get_fig_prompt)%{$fg_bold[green]%}) %{$fg_bold[blue]%}//${match[2]#/}"
  else
    echo "%{$fg_bold[blue]%}$(print -P %~)"
  fi
}

PROMPT='$(google3_prompt_info) %{$fg[green]%}➜ %{$reset_color%}'

