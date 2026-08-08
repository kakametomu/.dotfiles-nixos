{ config, ... }: {
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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

  # OpenSSHデーモン（Tailscale経由のみ・公開鍵認証のみ）
  services.openssh = {
    enable = true;
    openFirewall = false; # LANには公開しない（tailscale0はtrustedInterfacesなので接続可）
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
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

  # Dockerをrootlessのみで有効化（rootデーモンは起動しない）
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true; # $DOCKER_HOSTを設定
  };
}
