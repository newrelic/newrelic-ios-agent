#!/bin/zsh
# Serves the captured snapshots at http://localhost:8765/<id>.html for the simulator.
cd ${0:A:h}/pages && exec python3 -m http.server 8765 --bind 127.0.0.1
