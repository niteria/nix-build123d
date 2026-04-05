{
  description = "CAD development environment for build123d + yacv-server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # Allow unfree if needed for any CAD-related packages in the future
          # config.allowUnfree = true;
        };

        # Same build inputs as your devenv.nix
        buildInputs = with pkgs; [
          stdenv.cc.cc
          libuv
          zlib
          libGL
          libX11
          libXrender
          expat
        ];

        # Python 3.12+ as required by pyproject.toml
        python = pkgs.python312;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "cad-dev";

          buildInputs = buildInputs ++ [
            python
            pkgs.uv # UV package manager (replaces pip + venv management)
          ];

          # Same LD_LIBRARY_PATH as your devenv setup (critical for build123d's native extensions)
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;

          # Automatic setup on `nix develop` (mirrors your devenv + uv.sync + enterShell)
          shellHook = ''
            echo "🚀 Entering CAD development shell (build123d + yacv-server)"

            # Tell UV to use the exact Python version from Nix
            export UV_PYTHON=${python}/bin/python
            export UV_PYTHON_PREFERENCE=only-managed

            # Create/sync the virtual environment exactly like `uv sync` + devenv does
            if [ ! -d .venv ]; then
              echo "Creating UV virtual environment and syncing dependencies..."
              uv sync --frozen
            else
              echo "Syncing UV virtual environment (use 'uv sync' manually if you change pyproject.toml)..."
              uv sync --frozen --no-install-project
            fi

            # Activate the venv (exactly like your enterShell)
            source .venv/bin/activate

            # Optional: make sure the test import works immediately
            if command -v python >/dev/null; then
              if python -c "import build123d" 2>/dev/null; then
                echo "✅ build123d is importable"
              else
                echo "⚠️  build123d import failed – run 'uv sync' manually"
              fi
            fi

            echo ""
            echo "Commands available:"
            echo "  python object.py          # run your model + YACV server"
            echo "  uv sync                   # update venv after changing dependencies"
            echo "  uv run python -c 'import build123d'"  # test import
            echo ""
            echo "YACV remote access: export YACV_HOST=0.0.0.0"
          '';
        };
      }
    );
}
