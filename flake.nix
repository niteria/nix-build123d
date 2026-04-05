{
  description = "CAD development environment for build123d + yacv-server (reusable)";

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
    let
      perSystem = flake-utils.lib.eachDefaultSystem;
    in
    {
      templates = {
        extend = {
          path = ./templates/extend;
          description = "Template for extending the CAD base";
        };
      };
    }
    // perSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

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

        ocpOverlay = final: prev: {
          cadquery-ocp = final.cadquery-ocp-novtk;
          ocp = final.cadquery-ocp-novtk;
        };

        pythonSet = pythonBase.overrideScope (
          pkgs.lib.composeManyExtensions [
            pyproject-build-systems.overlays.wheel
            pyprojectOverlay
            ocpOverlay
          ]
        );

        # Separate overlays for different use cases
        editableOverlay = workspace.mkEditablePyprojectOverlay {
          root = "$REPO_ROOT";
        };

        # Python set WITH editable - for local devshell
        editablePythonSet = pythonSet.overrideScope editableOverlay;

        # Use workspace.deps.default directly - should now include both base + watchdog-extension
        workspaceDeps = workspace.deps.default;

        # Create virtualenv with all workspace deps (no more overrideAttrs hack!)
        virtualenv = editablePythonSet.mkVirtualEnv "cad-dev-env" workspaceDeps;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "cad-dev";

          packages = [
            virtualenv
            pkgs.uv
          ];

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeLibs;

          env = {
            UV_NO_SYNC = "1";
            UV_PYTHON_DOWNLOADS = "never";
          };

          shellHook = ''
            export REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
            unset PYTHONPATH

            echo "🚀 Entering CAD development shell"
            echo ""
          '';
        };

        packages = {
          cadPythonEnv = virtualenv;
          cadPythonSet = editablePythonSet;
          cadPythonSetNoEditable = pythonSet;
          cadWorkspace = workspace;
          cadPyprojectOverlay = pyprojectOverlay;
          cadEditableOverlay = editableOverlay;
          nativeLibs = nativeLibs;
          pyproject-build-systems = pyproject-build-systems;
          uv2nix = uv2nix;
          pyproject-nix = pyproject-nix;

          # Helper for extending repos
          mkCadDevShell =
            {
              extraWorkspaces ? null,
            }:
            let
              extWorkspace =
                if extraWorkspaces != null then
                  uv2nix.lib.workspace.loadWorkspace { workspaceRoot = extraWorkspaces; }
                else
                  null;
              extOverlay =
                if extWorkspace != null then
                  extWorkspace.mkPyprojectOverlay { sourcePreference = "wheel"; }
                else
                  null;
              extEditableOverlay =
                if extWorkspace != null then
                  extWorkspace.mkEditablePyprojectOverlay { root = "$REPO_ROOT"; }
                else
                  null;
              extSet =
                if extOverlay != null then
                  pythonSet.overrideScope (
                    pkgs.lib.composeManyExtensions [
                      pyproject-build-systems.overlays.wheel
                      extOverlay
                      extEditableOverlay
                    ]
                  )
                else
                  pythonSet;
              extDeps = if extWorkspace != null then extWorkspace.deps.default else { };
              combinedDeps = workspace.deps.default // extDeps;
            in
            pkgs.mkShell {
              name = "cad-dev";
              packages = [
                (extSet.mkVirtualEnv "cad-dev" combinedDeps)
                pkgs.uv
              ];
              LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeLibs;
              env = {
                UV_NO_SYNC = "1";
                UV_PYTHON_DOWNLOADS = "never";
              };
              shellHook = ''
                export REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
                unset PYTHONPATH
                echo "🚀 CAD dev shell"
              '';
            };
        };
      }
    );
}
