{
  description = "ExpressVPN 14.x with Qt GUI — NixOS package and module";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ self.overlays.default ];
    };
  in {
    overlays.default = import ./overlay.nix;

    packages.${system} = {
      expressvpn-qt = pkgs.expressvpn-qt;
      default = pkgs.expressvpn-qt;
    };

    nixosModules.default = ./module.nix;
    nixosModules.expressvpn-qt = ./module.nix;
  };
}
