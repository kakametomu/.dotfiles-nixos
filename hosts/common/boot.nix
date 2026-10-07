{ config, ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # v4l2loopback カーネルモジュールを入れる
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];

  # 起動時に v4l2loopback をロードする
  boot.kernelModules = [ "v4l2loopback" ];

  # ホスト固有の仮想カメラ(例: minipc の camera-pipewire-bridge)を追加する場合は
  # lib.mkForce でこの設定ごと上書きする(v4l2loopback の options 行は1本化しないと
  # modprobe 側でパラメータが衝突するため)
  # デフォルトでは /dev/video10 に OBS Virtual Camera を1つだけ作る
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  networking.networkmanager.enable = true;
}
