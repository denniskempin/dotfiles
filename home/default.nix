# Home configuration shared by every machine, macOS and Linux.
{
  config,
  pkgs,
  ...
}:
let
  # Symlink into the git checkout so edits stay live. Every machine keeps the
  # checkout at ~/dotfiles.
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  link = rel: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${rel}";

  # Where Electron apps like Cursor keep per-user settings.
  appConfig = if pkgs.stdenv.isDarwin then "Library/Application Support" else ".config";
in
{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    bat
    bottom
    delta
    direnv
    eza
    fd
    fzf
    grc
    helix
    jq
    less
    procs
    ripgrep
    rsync
    starship
    tldr
    wget
    zoxide
  ];

  home.file = {
    ".gitconfig".source = link "gitconfig";
    ".bashrc".source = link "fish/bashrc";
    ".zshrc".source = link "fish/bashrc";

    "${appConfig}/Cursor/User/settings.json".source = link "cursor/settings.json";
  };

  xdg.configFile = {
    "fish/config.fish".source = link "fish/config.fish";
    "fish/fish_plugins".source = link "fish/fish_plugins";
    "starship.toml".source = link "fish/starship.toml";
    "helix".source = link "helix";
    "nvim".source = link "nvim";
    "gh/config.yml".source = link "gh/config.yml";
  };
}
