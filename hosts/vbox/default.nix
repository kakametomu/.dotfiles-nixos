# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ 
  inputs,
  config, 
  pkgs,
  ...
}:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.xremap.nixosModules.default
      # デスクトップ環境: kde.nix または gnome.nix を選択
      # ./kde.nix
      ./gnome.nix
    ];

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
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Tokyo";

  # Select internationalisation properties.
  i18n.defaultLocale = "ja_JP.UTF-8";

  # VMware仮想環境ではOpenGL 4.1しか利用できないため、ソフトウェアレンダリングを使用
  environment.variables.LIBGL_ALWAYS_SOFTWARE = "1";

  # fcitx5の日本語入力をWaylandセッションで有効化
  # GTK_IM_MODULE/QT_IM_MODULEはWaylandのネイティブIMプロトコルと競合するため設定しない
  environment.sessionVariables = {
    XMODIFIERS = "@im=fcitx"; # XWaylandアプリ向け
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    # VirtualBoxでGNOMEのMutterがハードウェアカーソルを描画できないため無効化
    MUTTER_DEBUG_DISABLE_HW_CURSORS = "1";
  };

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };
  
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc-ut
        fcitx5-gtk
      ];
    };
  };

  fonts = {
    packages = with pkgs; [
      noto-fonts-cjk-serif
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.caskaydia-mono
    ];
    fontDir.enable = true;
    fontconfig = {
      defaultFonts = {
        serif = ["Noto Serif CJK JP" "Noto Color Emoji"];
        sansSerif = ["Noto Sans CJK JP" "Noto Color Emoji"];
        monospace = ["CaskaydiaMono Nerd Font" "Noto Color Emoji"];
        emoji = ["Noto Color Emoji"];
      };
    };
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kaka = {
    isNormalUser = true;
    description = "kaka";
    extraGroups = [ "networkmanager" "wheel" ];
    # 初回ログイン用パスワード（passwd コマンドで変更後は無効）
    initialPassword = "changeme";
    shell = pkgs.fish;
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # fishをログインシェルとして使用するために必要
  programs.fish.enable = true;

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
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

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  system.stateVersion = "25.11"; # Did you read the comment?

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
    };
    # ガベージコレクションを自動実行
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # tailscale（VPN）を有効化
  services.tailscale.enable = true;
  networking.firewall = {
    enable = true;
    # tailscaleの仮想NICを信頼する
    # `<Tailscaleのホスト名>:<ポート番号>`のアクセスが可能になる
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
  };

  # Dockerをrootlessで有効化
  virtualisation = {
    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true; # $DOCKER_HOSTを設定
      };
    };
  };

  # Linuxデスクトップ向けのパッケージマネージャ
  # アプリケーションをサンドボックス化して実行する
  # NixOSが対応していないアプリのインストールに使う
  services.flatpak.enable = true;
  xdg.portal.enable = true; # flatpakに必要
}
