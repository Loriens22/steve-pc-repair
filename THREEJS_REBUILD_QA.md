# Three.js Kestrel Rebuild — QA Log

Date: 2026-10-01

This branch tracks the new single-file Three.js vertical-slice requested for **Steve The PC Repair Man**. The playable HTML artifact is being delivered in the ChatGPT task; this file records what was checked against the repository's earlier Godot build and what is still unverified.

## What was deliberately improved

- Replaced the generic "take down an asset" beat with the **Kestrel Node** job: a covert hardware relay in a Tallinn hotel server room. The mission is technical/stealth-focused rather than a generic shooter.
- Preserved the opening CMOS-battery repair with Ms. Ellis and made the CR2032 cabinet explicitly labelled and interactable.
- Mobile controls reserve separate areas for movement, camera look, USE, SCAN, CROUCH and menu/binder.
- Main furniture, workbenches, parts cabinet, server racks, service cart, walls and the locked B2 doorway use collision bounds.
- The B2 service door remains physically blocked until the maintenance-panel puzzle is solved.
- Hotel cameras now include an occlusion check so they do not simply detect through collision walls.
- All models, signage textures, sounds and ambient music are procedural/in-code. Three.js is the only external runtime library.
- Dialogue has subtitles and an optional OpenAI Speech API path using `gpt-4o-mini-tts`; no API key is committed or stored.
- The game includes a device-speech fallback so the story remains playable when API TTS is unavailable.
- OpenAI TTS playback is explicitly disclosed as AI-generated in the voice settings UI.

## Regression lessons taken from existing repo history

Recent commits fixed:
- Ms. Ellis walking into a wall.
- A mobile HUD counter appearing off-screen.
- The chapter-one CMOS battery drawer being hard to find/use.

The rebuild therefore avoids scripted NPC collision during the playable repair step, keeps phone action buttons inside safe-area-aware HUD zones, and starts with a clearly named CR2032 objective.

## Checks completed

- JavaScript syntax validated with `node --check`.
- All JavaScript `#id` selector references were checked against declared DOM IDs: no missing selectors found.
- A first-pass escaping bug in a shop sign/dialogue string was caught by the syntax check and fixed before delivery.
- Major scenery collision pass added after review.
- Locked-door progression and camera occlusion were added after review.
- No TODO markers left in the delivered source.

## Known limitation / not falsely marked as verified

A headless Chromium runtime smoke test could not initialize WebGL/ANGLE in the current container (EGL/XCB initialization failure). That is an environment limitation, not a passed gameplay test. The build should still be tested on the target Android Chrome device for:
- WebGL startup and CDN access to Three.js.
- Long-touch camera feel.
- OpenAI TTS browser CORS behavior when a session key is supplied.
- Thermal/performance behavior in High quality mode.
- Full objective flow from Ms. Ellis repair -> Oleg briefing -> B2 puzzle -> Kestrel timing game -> service lift.

## Security note

Do **not** commit an OpenAI API key into this public repository or hard-code it in the HTML. For a deployed build, route TTS through a trusted server-side endpoint. The single-file demo only accepts an optional session key in RAM for direct experimentation.
