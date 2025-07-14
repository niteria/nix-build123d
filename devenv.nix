{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  buildInputs = with pkgs; [
    stdenv.cc.cc
    libuv
    zlib
    libGL
    xorg.libX11
    xorg.libXrender
    expat
  ];
in

{
  env = {
    LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}";
  };
  languages.python.enable = true;
  languages.python.uv.enable = true;
  languages.python.uv.sync.enable = true;
  enterShell = ''
    . .devenv/state/venv/bin/activate
  '';

  enterTest = ''
    uv run python -c 'import build123d'
  '';

}
