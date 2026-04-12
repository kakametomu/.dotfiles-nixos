{ inputs, config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    inputs.xremap.nixosModules.default
    ../../hosts/common/default.nix
    # デスクトップ環境: kde.nix または gnome.nix を選択
    # ./kde.nix
    ./gnome.nix
  ];

  networking.hostName = "vbox";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # VMware仮想環境ではOpenGL 4.1しか利用できないため、ソフトウェアレンダリングを使用
  environment.variables.LIBGL_ALWAYS_SOFTWARE = "1";

  environment.sessionVariables = {
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    # VirtualBoxでGNOMEのMutterがハードウェアカーソルを描画できないため無効化
    MUTTER_DEBUG_DISABLE_HW_CURSORS = "1";
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
