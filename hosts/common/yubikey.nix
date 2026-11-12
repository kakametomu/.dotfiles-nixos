{ pkgs, ... }:

{
  # YubiKeyによる sudo / SDDMログイン / KDE画面ロック解除のパスワードレス認証、
  # および SSH FIDO2常駐鍵認証 (ssh-keygen -t ed25519-sk) のサポート。
  # 登録・有効化の手順は docs/yubikey.md を参照。
  #
  # 想定構成:
  #   - メイン:       YubiKey Bio    (pamu2fcfg -V で登録 → 指紋が必須)
  #   - バックアップ: タッチ式YubiKey (pamu2fcfg -N で登録 → PIN + タッチが必須)
  # 指紋/PINの要否は鍵ごとに authfile 側のフラグ (+verification / +pin) で決める。
  # ここで userverification = 1 を全体に指定すると、指紋センサーの無い
  # バックアップキーが無視されるので指定しない。
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
      authfile = "/etc/security/u2f_keys";
      # ホスト名非依存の固定origin。デフォルト(pam://$HOSTNAME)のままだと
      # main/minipc/vboxでホスト名が異なり同じauthfileが使えなくなる。
      origin = "pam://dotfiles-nixos";
      cue = true; # "please touch your YubiKey" を表示
    };
  };

  # "sufficient": 鍵で認証できればパスワード不要。失敗時・鍵が無いときはパスワードにフォールバックする。
  # パスワードも必須にしたいサービスは "required" にする (鍵が無いと認証できなくなる点に注意)。
  # ここに無いPAMサービス (su / polkit-1 など) も nixpkgs の既定値で "sufficient" になる。
  security.pam.services = {
    sudo.u2f.control = "sufficient";
    login.u2f.control = "sufficient"; # SDDMログインは "auth substack login" 経由でこれが効く
    kde.u2f.control = "sufficient";   # KDE画面ロック/解除
  };
}
