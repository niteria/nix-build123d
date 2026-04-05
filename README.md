# CAD Development Base

Base Nix flake for CAD development with build123d, cadquery-ocp-novtk, and yacv-server.

## Quick Start

```bash
# Enter development shell
nix develop

# Run the example
python object.py
```

The `object.py` script will print a URL - open it in your browser to see the 3D model.

## YACV Configuration

YACV (Yet Another CAD Viewer) can be configured with environment variables:

```bash
# Enable remote access (e.g., for running on a remote server)
export YACV_HOST=0.0.0.0

# Default is localhost - no changes needed for local use
```

## Using the Template

Create a new extending project using the template:

```bash
# 1. Create your extending project from template
nix flake init -t github:niteria/nix-build123d#extend

# 2. Edit pyproject.toml to add your dependencies

# 3. Generate uv.lock (requires Nix shell with uv)
nix-shell -p uv --run "uv lock"

# 4. Enter dev shell with base + your deps
nix develop
```

## How It Works

- **Base repo** provides a `mkCadDevShell` function that:
  1. Loads the base Python set (build123d, cadquery-ocp-novtk, yacv-server)
  2. Loads your extra workspace from `extraWorkspaces` path
  3. Creates a virtualenv with all combined dependencies
  4. Returns a devshell

- **Two separate uv.lock files** - base has its own, your extension has its own
  - Base: build123d + cadquery-ocp-novtk + yacv-server
  - Extension: whatever you add in your pyproject.toml

## Architecture

```
nix-build123d-flake/          # Base repo
├── flake.nix                 # Provides mkCadDevShell helper
├── pyproject.toml            # Base dependencies
├── uv.lock                   # Base's locked deps
├── object.py                 # Example CAD script
└── util.py                   # Helper for generating filenames

my-cad-project/               # Your extending repo
├── flake.nix                 # Calls mkCadDevShell
├── pyproject.toml            # Your extra dependencies  
└── uv.lock                   # Your locked deps
```