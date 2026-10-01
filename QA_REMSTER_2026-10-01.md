# Three.js Remaster QA Log — 2026-10-01

## Build scope completed
- Single HTML playable vertical slice, Three.js renderer
- Shop opening, Ms. Ellis repair interaction, Oleg briefing and branching dialogue
- Loadout selection, hotel infiltration, badge-clone objective, sublevel/server-room mission
- Hardware/service puzzle with multiple approaches and three ending choices
- Runtime-authored meshes/materials/signage; procedural WebAudio SFX/ambience
- Keyboard/mouse plus dual-stick touch controls, USE and CROUCH buttons
- Collision checks, performance tiers, subtitles, pause/restart UI, focus/cover state
- Browser speech synthesis fallback so the build remains playable with no secret in client code

## Static QA performed
- JavaScript parsed successfully with Node `--check`
- HTML script tags balanced
- Curly/round/square delimiter counts balanced
- Required scene functions and mobile input paths present
- Main branch intentionally left untouched

## Known limitations / follow-up
1. OpenAI TTS assets were not generated because the prompt contained no actual API key value.
2. A secret must never be hard-coded into a public single-file client build. Production OpenAI TTS should be generated ahead of time or proxied server-side.
3. Current HTML imports the Three.js library from jsDelivr; all *game assets* are procedural/original, but the engine library is external.
4. Browser-TTS voices vary by device and are a fallback, not final cinematic voice direction.
5. Runtime smoke-testing should be repeated on Android Chrome after deployment because local-file/browser WebGL and autoplay policies differ by device.

Tracking issue: #1
