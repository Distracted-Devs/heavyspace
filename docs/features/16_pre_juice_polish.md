# pre_juice_polish
Started 2026-11-24. The live phase is in `.claude/bin/feature status`.

## Idea
What the user imagines, in their words: how it should look, feel and play.

"We're going to clean up some things before working on proper juice"
- Add a pause menu that shows controls.
- When showing controls, switch between controller and keyboard and mouse
  depending on what's active.
- Use the icons in `resources/input_icons/` (coloured default Xbox for the
  controller, dark for the keyboard and mouse). Use the input texture SVGs
  (`resources/input_textures/`) to show the layout of the active device and
  put in the control for each button. When showing e.g. "X to boost", use
  the icons.
- Add jitter to the ring body positions so it doesn't look like they spawned
  on a grid. Make sure they don't overlap, by ensuring the body + jitter max
  is within the cell size.
- Make sure the player spawns facing the nearest planet.
- Make the player slightly bigger.
- When the player is fast, the blue_thrust is barely seen. Spawn more of it
  and have it follow the player more closely.

(The assets were renamed into `resources/input_icons/<device>/<style>/` and
`resources/input_textures/{controller,keyboard}_layout.svg` before the
prototype started, committed in e140d26.)

## Prototype log
One line per iteration: what changed and what the user said about it.

- v1: pause menu (Resume/Restart/Quit) with the active device's layout
  picture and icon labels from the input map; ring bodies jittered within
  cell − diameter; spawn faces the nearest planet; ship ×1.3 (collider too);
  thrust 90 particles, 0.8 s, inheriting the ship's velocity. User: yes to
  device-aware icon prompts for the shop hints and the crash message too.
- v2: shop hints (move/buy/zoom/warp) and the crash message use icon
  prompts read from the input map; one device tracker that runs while
  paused drives every prompt. User (after trying v1): remove the unused
  leader lines from the controller picture and make the icons all the same
  size. So unbound slots' lines are cut from the SVG, and icons are shown
  whole on the pack's shared 128 px canvas at one square size (cropping
  had made wide and arrowed icons a different scale); only keyboard key
  caps are still cropped, to fill their keys.
- User on v2: "Great, amazing." Next: play the warp in reverse when warping
  in; ring bodies pop (retexture or transform change?) at pickup distance;
  streamed-in bodies pop in, so ease their scale in; crash screen in the
  holo/vaporwave theme; a tutorial (step-by-step controls waiting for each
  input: turning and camera, then boost; then arrows to the nearest planet
  and the cargo, "mine your quota"); every run, highlight the warp-out
  prompt once there's enough mass; first shop, highlight how to buy the
  first item; every shop, highlight warp in once nothing's left to buy.
- v3: warp in = WarpEffect's curves played backwards at every run start.
  The pop was two things: the proxy draws its surface in the ring's
  (randomly tilted) frame while the live body was world-aligned, and the
  proxy sphere was 12 segments against the live 64. Live meshes now turn to
  the ring's frame and proxies use 64 segments (GPU cost to check in perf).
  New rings grow in over 0.6 s (ease 2.0, via instance scale only). Crash
  screen rebuilt as a holo panel. Tutorial (once per session): pitch, yaw,
  roll, look, boost, each held until a bar fills, then "MINE YOUR QUOTA"
  with a planet reticle/edge arrow and an arrow at the mass tanks until the
  first pickup. Every run: pulsing "QUOTA MET / WARP OUT" prompt at the
  bottom. Shop: BUY tag over the first buyable item until the first buy;
  pulsing WARP IN with an arrow once nothing can be bought.

## Accepted behaviour
Filled in before acceptance. This is the spec for the rewrite: the behaviours
to keep, the tuned values the user liked, and what was tried and dropped.
From `prototypes/pre_juice_polish/` (`main.gd`, `pause_menu.gd`,
`input_icons.gd`, `device_tracker.gd`, `prompts.gd`, `tutorial.gd`,
`warp_in.gd`, `holo.gd`, `polish_streamer.gd`, `polish_pool.gd`,
`polish_spawn.gd`), v3. The user accepted v3 as it was; no values were
retuned.

