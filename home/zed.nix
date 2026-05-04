{pkgs, ...}: {
  programs.zed-editor = {
    enable = true;
    extensions = [];
    userSettings = {
      ui_font_size = 16;
      buffer_font_size = 14;
      theme = "One Dark";
      vim_mode = false;
    };
  };
}
