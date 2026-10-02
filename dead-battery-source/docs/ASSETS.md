# Original asset provenance

The Blender scenes, all game geometry and artwork were authored for Steve The PC Repair Man. There are no downloaded stock assets or asset-library dependencies.

- `tools/create_world.py`: modeled rooms, office park, car, CRT, individual keyboard keys, PC board and components, moving screws and panels, case, phone, tickets, shelves, chairs, props, server cabinets and rack hardware, conduit, fuse cart, pump, gauges, valves, archive, HSM, UPS, ladder, roof, HVAC, skyline, anatomical characters, BIOS the cat, gloved hand and tools, patrol drone. Measurements are in meters. Bevels, normal maps, roughness and metallic surfaces are authored in the Blender pipeline.
- `tools/create_materials.py`: seeded mathematical PBR textures for plaster, vinyl, wood, steel, aluminium, enamel, plastic, concrete, asphalt, rubber, fabric, skin, paper and circuit board; original printed notes and display art. Workshop Sans and its UI weight were constructed from original stroke geometry and exported as TrueType fonts.
- `tools/optimize_models.py`: byte-identical texture deduplication. This changes storage and references, without changing geometry, surface maps or materials. Shared image hashes are recorded in `assets/textures/shared_manifest.json`.
- `tools/create_audio.py`: new dialogue performances, footsteps, tool sounds, relay, fan, ventilation and drone. Effects are synthesized from oscillators and seeded noise. The included earlier score, chime, alarm, purr and other effects were likewise synthesized for this game's previous build; their generator is `tools/create_legacy_audio.py`. Speech is newly generated from the original script with distinct Guy, Sonia, Ryan and Aria voice performers through edge-tts; these are generated performances, not stock recordings.
- `scripts/world.gd`: original procedural sky, local lighting, reflections, rain and level collision.
- `scripts/hud.gd`: original interface, vector reticle, virtual stick, service floor plan, captions, menus and graphics controls.
- `assets/icon.svg`: original game symbol; web favicons are derived from it.

The game uses Blender and the Godot engine, as requested. Engine binaries and open-source runtime dependencies are software rather than game artwork. Their notices are in `web/`. The default Godot splash image is disabled and removed from the exported website.

The water-loop puzzle uses the energy balance ΔT = 4000 W / (4184 J/kg/K × water mass flow). Return/supply/bypass settings change flow and pressure continuously, with a thermal settling response. Walking uses capsule collision and 9.81 m/s² gravity. Surveillance traces rays through the same level collision geometry. These support believable gameplay; this is a fictional repair and stealth adventure.
