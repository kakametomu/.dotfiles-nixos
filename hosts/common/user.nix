{ pkgs, ... }: {
  users.users.kaka = {
    isNormalUser = true;
    description = "kaka";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  # fishをログインシェルとして使用するために必要
  programs.fish.enable = true;

  # Install firefox.
  programs.firefox.enable = true;
}
