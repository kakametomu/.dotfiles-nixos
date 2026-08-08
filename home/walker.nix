{ ... }: {
  services.elephant = {
    enable = true;
    settings.modules = [ "desktopapplications" "runner" ];
  };

  services.walker = {
    enable = true;
    enableElephantIntegration = true;
  };
}
