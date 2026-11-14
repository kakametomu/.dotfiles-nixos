{ pkgs, ... }: {
  # Linuxデスクトップ向けのパッケージマネージャ
  # アプリケーションをサンドボックス化して実行する
  # NixOSが対応していないアプリのインストールに使う
  services.flatpak = {
    enable = true;
    packages = [
      { appId = "com.bitwarden.desktop"; origin = "flathub"; }
      { appId = "io.dbeaver.DBeaverCommunity"; origin = "flathub"; }
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };

  xdg.portal.enable = true; # flatpakに必要

  # Bitwardenデスクトップの「システム認証でロック解除」用のpolkitポリシー。
  # Flatpak版はサンドボックス内から /usr/share/polkit-1/actions に書き込めないため、
  # アプリ側では自動セットアップできない。ホスト側にポリシーがあれば、認証自体は
  # サンドボックス内からD-Bus経由で行える。
  # 内容は bitwarden/clients の os-biometrics-linux.service.ts にあるものと同じ。
  # 使い方は docs/yubikey.md の「Bitwarden で使う」を参照。
  environment.systemPackages = [
    (pkgs.writeTextDir "share/polkit-1/actions/com.bitwarden.Bitwarden.policy" ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE policyconfig PUBLIC
       "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
       "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">

      <policyconfig>
          <action id="com.bitwarden.Bitwarden.unlock">
            <description>Unlock Bitwarden</description>
            <message>Authenticate to unlock Bitwarden</message>
            <defaults>
              <allow_any>no</allow_any>
              <allow_inactive>no</allow_inactive>
              <allow_active>auth_self</allow_active>
            </defaults>
          </action>
      </policyconfig>
    '')
  ];
}
