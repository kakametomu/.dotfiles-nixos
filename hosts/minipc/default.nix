{ pkgs, lib, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../hosts/common/default.nix
    ./kde.nix
  ];

  networking.hostName = "minipc";

  # FHD Camera (1bcf:28c4) は V4L2 直接アクセスで常に黒フレームを返すハードウェアバグがある。
  # Chrome/Firefox 等は Camera XDG ポータルを使わず V4L2 デバイスに直接アクセスするため、
  # PipeWire 経由で正しく読み出した映像を v4l2loopback (/dev/video0) に書き戻してブリッジする。
  # OBS Virtual Camera (video_nr=10) は hosts/common/boot.nix の設定を維持しつつ追加するため、
  # options 行ごと mkForce で上書きする。
  boot.extraModprobeConfig = lib.mkForce ''
    options v4l2loopback devices=2 video_nr=0,10 card_label="FHD Camera (Virtual),OBS Virtual Camera" exclusive_caps=0,1
  '';

  systemd.user.services.camera-pipewire-bridge = {
    description = "FHD Camera の映像を PipeWire から v4l2loopback (/dev/video0) へブリッジ(黒フレームバグ回避)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "pipewire.service" "wireplumber.service" ];
    serviceConfig = {
      # target-object は指定しない: USB 抜き差しで PipeWire ノードIDが変わるため、
      # 指定するとデバイス再接続のたびにブリッジが壊れる
      ExecStart = "${pkgs.gst_all_1.gstreamer}/bin/gst-launch-1.0 pipewiresrc ! videoconvert ! v4l2sink device=/dev/video0";
      Environment = "GST_PLUGIN_SYSTEM_PATH_1_0=${pkgs.pipewire}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  # AMD CPU マイクロコードアップデート
  hardware.cpu.amd.updateMicrocode = true;

  # AMD GPU ドライバー（Radeon 780M / RDNA 3）
  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Vulkan は Mesa の RADV を優先（安定性が高い）
  environment.variables.AMD_VULKAN_ICD = "RADV";

  environment.systemPackages = with pkgs; [
    (vivaldi.override {
      proprietaryCodecs = true;
      enableWidevine = false;
    })
  ];

  system.stateVersion = "25.11";
}
