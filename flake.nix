{
  description = "SML#";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    with nixpkgs.lib;
    with flake-utils.lib;

    eachSystem allSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = with pkgs; mkShell {
          buildInputs = [
            llvmPackages_13.libllvm
            gmp
            (pkgs.callPackage ./massive-threads.nix { })
            smlnj
            smlfmt
            mlton
          ];
        };
      });
}
