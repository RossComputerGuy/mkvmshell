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
        pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
          (import ./pkgs/default.nix)
        ];
      in {
        legacyPackages = pkgs;

        devShells.default = pkgs.mkNixOSShell {};
      });
}
