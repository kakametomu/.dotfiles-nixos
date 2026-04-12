{ pkgs, ... }: {
  users.users.kaka = {
    isNormalUser = true;
    description = "kaka";
    extraGroups = [ "networkmanager" "wheel" ];
    # 初回ログイン用パスワード（passwd コマンドで変更後は無効）
    initialPassword = "changeme";
    shell = pkgs.fish;
    packages = with pkgs; [];
  };

  # fishをログインシェルとして使用するために必要
  programs.fish.enable = true;

  # Install firefox.
  programs.firefox.enable = true;
}
