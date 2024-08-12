let
  flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
  nixpkgs = builtins.fetchTree flakeLock.nodes.nixpkgs.locked;
in (import nixpkgs.outPath)
