{ pkgs, ... }: {
  imports = [
    ./git.nix
    ./nvim.nix
    ./zsh.nix
    ./fish.nix
    ./bash.nix
    ./plasma.nix
  ];

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
    google-chrome
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

  # カーソルテーマの設定（Wayland/X11両方に適用）
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
  };

  # GNOMEのdconf設定でカーソルを明示的に指定
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      cursor-theme = "Adwaita";
      cursor-size = 24;
    };
  };
}
