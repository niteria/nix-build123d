{
  description = "Extension of CAD development base";

  inputs = {
    base.url = "github:niteria/nix-build123d";
  };

  outputs =
    {
      self,
      base,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (system: {
      devShells.default = base.outputs.packages.${system}.mkCadDevShell { extraWorkspaces = ./.; };
    });
}
