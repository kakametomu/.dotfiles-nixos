{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../hosts/common/default.nix
    ./kde.nix
  ];

  networking.hostName = "main";

  # Intel CPU マイクロコードアップデート
  hardware.cpu.intel.updateMicrocode = true;

  # NVIDIA ドライバー（RTX 3060 Ti）
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false; # プロプライエタリドライバーを使用
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.systemPackages = with pkgs; [
    vivaldi
  ];

  system.stateVersion = "25.11";
}
