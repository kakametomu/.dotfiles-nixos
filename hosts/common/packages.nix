{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    curl
    appimage-run
    devenv
    # カメラテスト・設定用ツール
    v4l-utils
    ffmpeg
    # GUI
    brave
    ghostty
    wezterm
    chromium
    vscode
    obs-studio
    foliate
    signal-desktop
    obsidian
    usbutils
  ];

  # 汎用Linux向けの動的リンクバイナリを実行できるようにする
  # （claude-code の公式ネイティブインストーラ等が配布するバイナリ用）
  programs.nix-ld.enable = true;
}
