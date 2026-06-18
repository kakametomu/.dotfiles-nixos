{ inputs, ... }: {
  imports = [ inputs.xremap.nixosModules.default ];

  services.xremap = {
    enable = true;
    userName = "kaka";
    serviceMode = "system";
    config.modmap = [
      {
        # CapsLockをCtrlに置換
        name = "CapsLock is dead";
        remap.CapsLock = "Ctrl_L";
      }
    ];
  };

  # 起動時にUSBデバイスが未列挙でも再試行する
  systemd.services.xremap.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "2s";
  };
}
