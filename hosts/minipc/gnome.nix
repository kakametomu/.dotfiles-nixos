{ pkgs, ... }:

{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # fcitx5のLuaスクリプト拡張（GNOME環境で使用）
  i18n.inputMethod.fcitx5.addons = with pkgs; [
    fcitx5-lua
  ];
}