### Keep
- **Active device, everywhere.** One tracker follows the device used
  last, and keeps running while paused and in the shop: a key, mouse
  button or mouse motion means keyboard and mouse; a pad button, or a
  stick or trigger past the dead zone (0.2), means controller. Every
  prompt and the pause menu switch the moment it changes.
- **Icons from the input map.** Each prompt is a list of actions; its
  icons are read from their bindings for the active device, so they stay
  right if bindings change. Controller: `resources/input_icons/xbox/default/`
  (coloured A/B/X/Y). Keyboard and mouse:
  `resources/input_icons/keyboard_mouse/dark/`. Mouse look isn't an
  action, so it's shown with `mouse_xy`.
  - Sets that do one job merge into one icon: the four d-pad directions →
    `dpad`; a stick's four directions → `l_2d`/`r_2d`, up+down → `l_y`,
    left+right → `l_x`; wheel up+down → `mouse_scroll`. The arrow keys are
    dropped when other keys (WASD) are bound too.
  - Icons are shown whole on the pack's shared 128 px canvas at one square
    size, so buttons, triggers and sticks keep one scale. Only keyboard
    key caps on the keyboard picture are cropped to their visible pixels,
    so wide keys (Shift, Space) fill their keys.
- **Pause menu** (replaces the "Paused" label): `// PAUSED` title, a
  controls panel and RESUME / RESTART / QUIT buttons. Resume is focused on
  open; pad B also resumes. The panel is the same size for both devices.
  - Controller: `controller_layout.svg` with the leader lines recoloured
    cyan. Each bound control's icon and action name sit at the end of its
    line (left side right-aligned, right side left-aligned); the lines of
    unbound controls are removed. A stick's axes are grouped: pitch on Y
    and yaw on X show as `[l_y] Pitch [l_x] Yaw`; look on both axes as
    `[r_2d] Look`.
  - Keyboard: `keyboard_layout.svg` with cyan outlines. Each bound key is
    outlined magenta on a cyan glow, with its key cap and a short caption
    (`Pitch ↓`, `Yaw ←`, `Roll →`, `Boost`, `Warp out`, `Restart`).
    Bindings that aren't on the picture (Esc, mouse look) are listed
    underneath.
- **Shop hints** become icon prompts: `[W][A][S][D] MOVE`, `[Enter] BUY`,
  `[Q][E][wheel] ZOOM`, and the WARP IN button gets the `warp_out` icon.
  On a pad: `[dpad][l_2d] MOVE`, `[A] BUY`, `[LT][RT] ZOOM`, `[X]`.
- **Crash screen** in the holo look: a dimmed, magenta-scanlined backdrop
  and a magenta-bordered panel with `// CRASHED`,
  `HULL BREACH: YOU HIT SOMETHING HEAVIER` and a pulsing `[R] RESTART`
  prompt.
- **Warp out prompt, every run:** once the warp is ready
  (`WarpController.can_warp()`), a pulsing magenta panel at the bottom
  reads `QUOTA MET` / `[X] WARP OUT >>`. Hidden while warping, crashed
  or in the shop.
- **Shop guidance:** until anything has ever been bought, a bouncing
  `[A] BUY ▼` tag sits over the first buyable node and the BUY hint
  pulses. On every shop screen where nothing can be bought, WARP IN
  pulses with a bouncing `▼` above it.
- **Warp in:** every run starts with the warp-out effect played
  backwards: white, wide (FOV 130), stretched and 400 ahead, easing back
  to the ship in place at the normal FOV over the warp duration.
- **Tutorial, once per game session** (survives restarts and the shop),
  after the warp in, in a cyan holo panel at the bottom:
  1. Flight training, one control at a time: PITCH, YAW, ROLL, LOOK,
     BOOST, each with its icons, a hint and a bar that fills while it's
     held past 0.3. Mouse look fills by distance moved. "NICE!" then the
     next step.
  2. Objective, `MINE YOUR QUOTA` / `FLY INTO BODIES SMALLER THAN YOU TO
     FILL YOUR TANKS`, with a pulsing magenta diamond on the nearest
     planet (or an arrow at the screen edge if it's off screen, with its
     distance), and a gold arrow at the mass tanks gauge (`YOUR QUOTA`).
     After the first pickup: `NICE! KEEP MINING` / `FILL EVERY TANK, THEN
     WARP OUT` for 3 s, then it's done.
  If the run crashes mid-objective, only the objective comes back.
  Hidden while crashed or warping.
