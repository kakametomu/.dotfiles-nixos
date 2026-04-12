{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    xremap.url = "github:xremap/nix-flake";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
  let
    mkSystem = { hostname, system ? "x86_64-linux", extraModules ? [] }:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/${hostname}/default.nix ] ++ extraModules;
      };
  in {
    nixosConfigurations = {
      vbox = mkSystem { hostname = "vbox"; };
      # hosts/main/hardware-configuration.nix を追加してからコメントを外す
      # main = mkSystem { hostname = "main"; };
      # hosts/minipc/hardware-configuration.nix を追加してからコメントを外す
      # minipc = mkSystem { hostname = "minipc"; };
    };
    homeConfigurations = {
      myHome = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true; # プロプライエタリなパッケージを許可
        };
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./home/default.nix ];
      };
    };
  };
}
