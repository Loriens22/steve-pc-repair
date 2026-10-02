# Steve The PC Repair Man — First Person

**Case 01: Dead Battery** is a complete first-person repair and stealth chapter, built in Blender 4.3.2 and Godot 4.6.3. All game artwork, environments, characters, models, surface maps, typefaces, music, effects and dialogue performances were created for this game.

[Play in your browser](https://loriens22.github.io/steve-pc-repair/dead-battery/?v=first-person)

Steve keeps old PCs alive for customers other shops overcharge. Oleg's next contract is paid entirely up front: take down Widowmaker, a battery-backed signing key in Meridian's Tallinn facility. Eight million stolen pension records are about to be auctioned. Ms. Ellis is among them. Secure the evidence, destroy the key, and come home to BIOS.

The rebuilt game uses a player-height camera and a colliding first-person controller. Repairs happen on the actual hardware: remove screws and panels, isolate power, use the meter, release clips, replace a cell and validate boot. The facility adds a timed camera-loop bridge, fuse selection, a physically based chilled-water flow and pressure puzzle, a background evidence copy, dual UPS isolation, tamper hardware, line-of-sight surveillance and a roof escape. Eight discoveries connect the ordinary shop to the night job.

## Controls

| Action | Desktop | Phone |
| --- | --- | --- |
| Walk | WASD / arrows | Left thumbstick |
| Look | Mouse; right-drag if capture is unavailable | Swipe right side |
| Use tool | Hold E / left mouse | Hold ACT |
| Tool selection | 0–6, wheel, or Tab | TOOLS |
| Run | Shift | RUN toggle |
| Crouch | C | DUCK toggle |
| Torch | F | LIGHT |
| Jump | Space | UP |
| Inspect closer | Right mouse | Approach the object |
| Case / hints / floor plan | J / CASE | CASE |
| Pause / audio / sensitivity / graphics | Esc / II | II |
| Advance dialogue | Space / Enter / NEXT LINE | NEXT LINE |

Walking, looking and holding ACT use separate touch IDs. Portrait and landscape layouts reserve space above the screen edge. Menus scroll on touch. Graphics have Battery, Balanced and High settings; the interface stays sharp when the 3D render scale changes. Progress and preferences save on this device.

## Build

Open `project.godot` in Godot 4.6.3, or run:

```sh
bash tools/build.sh
python3 -m http.server 8081 --directory web
```

Open http://localhost:8081. Serve over HTTP; the WebAssembly build cannot be opened as a local HTML file. The single-threaded WebGL 2 export works without cross-origin isolation headers. GitHub Pages serves the same build.

To regenerate the Blender assets and original material library:

```sh
python3 -m pip install numpy scipy Pillow fonttools shapely
bash tools/build.sh --assets
```

`tools/create_legacy_audio.py` regenerates the score, effects and original scene performances. Then `tools/create_audio.py` regenerates the first-person mission performances and effects. Run them in that order with Python, ffmpeg and edge-tts. It needs network access for speech synthesis. The committed audio is ready to play. The opening, core and ending performances were also generated specifically for this game and are included.

`blender/` contains seven editable, packed, compressed Blender files. GLB geometry in `assets/models/` references deduplicated original PNGs in `assets/textures/shared/`. Keep those folders together. Geometry, materials, rigs, collision boxes and generated placards are reproducible from the tools. No stock artwork, models, music, recordings or fonts are used.

The browser downloads the unchanged Godot pack in three content-addressed parts, which fit GitHub's upload limits. The loader assembles them directly in memory while the engine loads; the progress bar covers both downloads. `tools/package_web.py` regenerates the manifest and parts after export. The browser folder does not need the unsplit `first-person.pck` file.

See [asset provenance](docs/ASSETS.md) and [validation](docs/VALIDATION.md). Godot and its third-party runtime notices are included in the browser build. Game assets are separate from the open-source engine.
