{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    xremap.url = "github:xremap/nix-flake";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    nixosConfigurations = {
      vbox = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/vbox/default.nix
        ];
	specialArgs = {
          inherit inputs; # `inputs = inputs;`と等しい
        };
      };
    };
    homeConfigurations = {
      myHome = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true; # プロプライエタリなパッケージを許可
        };
        extraSpecialArgs = {
          inherit inputs;
        };
        modules = [
          ./home/default.nix
          ./home/git.nix
          ./home/nvim.nix
          ./home/zsh.nix
          ./home/fish.nix
          ./home/bash.nix
        ];
      };
    };
  };
}
