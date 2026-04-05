{
  description = "CAD development environment for build123d + yacv-server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Native libs — NO VTK needed anymore
        nativeLibs = with pkgs; [
          stdenv.cc.cc
          libuv
          zlib
          libGL
          libX11
          libXrender
          expat
        ];

        python = pkgs.python312;

        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

        pythonBase = pkgs.callPackage pyproject-nix.build.packages { inherit python; };

        pyprojectOverlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        # === THE FIX: alias the old name to the no-VTK package ===
        ocpOverlay = final: prev: {
          cadquery-ocp = final.cadquery-ocp-novtk;
          ocp = final.cadquery-ocp-novtk; # some transitive imports still use "ocp"
        };

        pythonSet = pythonBase.overrideScope (
          pkgs.lib.composeManyExtensions [
            pyproject-build-systems.overlays.wheel
            pyprojectOverlay
            ocpOverlay
          ]
        );

        editableOverlay = workspace.mkEditablePyprojectOverlay {
          root = "$REPO_ROOT";
        };

        editablePythonSet = pythonSet.overrideScope editableOverlay;

        virtualenv = editablePythonSet.mkVirtualEnv "cad-dev-env" workspace.deps.all;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "cad-dev";

          packages = nativeLibs ++ [
            virtualenv
            pkgs.uv
          ];

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeLibs;

          env = {
            UV_NO_SYNC = "1";
            UV_PYTHON_DOWNLOADS = "never";
          };

          shellHook = ''
            echo "🚀 Entering CAD development shell (build123d + yacv-server via uv2nix + novtk)"
            export REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
            unset PYTHONPATH

            echo "✅ Pure Nix environment ready (using cadquery-ocp-novtk – no VTK)"
            echo ""
            echo "Commands:"
            echo "  python object.py                  # run your model + YACV server"
            echo "  uv add <pkg> && nix develop       # after changing pyproject.toml"
            echo "  uv run python -c 'import build123d; print(\"✅ OK\")'"
            echo ""
            echo "YACV remote access: export YACV_HOST=0.0.0.0"
          '';
        };
      }
    );
}
