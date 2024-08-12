let
  flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
  nixpkgs = builtins.fetchTree flakeLock.nodes.nixpkgs.locked;
in
{ overlays ? [], config ? {}, ... }@args:
(import nixpkgs.outPath) ({
  overlays = [
    (import ./pkgs/default.nix)
  ] ++ args.overlays or [];
  config = {
    useVMShell = true;
  } // args.config or {};
} // builtins.removeAttrs args [ "overlays" "config" ])
