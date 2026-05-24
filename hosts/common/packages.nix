{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    curl
    appimage-run
    # GUI
    bitwarden-desktop
    brave
    ghostty
    wezterm
    chromium
    vscode
    obs-studio
  ];
}
