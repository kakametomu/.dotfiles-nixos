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
    bitwarden-desktop
    brave
    ghostty
    wezterm
    chromium
    vscode
    obs-studio
    foliate
    signal-desktop
    obsidian
  ];
}
