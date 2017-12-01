# Set up Z to use fzf
unalias z 2> /dev/null
z() {
  [ $# -gt 0 ] && _z "$*" && return
  cd "$(_z -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
}

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
