# Steve The PC Repair Man

**Case 01: Dead Battery** — an original 3D cinematic stealth adventure created with Blender 4.3.2 and Godot 4.6.3.

Steve repairs old computers for people other shops overcharge. Tonight Oleg brings a contract, paid entirely up front: take down the Widowmaker, a signing-key asset inside Meridian's Tallinn data vault. Steve discovers Ms. Ellis among eight million stolen pension records. He decides to secure the evidence before destroying the key.

## Play

Serve the `web/` directory over HTTP:

```sh
python -m http.server 8080 --directory web
```

Open http://localhost:8080 in a recent browser with WebGL 2. The WebAssembly build cannot run by opening the HTML as a local file. The export is single-threaded and does not require cross-origin isolation headers.

| Action | Desktop | Phone |
| --- | --- | --- |
| Move | WASD / arrows, or click the floor | Virtual stick, or tap the floor |
| Walk and inspect | Click a prop's `+` marker | Tap a prop's `+` marker |
| Nearby interaction | E | ACT |
| Hurry | Shift | HURRY |
| Orbit camera | Hold right mouse and drag | Use the default follow camera |
| Zoom | Mouse wheel | Default zoom adapts to the screen |
| Case file | J / CASE FILE | CASE FILE |
| Pause and audio | Esc / II | II |
| Advance dialogue | Space / Enter / next-line button | Next-line button |

Cutscenes play generated character voices with synchronized subtitles. Individual lines and complete scenes can be skipped. Progress and audio preferences are stored on this device.

## Mission and optional discoveries

Explore Steve's repair shop, inspect Oleg's briefcase, and travel to Tallinn. Collect the service identity, reroute surveillance, balance coolant pressure, back up the evidence, isolate the signing key, remove its battery and reach the extraction lift. Return to the shop for the ending.

The patrol drone sees inside its red cone. Server racks occlude its line of sight. Detection returns Steve to his maintenance cover while preserving completed puzzles. Eight optional discoveries reward inspection across both locations.

## Editable source

Open `project.godot` in Godot 4.6.3. Original editable Blender scenes are in `blender/`; their game-ready GLBs are in `assets/models/`.

- `tools/create_world.py` creates all environmental, human-character and cat geometry from scratch in Blender.
- `tools/create_audio.py` creates the score and effects mathematically and generates new dialogue performances.
- `scripts/game.gd` handles movement, physics, pathfinding, camera, dialogue, mission, drone and saves.
- `scripts/hud.gd` handles responsive controls, menus, subtitles and prop markers.
- `scripts/puzzles.gd` implements the three repair puzzles.
- `tools/playtest.py` drives the exported browser game through its visible controls for mission and phone checks.

Regenerate the visual assets:

```sh
blender -b --python tools/create_world.py
```

The generators locate this project relative to their own files. The audio generator requires Python, NumPy, edge-tts, and FFmpeg. Install Godot's 4.6.3 export templates before exporting:

```sh
godot --headless --path . --export-release Web web/index.html
```

## Asset provenance

Every mesh, sign and environmental detail was authored for this game using its Blender generator. Both locations, three human characters and BIOS the cat are original. There are no downloaded models, image textures, music tracks or sound samples. The music and effects are mathematical synthesis. The story and dialogue are original, and the voices are newly generated performances using distinct neural voices.

Godot, Blender, the voice-synthesis engine, browser fonts and the WebAssembly runtime are software dependencies. The design uses a detailed stylized diorama, with PBR materials, shadows, collision, gravity and an occluded security sightline.
