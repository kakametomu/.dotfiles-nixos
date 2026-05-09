{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../hosts/common/default.nix
    # デスクトップ環境: どちらか一方を有効化
    ./kde.nix
    # ./gnome.nix
    # キーボード: USキーボードの場合のみ有効化（JISはcommon/xremap.nixの設定のみで対応）
    ./keyboard-us.nix
  ];

  networking.hostName = "minipc";

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
