# Random helper to cause iterm to show a notification
notify() {
	($*);
	echo 'iterm-notify';
}

# Load starship theme
eval "$(starship init zsh)"
