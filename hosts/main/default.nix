{ inputs, config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    inputs.xremap.nixosModules.default
    ../../hosts/common/default.nix
    ./kde.nix
  ];

  networking.hostName = "main";

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
