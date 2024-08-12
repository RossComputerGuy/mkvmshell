{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    systems.url = "github:nix-systems/default-linux";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    systems,
  }:
    flake-utils.lib.eachSystem (import systems) (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
          config.useVMShell = true;
        };
      in {
        legacyPackages = pkgs;

        devShells.default = pkgs.mkVMShell {};
      }) // {
        inherit (nixpkgs) lib;

        overlays.default = import ./pkgs/default.nix;
      };
}
