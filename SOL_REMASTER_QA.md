# Sol High Remaster v2 — QA status

Date: 2026-10-01
Branch: `sol-high-remaster-v2`

## Previous prototype status
Rejected. It was too blockout-heavy, shallow, and insufficiently tested.

## Rebuild scope completed
- Rebuilt game structure as a denser Three.js vertical slice.
- Added authored procedural PC internals: motherboard, RAM, GPU, PSU, CRT, cables, CMOS battery and repair bench.
- Added CMOS repair interaction flow rather than a single click.
- Added Ms. Ellis, Capacitor the cat, Oleg, hotel staff/guests and security patrols.
- Added cinematic camera shots and branching briefing dialogue.
- Added shop -> flight -> hotel -> service corridor -> B2 server mission progression.
- Added badge cloning, cover/focus systems, crouch detection, service-door access and ORCHID maintenance puzzles.
- Added procedural WebAudio SFX/ambience and browser TTS fallback.
- Added mobile dual-stick controls, USE/CROUCH/SCAN, quality modes and collision handling.

## QA fixes made before delivery
- Fixed storefront entrance geometry so the front door is no longer embedded in the facade wall.
- Fixed hotel service-wall gaps that allowed bypassing the locked door.
- Added collision to locked doors and remove collision only when they open.
- Fixed keyboard crouch sticking after Control release.
- Fixed cinematic sequences unlocking movement between camera shots.
- Fixed NPC path completion logic.
- Fixed overlapping exterior asphalt/floor geometry.
- Fixed missing car materials: tire, headlight, rear light.
- Fixed Three.js runtime reference: classic `build/three.min.js` was removed after r160, so the classic build uses r160.
- Re-ran DOM ID checks and material dependency checks: no missing references found.
- Re-ran JavaScript syntax validation with `node --check`: passed.

## Known limitation
The HTML contains all game-authored assets and logic, but Three.js itself is loaded from jsDelivr as the rendering library. No external model, texture, music or sound asset is used.
