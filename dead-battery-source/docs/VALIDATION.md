# Validation

The first-person rebuild was checked in Godot 4.6.3 and Chromium with WebGL 2. Tests use actual level collision and real held-tool actions rather than accepting UI completion flags.

## Complete mission

`docs/mission_test.gd` traverses every required room and doorway, aims from the player's eye through physics ray occlusion, selects tools and holds actions through the actual task state machine. The final run passed **179 checks**:

- PC mains isolation, wrong-tool rejection, meter test, four screws, panel movement, clip, replacement cell, refitting, tightening, reconnection and boot validation.
- Generated dialogue and captions, paid briefcase, travel and service access.
- Wrong feed, correct feed, C3 isolation, missed diagnostic pulse and successful loop bridge.
- Rated fuse, pump, supply/return/bypass, calculated flow and pressure, temperature and thermal interlock.
- Asynchronous copy, premature retrieval rejection, verified evidence and vault access.
- Live dual-UPS rejection, isolation, zero-volt verification, tamper screws, cover and key zeroization.
- Actual rack geometry blocking surveillance; unobstructed detection; an actual alarm, checkpoint return and fifteen-second penalty.
- A climb through the roof aperture, roof traversal, extraction, voiced ending, completion and save data.
- Stable camera field of view and carried-tool position after one-second frames.

Surveillance has separate deterministic visibility/alarm assertions; it is suppressed during the route traversal so that every doorway can be tested independently. Godot's headless runner reports resource-cache warnings at shutdown. No gameplay script errors occurred.

## Browser and mobile input

`tools/browser_qa.py` checks the compiled browser game. Progress fixtures are produced by the native mission run. Runtime state is observed through a diagnostic bridge; gameplay is driven through keyboard, mouse, and real Chromium CDP touch events, without engine setters.

- Actual mouse looking, keyboard tool changes, held E actions, battery work and moving-panel refit.
- Two simultaneous touches produce both player movement and camera rotation.
- Touch crouch/stand, tool-menu selection, held ACT, clip release and cell fitting.
- Portrait 390 × 844 and landscape 844 × 390 layouts, with a minimum 44 CSS-pixel action target in landscape.
- Voiced scene advancement and skipping, subtitles and measured audible browser audio output.
- Rendered shop, character dialogue, chiller, root vault and roof frames, reviewed visually.
- No browser page errors or Godot gameplay script errors.

The browser runs here use SwiftShader software rendering. They verify functionality and images, and do not represent hardware performance on a physical phone. Battery, Balanced and High graphics settings are available in the game.

## Reproduce

```sh
# From the project root, with Godot 4.6.3 and web export templates installed:
bash tools/build.sh
godot --headless --path . --script docs/mission_test.gd
python3 -m http.server 8081 --directory web
# In a second shell, with Playwright and Chromium installed:
python3 tools/browser_qa.py
```

## Published build

The [GitHub Pages game](https://loriens22.github.io/steve-pc-repair/dead-battery/?v=first-person) passed its public browser smoke test after publication:

- Actual first-person walking, mouse looking, crouching and tool changes.
- Boot verification, generated cinematic dialogue with measured audible output, caption advancement and scene skipping.
- Simultaneous independent touches for walking and looking, precision-pick selection and a held ACT repair on the actual battery clip.
- Portrait and landscape control layouts, tool selection and a minimum 44 CSS-pixel ACT target.
- No failed asset requests, browser page errors or Godot gameplay script errors.

Each downloaded part was checked against its SHA-256. The assembled 54,564,136-byte pack matches the exact locally tested game: `fa50bc9ded8706195e5ee71dae71afe05285be5887ce3c7ea3faf6a8c6cfbb69`. Content-addressed download parts prevent older cached packs from loading. The repository's main play page opens this first-person version.

The software-rendered local packaging smoke test initially tapped a landscape control before resize had settled; the input driver now waits for the actual viewport aspect ratio before targeting the resized controls. The public suite completed successfully. These checks establish browser and touch functionality, rather than physical-phone performance.

