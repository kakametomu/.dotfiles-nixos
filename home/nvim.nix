{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # Lua中心の構成でRuby/Pythonプロバイダは未使用（26.05以降のデフォルトを先取り）
    withRuby = false;
    withPython3 = false;
    extraPackages = with pkgs; [
      lua-language-server
      nixd
    ];
  };

  home.file.".config/nvim/".source = ./nvim;
}
