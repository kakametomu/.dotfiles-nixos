{ pkgs, lib, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../hosts/common/default.nix
    ./kde.nix
  ];

  networking.hostName = "minipc";

  # FHD Camera (1bcf:28c4) をそのまま Chrome/Meet/OBS に見せると黒フレームやFPS誤認が起きる。
  # MJPEG 30fps を ffmpeg で低遅延変換し、v4l2loopback (/dev/video0) に書き戻してブリッジする。
  # OBS Virtual Camera (video_nr=10) は hosts/common/boot.nix の設定を維持しつつ追加するため、
  # options 行ごと mkForce で上書きする。
  boot.extraModprobeConfig = lib.mkForce ''
    options v4l2loopback devices=2 video_nr=0,10 card_label="FHD Camera (Virtual),OBS Virtual Camera" exclusive_caps=0,1
  '';

  systemd.user.services.camera-pipewire-bridge = {
    description = "FHD Camera の映像を ffmpeg で v4l2loopback (/dev/video0) へ低遅延ブリッジ";
    serviceConfig = {
      ExecStartPre = "${pkgs.v4l-utils}/bin/v4l2-ctl -d /dev/video0 -p 30";
      ExecStart = "${pkgs.ffmpeg}/bin/ffmpeg -hide_banner -loglevel warning -fflags nobuffer -flags low_delay -thread_queue_size 1 -use_wallclock_as_timestamps 1 -f v4l2 -framerate 30 -video_size 1280x720 -input_format mjpeg -i /dev/video2 -an -vf format=yuyv422 -f v4l2 /dev/video0";
      ExecStartPost = "${pkgs.v4l-utils}/bin/v4l2-ctl -d /dev/video0 -p 30";
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
