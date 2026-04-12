{ inputs, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    inputs.xremap.nixosModules.default
    ../../hosts/common/default.nix
    # デスクトップ環境: どちらか一方を有効化
    # ./kde.nix
    ./gnome.nix
  ];

  networking.hostName = "minipc";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  environment.sessionVariables = {
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  # xremapでキー設定をいい感じに変更
  services.xremap = {
    enable = true;
    userName = "kaka";
    serviceMode = "system";
    config = {
      modmap = [
        {
          # CapsLockをCtrlに置換
          name = "CapsLock is dead";
          remap = {
            CapsLock = "Ctrl_L";
          };
        }
      ];
    };
  };

  # AMD CPU マイクロコードアップデート
  hardware.cpu.amd.updateMicrocode = true;

  # AMD GPU ドライバー（Radeon 780M / RDNA 3）
  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # 非推奨らしいのでコメントアウト
      # amdvlk
    ];
  };

  # Vulkan は Mesa の RADV を優先（安定性が高い）
  environment.variables.AMD_VULKAN_ICD = "RADV";

  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    curl
    appimage-run
    # GUI
    bitwarden-desktop
    brave
    ghostty
    wezterm
    vivaldi
    chromium
    vscode
  ];

  system.stateVersion = "25.11";
}