- **Ring bodies jitter** anywhere in their cell that keeps the whole body
  inside it (cell minus its diameter), so the grid disappears and bodies
  can't overlap.
- **No pop at live distance:** a live body's surface is turned to its
  ring's frame (the proxy draws in the ring's tilted frame), and the proxy
  sphere has the live sphere's tessellation (64 × 32), so the
  vertex-raised terrain keeps its shape.
- **Streamed-in rings grow in** from nothing to full size over 0.6 s,
  eased in. Only the drawn instance scale changes, so positions and
  pickups are unaffected.
- **Spawn facing:** the ship faces the nearest planet (the nearest root
  child), keeping the ring normal as up.
- **Bigger ship:** the ship's mesh is ×1.3 and its collider grows with
  it, before growth applies.
- **Thrust follows the ship:** 90 particles, 0.8 s lifetime, inheriting
  all of the ship's velocity.

### Tuned values
| value | setting |
|---|---|
| device switch dead zone | 0.2 |
| ring jitter | 1.0 (whole cell minus the body's diameter) |
| grow in | 0.6 s, ease curve 2.0 (ease in) |
| proxy segments | 64 (production was 12) |
| ship scale, collider | ×1.3, scaled too |
| thrust amount / lifetime / inherit velocity | 90 / 0.8 s / 1.0 (were 30 / 1 s / 0) |
| tutorial hold time, threshold | 0.7 s, 0.3 |
| tutorial mouse distance | 600 px |
| tutorial step gap, objective linger | 0.6 s, 3 s |
| planet marker hides within | 150 of the surface |
| prompt pulse | 1.4 Hz, bounce 8 px |
| pause menu controller picture, label column, icon | 420 px, 220 px, 36 px |
| pause menu keyboard picture, legend icon, key caption | 860 px, 36 px, 11 pt |
| pause menu panel | at least 860 × 356 |
| shop hint icons, crash icon, warp-out icon, tutorial icon | 26, 44, 40, 40 px |
| colours | the HUD's cyan, magenta, gold and glass panel (see [skill tree](15_skill_tree.md)) |

### Edge cases noticed
- Cropping icons to their visible pixels makes wide and arrowed icons a
  different scale from round buttons; show the whole canvas instead.
- Godot's SVG renderer draws no text, so the template's own "LT/RT/LS/RS"
  letters don't appear.
- The player's own device tracking stops while paused, so the menu and
  shop need a tracker that keeps running.
- Scaling the renderer node to grow a ring in would scale the CPU-side
  child positions too (pickups, live bodies). Scale the instances only;
  the proxy shader divides its orbit offset by the instance scale.
- A tag waiting outside the tree leaks at exit; keep it parented, hidden.
- A face-button or d-pad leader line is only ~20 px from its neighbours,
  so labels for adjacent slots would touch if both were bound.

### Tried and dropped, or test-only
- Cropping every icon (v1).
- The template's unused leader lines (v1).
- The arrow keys alongside WASD in prompts.
- Test-only: the tutorial's `every_run`.

## Decision
- 2026-11-24: accepted, moving to the rewrite.

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written. The user agreed the split on
2026-11-24 and asked to go ahead, being told of every new or changed
contract. Agreed then: one `InputDevice` autoload replaces the player's own
device tracking, and ring jitter is a general `Tier` rule.

### PlayerSpawn (changed, see [procedural generation](10_procedural_generation.md))
- `face_nearest_planet` (exported, off; on in the level). When on, after
  the player is placed (and stopped, if `start_at_rest`), it faces (−Z)
  the centre of the nearest root child at the spawn time. Its up is as
  close to the home ring plane's normal as the facing allows (the normal
  projected off the facing). Its position and velocity are unchanged.
- Off, it faces along its orbit as before.

### Tier (changed, see [procedural generation](10_procedural_generation.md))
- `jitter` (exported, 0–1, default 1): how far each child may move from
  its cell's centre, as a share of its room.
