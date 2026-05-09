{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../hosts/common/default.nix
    # デスクトップ環境: kde.nix または gnome.nix を選択
    ./kde.nix
    # ./gnome.nix
  ];

  networking.hostName = "vbox";

  # VMware仮想環境ではOpenGL 4.1しか利用できないため、ソフトウェアレンダリングを使用
  environment.variables.LIBGL_ALWAYS_SOFTWARE = "1";

  # VirtualBoxでGNOMEのMutterがハードウェアカーソルを描画できないため無効化
  environment.sessionVariables.MUTTER_DEBUG_DISABLE_HW_CURSORS = "1";

  environment.systemPackages = with pkgs; [
    vivaldi
  ];

  system.stateVersion = "25.11";
}
