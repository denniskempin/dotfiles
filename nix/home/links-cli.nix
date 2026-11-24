# CLI app config links shared by main systems and devcontainers.
{
  config,
  lib,
  ...
}:
let
  # Every machine keeps the checkout at ~/dotfiles. Out-of-store links keep
  # edits live without a rebuild.
  configs = "${config.home.homeDirectory}/dotfiles/configs";
  link = rel: config.lib.file.mkOutOfStoreSymlink "${configs}/${rel}";
in
{
  home.file = {
    ".bashrc".source = link "bash/bashrc";
    ".zshrc".source = link "bash/bashrc";
  };

  # Apps that write state next to their config (fish, gh) get file links; the
  # rest get the whole directory.
  xdg.configFile = {
    "fish/conf.d/00-paths.fish".source = link "fish/conf.d/00-paths.fish";
    "fish/config.fish".source = link "fish/config.fish";
    "fish/fish_plugins".source = link "fish/fish_plugins";
    "gh/config.yml".source = link "gh/config.yml";
    "helix".source = link "helix";
    "nvim".source = link "nvim";
    "starship.toml".source = link "starship/starship.toml";
  };

  # A missing checkout would leave every link above dangling without an error.
  home.activation.checkDotfiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ ! -d ${lib.escapeShellArg configs} ]; then
      echo "Missing ${configs}; clone the dotfiles repo there first." >&2
      exit 1
    fi
  '';
}