- `min_separation` defaults to 0 (the ring tier's value). The systems tier
  keeps 400, which is its cell, so its children stay centred.
- `require_valid` replaces "min_separation ≥ 2 × radius_max" with
  "2 × radius_max ≤ cell_size" (every child fits in a cell) and
  "0 ≤ min_separation ≤ cell_size", and adds "jitter in [0, 1]".

### TierGenerator.generate (changed, see [procedural generation](10_procedural_generation.md))
- A child's radius is drawn before its position. Its space is
  `s = max(radius, min_separation ÷ 2)`, and on each axis it sits
  `(u − 0.5) × jitter × (cell_size − 2s)` from its cell's centre, `u`
  uniform in [0, 1). So the space never leaves the cell.
- At time 0, siblings never overlap and are at least `min_separation`
  apart. Still deterministic for the same inputs.

### MassBody (changed, see [mass bodies](02_mass_bodies.md))
- `surface_frame` (default identity): the rotation the body's surface is
  drawn in. Setting it requires a rotation (orthonormal, not mirrored); a
  bad value is reported and ignored.
- Afterwards, and after any radius change, the mesh's basis is
  `surface_frame × radius`. Its collider and gravity don't turn.

### LiveBodyPool (changed, see [procedural generation](10_procedural_generation.md))
- A promoted body's `surface_frame` is its renderer's global basis,
  orthonormalised: the frame its proxy drew the surface in. So the
  pattern doesn't jump round when a body goes live or is released.

### OrbitRenderer (changed, see [procedural generation](10_procedural_generation.md))
- `proxy_segments` defaults to the live unit sphere's radial segments
  (64), and the proxy's rings are half of them (32, the unit sphere's), so
  drawn and live bodies have the same vertex-raised shape. It stays
  exported for the performance review.
- `display_scale` (default 1) requires a finite value ≥ 0; a bad value is
  reported and ignored. Afterwards every instance is drawn at
  `max(display_scale, 0.001) × its radius` (`drawn_radius(index)`), so the
  proxy shader never divides by zero. Only the uploaded transforms change:
  `instance_radius`, `child_positions`, hidden and tint are untouched, and
  the shader keeps each body's centre on its orbit.
- At 1 it uploads its own buffer unchanged. Hiding or tinting while scaled
  keeps the scaled size.

