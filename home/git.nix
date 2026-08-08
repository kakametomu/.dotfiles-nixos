{pkgs, ...}: {
  programs.git = {
    enable = true;
    settings = {
      user.name = "kaka";
      # GitHubのnoreplyアドレス（実メールアドレスの公開を避ける）
      user.email = "111382108+kakametomu@users.noreply.github.com";
      init.defaultBranch = "main";
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

