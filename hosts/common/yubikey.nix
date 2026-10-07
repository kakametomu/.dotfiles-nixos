{ pkgs, ... }:

{
  # YubiKeyによる sudo / SDDMログイン / KDE画面ロック解除の2FA、
  # および SSH FIDO2常駐鍵認証 (ssh-keygen -t ed25519-sk) のサポート。
  #
  # 注意: SDDM自身の "sddm" PAMサービスは useDefaultRules = false で
  # "auth substack login" に処理を委譲しているため (nixos/modules/services/display-managers/sddm.nix)、
  # U2Fは "sddm" ではなく "login" サービスに付与する必要がある。
  # KDEの画面ロック (kscreenlocker) は plasma6.nix が登録する "kde" という
  # PAMサービスを経由する。

  programs.yubikey-manager.enable = true; # ykman + pcscd + yubikey-personalization udevルール

  services.udev.packages = [ pkgs.libfido2 ]; # FIDO2 HIDのuaccessルール (pam_u2f / ssh-keygen -t ed25519-sk 両方に必要)

  environment.systemPackages = with pkgs; [
    pam_u2f   # 初回登録用の pamu2fcfg コマンド
    libfido2  # fido2-token / fido2-cred / fido2-assert (診断用)
  ];

  security.pam.u2f = {
    enable = true;
    settings = {
      authfile = ./u2f_keys;
      # ホスト名非依存の固定origin。デフォルト(pam://$HOSTNAME)のままだと
      # main/minipc/vboxでホスト名が異なり同じauthfileが使えなくなる。
      origin = "pam://dotfiles-nixos";
      cue = true; # "please touch your YubiKey" を表示
    };
  };

  security.pam.services = {
    sudo.u2f.control = "required";
    login.u2f.control = "required"; # SDDMログインは "auth substack login" 経由でこれが効く
    kde.u2f.control = "required";   # KDE画面ロック/解除
  };
}
