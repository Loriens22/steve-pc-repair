# Original asset record

Visual source: `tools/create_world.py`, deterministic random seed 98, authored and run in Blender 4.3.2.

| Original Blender scene | Game export | Contents |
| --- | --- | --- |
| shop.blend | shop.glb | Cutaway office-park shop, counter, CRTs, repair benches, pegboard tools, motherboard, storage, coffee station, waiting area, cat accessories, car, signs and small details |
| vault.blend | vault.glb | Meridian server vault, modular racks, coolant system, core, magnetic gate, maintenance cart, extraction lift, skyline and details |
| steve.blend | steve.glb | Steve, rigged with arm and leg pivots for procedural animation |
| ellis.blend | ellis.glb | Ms. Ellis, glasses, pearls, hair bun and limb pivots |
| oleg.blend | oleg.glb | Oleg, suit, tie, dark glasses and limb pivots |
| bios.blend | bios.glb | Tabby cat, triangular ears, paws, eyes, whiskers and curved tail |

Dynamic original geometry authored in Godot: patrol drone, sight cone, magnetic beams and rain particles. Physics bodies approximate walkable environment geometry with measured box and capsule colliders. Static environmental meshes are combined by material to reduce draw calls.

Audio source: `tools/create_audio.py`. Original NumPy synthesis creates door chime, UI click, confirmation, error, footsteps, purr, door, alarm, shutdown and two 48-second music loops. No prerecorded audio samples are used.

Thirty-six newly generated dialogue performances cover the opening, vault arrival, core confrontation and ending. Steve, Ms. Ellis, Oleg and Meridian have distinct generated voices. Subtitles and timing are exported in `assets/dialogue.json`.