### GrowInEffect (`scripts/effects/grow_in_effect.gd`)
- Exports the `HierarchyStreamer`, `grow_time` (0.6 s, ≥ 0) and
  `ease_curve` (2.0, > 0, Godot's `ease()`: above 1 eases in). Bad values
  are reported and ignored. It requires a streamer.
- Each renderer the streamer expands after the effect is ready starts at
  `display_scale` 0. Each frame (`advance(delta)`, `delta ≥ 0`) it becomes
  `ease(min(elapsed ÷ grow_time, 1), ease_curve)`, and once the time is up
  it is exactly 1 and the renderer is no longer tracked.
- `grow_time` 0 leaves new renderers at full size. A renderer the
  streamer collapses while growing is dropped. It pauses with the game.
- `growing_count()` is how many renderers are still growing. Renderers and
  their elapsed times are kept in flat arrays with swap-remove.

### WarpEffect (changed, see [game loop](12_game_loop.md))
- `play_in()` has `play()`'s pre-conditions. It records the camera FOV
  and the mesh scale and position as the pose to return to, then shows the
  warp-out's end pose at once: `warp_fov`, `scale.z × stretch`,
  `position.z − warp_distance` and fade 1. `playing` and `playing_in`
  become true.
- While playing in, `advance(delta)` shows the warp-out's pose at
  `t = 1 − elapsed ÷ warp_duration`, so at any moment it mirrors the warp
  out and every value only moves towards the recorded pose.
- Post-condition at the end: every value is back at the recorded pose
  (fade 0), `playing` and `playing_in` are false, and `finished` has been
  emitted exactly once.
- `play_in_on_ready` (exported, off; on in the level): plays in from
  `_ready`, after the player has applied its growth.

### DeviceTracker (`scripts/input/device_tracker.gd`, autoload `InputDevice`)
- `enum Device { KEYBOARD_MOUSE, CONTROLLER }`, moved from
  `PlayerInputComponent`. The project has one tracker, the `InputDevice`
  autoload; tests make their own.
- `device` starts as `KEYBOARD_MOUSE` and is set from every input event
  (`_input`), while the game runs, is paused or is in the shop
  (`PROCESS_MODE_ALWAYS`):
  - a key, mouse button or mouse motion sets `KEYBOARD_MOUSE`
  - a pad button, or a stick or trigger past `switch_deadzone` (exported,
    0.2, in [0, 1]; a bad value is reported and ignored), sets
    `CONTROLLER`, so stick drift can't flip it
  - any other event leaves it alone
- `device_changed(device)` is emitted once for each actual change.
- `is_controller()` is `device == CONTROLLER`.

### PlayerInputComponent (changed, see [controls](05_controls.md))
- `active_device`, `device_changed`, `device_switch_deadzone` and the
  `Device` enum are gone: `InputDevice` tracks the device for everyone.

### DebugOverlay (changed, see [controls](05_controls.md))
- `devices` (a `DeviceTracker`) defaults to `InputDevice` on entering the
  tree. The `Input` line shows its device (`Keyboard/Mouse` or
  `Controller`).

### WarpController (changed, see [game loop](12_game_loop.md))
- `can_warp()` is also false while `warp_effect` is playing, so a run
  can't warp out before it has finished warping in. Without an effect
  nothing changes.
## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done.

### 5.23 Ship size and thrust ✅
- `player.tscn`: the `Mesh` node ×1.3 and the collider's radius ×1.3.
- `blue_thrust.tscn`: 90 particles, 0.8 s lifetime, inherit velocity
  ratio 1.
- **Done:** a test checks the player scene's mesh scale and collider
  radius, and the thrust's amount, lifetime and inherited velocity.

### 5.24 Spawn faces the nearest planet ✅
- `PlayerSpawn.face_nearest_planet` (on): after placing the player, it
  faces the nearest root child, keeping the ring normal as up.
- **Done:** `tests/levels/test_player_spawn.gd` checks the facing, that
  off keeps the prograde facing, and that up stays the ring normal.

### 5.25 Ring jitter ✅
- `Tier.jitter` (0–1, default 1). `TierGenerator` places each child
  anywhere in its cell that keeps `max(radius, min_separation ÷ 2)` inside
  it, scaled by `jitter`. The rings tier's `min_separation` drops to 0, and
  "min_separation ≥ 2 × radius_max" becomes "2 × radius_max ≤
  cell_size".
- **Done:** `tests/generation/test_tier_generator.gd` checks that
  siblings never overlap and are at least `min_separation` apart, that
  jitter 0 centres each child in its cell, and that jitter 1 uses the
  whole room; `test_tier.gd` checks the new rule.

### 5.26 Live bodies match their proxies ✅
- `MassBody.surface_frame`: the rotation its surface is drawn in.
  `LiveBodyPool` sets it to the ring's frame when it promotes a body.
- `OrbitRenderer`'s proxy sphere has the live sphere's tessellation.
- **Done:** tests check a promoted body's mesh frame equals its
  renderer's, and the proxy's segments and rings equal the unit sphere's.

### 5.27 Rings grow in ✅
- `OrbitRenderer.display_scale`: draws every instance at that share of its
  size, without changing `child_positions`.
- `GrowInEffect` (`scripts/effects/grow_in_effect.gd`): eases each newly
  expanded renderer's `display_scale` from 0 to 1 (0.6 s, ease 2).
- **Done:** `test_orbit_renderer.gd` and `tests/effects/test_grow_in_effect.gd`
  pass (instance scales follow the display scale, positions don't move,
  the grow ends at exactly 1).

### 5.28 Warp in ✅
- `WarpEffect.play_in()`: the warp-out pose played backwards, emitting
  `finished` when the ship is back in place. The level plays it at the
  start of every run.
- **Done:** `tests/effects/test_warp_effect.gd` checks the warp in starts
  at the warp-out's end pose and ends at the start pose.

### 5.29 Active input device
- `InputDevice` autoload (`scripts/input/input_device.gd`): `device` and
  `device_changed`, running while paused. `PlayerInputComponent` loses its
  own tracking; the debug overlay reads the autoload.
- **Done:** `tests/input/test_device_tracker.gd` passes (the rules moved
  from the player input component's tests), and the debug overlay's test.

### 5.30 Input icons
- `InputIconSet` resource (the controller and keyboard icon folders) and
  `InputIcons` (`scripts/input/input_icons.gd`): the icons for a list of
  actions on a device, with the merges.
- **Done:** `tests/input/test_input_icons.gd` checks each binding kind's
  icon, every merge, that arrows drop beside WASD, and uniform vs cropped
  textures.

### 5.31 Input prompt
- `InputPrompt` (`scripts/ui/input_prompt.gd`): a row of icons and text
  for a list of actions that follows `InputDevice`. The holo look as a
  shared theme, `resources/ui/holo_theme.tres`.
- **Done:** `tests/ui/test_input_prompt.gd` checks the icons for each
  device and that it rebuilds when the device changes.

### 5.32 Pulse and bounce effects
- `PulseEffect` and `BounceEffect` (`scripts/effects/`): brighten a canvas
  item at a rate, and bob it by a distance.
- **Done:** their tests check the period, range and reset when stopped.

### 5.33 Controls layouts
- `ControllerLayout` and `KeyboardLayout` resources (`scripts/ui/`), and
  their `.tres` for the two SVGs: leader-line slots and their SVG ids, key
  rectangles, and which bindings go where.
- **Done:** their tests check the slot and key mapping from the input map
  and the stick grouping.

### 5.34 Controls view
- `ControlsView` (`scripts/ui/controls_view.gd`): the active device's
  picture, with labelled leader lines (unbound ones removed) or lit keys,
  at one size for both.
- **Done:** `tests/ui/test_controls_view.gd` checks each device's labels
  and the switch.

### 5.35 Pause menu
- `PauseMenu` (`scenes/ui/pause_menu.tscn`) replaces `PauseOverlay`:
  title, controls view, RESUME / RESTART / QUIT, B resumes.
  `PauseController.restart()` is split out of its input handling.
- **Done:** `tests/ui/test_pause_menu.gd` and `test_pause_controller.gd`
  pass.

### 5.36 Shop hint prompts
- The shop's hint labels become `InputPrompt`s, and WARP IN shows the
  `warp_out` icon.
- **Done:** `test_shop_overlay.gd` checks the hint prompts' actions.

### 5.37 Holo crash screen
- `LoseOverlay` rebuilt in the holo look, with a pulsing restart prompt.
- **Done:** `test_lose_overlay.gd` passes.

### 5.38 Warp out prompt
- `WarpPrompt` (`scenes/ui/warp_prompt.tscn`): shown while
  `WarpController.can_warp()`, pulsing.
- **Done:** `tests/ui/test_warp_prompt.gd` checks when it shows.

### 5.39 Shop guide
- `ShopGuide` (`scripts/ui/shop_guide.gd`): the BUY tag over the first
  buyable node until anything's bought, and WARP IN highlighted while
  nothing can be bought.
- **Done:** `tests/ui/test_shop_guide.gd` checks both rules.

### 5.40 Tutorial progress
- `TutorialProgress` on `RunProgress`: which parts are done this session.
- **Done:** its test passes.

### 5.41 Flight training
- `TrainingStep` resource (title, hint, actions, mouse) and
  `FlightTraining` (`scripts/tutorial/flight_training.gd`): the steps in
  order, each done once held long enough.
- **Done:** `tests/tutorial/test_flight_training.gd` checks the hold, the
  mouse distance, the gap and the order.

### 5.42 Target marker
- `TargetMarker` (`scripts/ui/target_marker.gd`): a diamond on a 3D point
  on screen, or an arrow at the screen edge towards it.
- **Done:** `tests/ui/test_target_marker.gd` checks on screen, off screen
  and behind the camera.

### 5.43 Tutorial overlay
- `TutorialOverlay` (`scenes/ui/tutorial_overlay.tscn`): training, then
  the objective with the planet marker and the cargo arrow, once per
  session.
- **Done:** `tests/ui/test_tutorial_overlay.gd` checks the phases and the
  session rule.

## Performance evaluation
The load measured, the budget, and each option weighed:

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |
