# 一時的な回避策。上流で直ったら該当ブロックを削除する。
{ ... }:
{
  # Ghosttyが時々起動に失敗する（"Remote peer disconnected"）
  # 原因: systemd 262の新しいチェックと、Ghosttyの起動処理の順番がぶつかる
  # 上流: https://github.com/ghostty-org/ghostty/issues/14398
  # 追加: 2026-11-08 / 削除条件: Ghostty側で修正されたら
  xdg.configFile."systemd/user/app-com.mitchellh.ghostty.service.d/override.conf".text = ''
    [Service]
    Type=dbus
  '';
}
