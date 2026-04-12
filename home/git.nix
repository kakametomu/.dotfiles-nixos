{pkgs, ...}: {
  programs.git = {
    enable = true;
    settings = {
      user.name = "kaka";
      user.email = "kaka@example.com"; # TODO: 本物のメールアドレスに変更する
    };
  };

  # GitHub CLI
  programs.gh = {
    enable = true;
    extensions = with pkgs; [gh-markdown-preview];
    settings = {
      editor = "nvim";
    };
  };
}

