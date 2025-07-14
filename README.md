Environment for running https://github.com/yeicor-3d/yet-another-cad-viewer and https://github.com/gumyr/build123d for CAD development.

# Running

## Enter shell

### With direnv

Install direnv. I install mine in home-manager.
Add to bashrc: https://direnv.net/docs/hook.html

### Without direnv

```
devenv shell
```

## See the model

```
python object.py
```
It will log the url to open with the browser.

# Acknowledgements

Based on https://github.com/clementpoiret/nix-python-devenv
