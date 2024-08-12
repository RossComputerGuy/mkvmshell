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

        devShells = {
          default = pkgs.mkVMShell {};
          aarch64-linux = (if pkgs.targetPlatform.isAarch64 && pkgs.targetPlatform.isLinux then pkgs else pkgs.pkgsCross.aarch64-multiplatform).mkVMShell {};
          i686-linux = (if pkgs.targetPlatform.isi686 && pkgs.targetPlatform.isLinux then pkgs else pkgs.pkgsCross.gnu32).mkVMShell {};
          x86_64-linux = (if pkgs.targetPlatform.isx86_64 && pkgs.targetPlatform.isLinux then pkgs else pkgs.pkgsCross.gnu64).mkVMShell {};
          riscv32-linux = (if pkgs.targetPlatform.isRiscV32 && pkgs.targetPlatform.isLinux then pkgs else pkgs.pkgsCross.riscv32).mkVMShell {};
          riscv64-linux = (if pkgs.targetPlatform.isRiscV64 && pkgs.targetPlatform.isLinux then pkgs else pkgs.pkgsCross.riscv64).mkVMShell {};
        };
      }) // {
        inherit (nixpkgs) lib;

        overlays.default = import ./pkgs/default.nix;
      };
}
