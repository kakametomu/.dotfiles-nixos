{ ... }: {
  imports = [
    ./locale.nix
    ./fonts.nix
    ./input-method.nix
    ./desktop.nix
    ./user.nix
    ./nix.nix
    ./boot.nix
    ./packages.nix
    ./xremap.nix
  ];
}
