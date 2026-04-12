{ pkgs, ... }: {
  # fcitx5の日本語入力をWaylandセッションで有効化
  # GTK_IM_MODULE/QT_IM_MODULEはWaylandのネイティブIMプロトコルと競合するため設定しない
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc-ut
        fcitx5-gtk
      ];
    };
  };

  environment.sessionVariables = {
    XMODIFIERS = "@im=fcitx"; # XWaylandアプリ向け
  };
}
