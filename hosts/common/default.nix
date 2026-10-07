{ inputs, ... }: {
  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak
    ./locale.nix
    ./fonts.nix
    ./input-method.nix
    ./desktop.nix
    ./user.nix
    ./nix.nix
    # ./yubikey.nix
    ./boot.nix
    ./packages.nix
    ./flatpak.nix
    ./xremap.nix
  ];
}
