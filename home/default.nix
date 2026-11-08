{ pkgs, config, ... }: {
  imports = [
    ./git.nix
    ./nvim.nix
    ./zed.nix
    ./zsh.nix
    ./fish.nix
    ./bash.nix
    ./plasma.nix
    ./fcitx5.nix
    ./workarounds.nix
  ];

  home = rec {
    username = "kaka";
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
  };

  home.packages = with pkgs; [
    eza
    bat
    ripgrep
    fzf
    zoxide
    tmux
    herdr
    google-chrome
    # UpNote: nixpkgs未対応のため AppImage をラッパーで起動
    # AppImage本体は ~/Applications/UpNote.AppImage に配置すること
    (pkgs.writeShellScriptBin "upnote" ''
      exec ${pkgs.appimage-run}/bin/appimage-run ${config.home.homeDirectory}/Applications/UpNote.AppImage --ozone-platform=wayland "$@"
    '')
  ];

  # claude-code / codex: アップストリームの更新頻度（ほぼ毎日）が
  # Nixのビルド/switchサイクルに追いつかず、nixpkgs側も自己更新機能を
  # 無効化してしまうため、公式インストーラで手動管理する（README参照）。
  # インストール先の ~/.local/bin を使えるようにPATHへ追加するのみ。
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # 全シェル共通のエイリアス（fish固有のものはfish.nixで管理）
  home.shellAliases = {
    cat  = "bat";
    grep = "rg";
  };

  home.file = {
    ".local/share/applications/upnote.desktop" = {
      force = true;
      text = ''
        [Desktop Entry]
        Name=UpNote
        Exec=upnote %U
        Icon=upnote
        Comment=Beautiful, simple note taking app
        Type=Application
        Categories=Office;
        Terminal=false
      '';
    };
    ".config/ghostty/".source = ./ghostty;
    ".config/wezterm/".source = ./wezterm;
    ".config/tmux/tmux.conf".source = ./tmux/tmux.conf;
    ".local/share/icons/hicolor/256x256/apps/upnote.png".source = ./icons/upnote.png;
  };

  programs.home-manager.enable = true;

  # カーソルテーマの設定（Wayland/X11両方に適用）
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
  };
}
