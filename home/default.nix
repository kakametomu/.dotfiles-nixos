{ pkgs, ... }:

{
  home = rec {
    username="kaka";
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
  };

  home.packages = with pkgs; [
    eza
    bat
    ripgrep
    fzf
    zoxide
    claude-code
  ];

  # 全シェル共通のエイリアス（fish固有のものはfish.nixで管理）
  home.shellAliases = {
    cat  = "bat";
    grep = "rg";
  };

  home.file = {
    ".config/ghostty/".source = ./ghostty;
    ".config/wezterm/".source = ./wezterm;
  };

  programs.home-manager.enable = true;
}
