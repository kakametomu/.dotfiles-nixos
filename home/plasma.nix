{ ... }: {
  programs.plasma = {
    enable = true;
    # 設定例（必要に応じて追記していく）
    # workspace = {
    #   lookAndFeel = "org.kde.breezedark.desktop";
    # };
    kwin.virtualDesktops = {
      number = 4;
      rows = 1;
    };

    # Cinnamonライクなパネルレイアウト
    # 左: アプリランチャー → タスクバー → 右: システムトレイ → 時計
    panels = [
      {
        location = "bottom";
        floating = false;
        hiding = "none";
        widgets = [
          # アプリケーションメニュー（左端）
          { name = "org.kde.plasma.kickoff"; }
          # ウィンドウ一覧（タスクバー）- アイコンのみ、グループ化なし
          {
            iconTasks = {
              iconsOnly = true;
              behavior.grouping.method = "none";
            };
          }
          # 右寄せスペーサー
          { name = "org.kde.plasma.panelspacer"; }
          # 仮想デスクトップ切り替え（Cinnamonライクな番号ボタン）
          { name = "org.kde.plasma.pager"; }
          # キーボードレイアウト切り替え（JP ↔ US）
          { name = "org.kde.plasma.keyboardlayout"; }
          # システムトレイ
          { name = "org.kde.plasma.systemtray"; }
          # デジタル時計
          { name = "org.kde.plasma.digitalclock"; }
        ];
      }
    ];
  };
}
