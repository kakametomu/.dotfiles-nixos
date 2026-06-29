{ ... }: {
  # Linuxデスクトップ向けのパッケージマネージャ
  # アプリケーションをサンドボックス化して実行する
  # NixOSが対応していないアプリのインストールに使う
  services.flatpak = {
    enable = true;
    packages = [
      { appId = "com.bitwarden.desktop"; origin = "flathub"; }
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };

  xdg.portal.enable = true; # flatpakに必要
}
