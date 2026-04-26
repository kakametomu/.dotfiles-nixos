{ ... }: {
  # fcitx5キーバインド設定
  # 変換キー → IME ON（日本語入力）
  # 無変換キー → IME OFF（英語直接入力）
  # 注意: xdg.configFileはNixストアへのシンボリックリンクになるため
  #       fcitx5がファイルに書き込もうとするとエラーログが出るが動作には影響しない
  xdg.configFile."fcitx5/config".text = ''
    [Hotkey]
    TriggerKeys/0=
    ActivateKeys/0=Henkan_Mode
    DeactivateKeys/0=Muhenkan
  '';
}
