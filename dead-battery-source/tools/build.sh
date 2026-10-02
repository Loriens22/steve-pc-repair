#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "--assets" ]]; then
  python3 tools/create_materials.py
  blender --threads 4 --background --python tools/create_world.py
  python3 tools/optimize_models.py
fi
godot --headless --editor --path . --import
godot --headless --path . --export-release Web web/index.html
mv web/index.pck web/first-person.pck
python3 tools/package_web.py
cp assets/fonts/workshop_ui.ttf web/workshop_ui.ttf
rm -f web/index.png web/workshop.ttf
