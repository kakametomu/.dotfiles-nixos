{ pkgs, ... }: {
  users.users.kaka = {
    isNormalUser = true;
    description = "kaka";
    extraGroups = [ "networkmanager" "wheel" "video"];
    shell = pkgs.fish;
    # SSHはパスワード認証を無効化しているため、ログインに使う公開鍵をここに登録する
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILjQY8Nd6JOZbhMWjVL5bX6boguAK5lBd1Pj1m9z8J6H kaka"
    ];
  };

  # fishをログインシェルとして使用するために必要
  programs.fish.enable = true;

  # Install firefox.
  programs.firefox.enable = true;
}
