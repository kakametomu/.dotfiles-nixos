{ ... }: {
  services.xremap.config.keymap = [
    {
      # USキーボード（RDR Rainy 75）用IME切り替え
      # Shift+F9 → 変換キー（IME ON）
      # Shift+F10 → 無変換キー（IME OFF）
      name = "US keyboard IME switch";
      remap = {
        "Shift-F9" = "Henkan";
        "Shift-F10" = "Muhenkan";
      };
    }
  ];
}
