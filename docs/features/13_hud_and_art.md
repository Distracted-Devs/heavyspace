# hud_and_art
Started 2026-11-23. The live phase is in `.claude/bin/feature status`.

## Idea
"We're going to prototype adding in the thruster HUD, minimap, ship model, VFX, planet models + textures + shaders, skybox, etc. from dev-pablo and dev-ayla."

## Prototype log
One line per iteration: what changed and what the user said about it.

- v1: ported arcade/holo thrust HUD, orbit minimap, Ayla's ship model, thrust smoke, crash explosion, vaporwave/realistic planet shaders, vaporwave sky and sun onto the generated level. User: zoom the camera out a bit; the minimap going fully red is unreadable.
- v2: camera distance x1.6 (`camera_zoom`); minimap heavier bodies now muted, see-through mauve, ship marker white, no red frame flash on IMPACT (`impact_frame_flash` off). User: drop the forecast text, keep only the path colour; make the bodies static for now.
- v3: forecast text hidden (`show_forecast_text` off), path still coloured green/yellow/red; Clock stopped so orbits don't move (`orbits_move` off).
- Rewrite play-test (2026-11-23): the minimap path trailed behind where the ship really goes (it ignored arcade flight), and a planet could fill the whole minimap. Fixed: the predictor applies the arcade alignment along the facing, and map bodies between the map camera and the ship are hidden.
- Second play-test: the path still looked wrong. The prediction was right, but the minimap's ship cone pointed backwards (its rotation was transposed in `minimap.tscn`), so the path seemed to trail behind. Fixed, with a test that the tip follows the facing.
- Third play-test: the camera invariant broke after growing (world positions ~10^4 out lose 0.001 precision in 32-bit floats, so the fixed 0.001 tolerance was too tight), and planets still filled the minimap (the focus body could be bigger than the view: the giant is radius 5000, the view was capped at 4000). Fixed: a tolerance that scales with the coordinates, and the map fits 1.2 × the focus radius with the cap raised to 20000.
- User: "The minimap should only consider one tier above its current mass". The focus now comes only from the nearest tier above the ship (via the pool's body depths). The prediction still includes every heavier body.

## Accepted behaviour
The spec for the rewrite, from `prototypes/hud_and_art/` (defaults in
`main.gd`, `minimap.gd` and `hud_arcade.gd`, plus the user's tuned
`camera_zoom` in `main.tscn`).

### Keep
- **Thrust HUD (Pablo's arcade gauge), top left:** "THRUST" title, fuel %
  on the right, a framed, bevelled, segmented bar with scanlines, and a line
  below with seconds of boost left (`T-%04.1f`, fuel ÷ burn rate). The bar
  eases towards the real fraction (rate 12/s). The fill colour steps
  green → yellow → orange as the tank empties (`mid_threshold` 0.6,
  `low_threshold` 0.3). Below `low_fuel_fraction` (0.15) it turns red,
  flashes at 4 Hz and reads "!! LOW FUEL !!". Pixelify Sans font, black
  outline and hard drop shadow. Sized from the screen height.
- **Minimap, top right:** a square (0.34 × screen height, at least 160 px)
  with Pablo's white arcade frame and drop shadow, an "ORBIT" title, and
  Ayla's faint cyan grid (12 cells) and scanlines. Inside is a 3D view of
  the nearby live mass bodies around the focus:
  - Focus: the heavier body pulling hardest on the ship (mass ÷ distance²),
    or the ship when nothing heavier is live.
  - Bodies are spheres at their radius: bright green (0.3, 1, 0.5) if
    edible, muted see-through mauve (0.45, 0.25, 0.35, 0.45) if heavier.
  - The ship is a white cone pointing along its facing, sized to the view.
  - The predicted path (no input, gravity from the heavier live bodies,
    linear damping, bodies held still) fades along its length. Its colour
    is the only forecast: red on impact, yellow on escape, green after one
    full turn around the focus, cyan otherwise. No forecast text, and no
    frame flash.
  - The camera looks down on the orbit plane (from position × velocity),
    tilted 35° towards the ship, and zooms smoothly (rate 2/s) to fit the
    ship and the near path, with 1.15 padding, clamped to 150–4000 units.
  - Prediction: up to 120 s at 1/30 s steps, at most 2400 steps.
- **Ship model:** Ayla's low-poly ship (`LowPolySpaceShip.fbx`) replaces the
  CSG ship, fitted so its longest side is 1.7 units, and still scales with
  growth.
- **Thrust VFX:** Ayla's `BlueThrust` smoke at (0, 0, 0.75) behind the
  ship, scale 1, emitting only while thrusting with fuel left.
- **Crash VFX:** Pablo's ship explosion (muzzle flash, fireball, smoke) at
  the ship when the run is lost, scaled with the ship.
- **Planets (Ayla's vaporwave shader):** contour-lined, bumped terrain with
  a glowing rim, on both the far proxies (`OrbitRenderer`) and the live
  bodies. Each body hue-rotates the palette and shifts the terrain by a seed
  from its orbit (`fract(orbit_radius × 0.0137 + phase × 0.618)`), so a
  body looks the same as a proxy and once live (`hue_variety` 0.6).
- **Sky and lighting:** Ayla's vaporwave nebula sky shader with her tuned
  values, ACES tonemapping (white 6), ambient (0.15, 0.15, 0.2), glow
  (intensity 1.2, bloom 0.15, HDR threshold 1.2), and her vaporwave sun
  that follows the camera and lights the scene (light intensity 3).
- **Camera:** 3.5 × the production camera distance (tuned by the user),
  still growing with the ship.
- **Debug overlay:** hidden. It sits where the thrust HUD goes.
- **Static orbits:** the level clock is stopped so every body stays where
  it spawned ("for now").

### Tried and dropped
- Ayla's holo thrust readout (kept as an option in the prototype, not
  chosen).
- Ayla's thin cyan minimap frame, the IMPACT / ESCAPE / ORBIT text, the red
  frame flash on impact, and red heavier bodies ("fully red, unreadable").
- Pablo's rotating textured planets (earth, mars, jupiter, neptune) and the
  Milky Way panorama: options, not chosen.
- The other thrust smokes (FartMobile, BoringSmoke, Bruised) and Pablo's
  particle thrust: options, not chosen.
- Pixelate overlay: off.
- Not ported (nothing in production to attach to): orbit lock prompts,
  missions, dead zones, asteroids, sound, menus.

### Edge cases noticed
- The minimap path assumes bodies stand still, so it's approximate when
  orbits move. With orbits frozen it's exact apart from arcade flight
  turning the velocity.
- A window with a tall aspect makes the HUD and minimap large, since both
  size from the screen height.

## Decision
- 2026-11-23: done. The prototype was deleted.
- 2026-11-23: accepted, moving to the rewrite.

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written. The user asked for every contract
to be drafted at once and then built (2026-11-23). The thrust gauge uses
Ayla's holo look (agreed), and dev-ayla's assets are preferred where both
branches have one.

Changes to existing APIs are recorded in the files that own them:
`Clock`, `PlayerSpawn`, `OrbitRenderer` and `LiveBodyPool` in
[procedural generation](10_procedural_generation.md), and `MassBody` in
[mass bodies](02_mass_bodies.md).

### PlanetSeed (`scripts/generation/planet_seed.gd`)
- `PlanetSeed.of(orbit_radius, phase)` is
  `fposmod(orbit_radius × 0.0137 + phase × 0.6180339, 1)`: a value in
  [0, 1) that picks a body's look. The proxy shader
  (`planet_proxy.gdshader`) works out the same value from the instance's
  custom data, so a body looks the same drawn and live.
- It is pure: the same inputs always give the same seed.

### Sun (`scripts/bodies/sun.gd`, `scenes/bodies/sun.tscn`)
- A `Node3D` with a `Body` sphere (Ayla's vaporwave sun surface), a
  `Corona` quad, a `DirectionalLight3D` and a `FillLight`. It sits on the
  horizon and lights the scene.
- Exports (Sun): `direction` (non-zero, stored normalised, default
  (0.433, 0.5, 0.75)), `distance > 0` (3200), `radius > 0` (650),
  `corona_scale ≥ 1` (3), `light_intensity ≥ 0` (3), `surface_energy ≥ 0`
  (2.5), `glow_intensity ≥ 0` (12) and `shadow_strength` in [0, 1] (0.85). Exports (Fill light):
  `fill_intensity ≥ 0` (0.6), `fill_colour` and `fill_side_offset` in
  [0, 1] (0.35). A bad value is reported and ignored.
- `follow(camera)` (each frame, after the camera moves: process priority
  1000) requires nothing; with no camera it centres on the origin.
  Afterwards:
  - it is `direction × d` from the camera, with
    `d = min(distance, camera.far × 0.9 − radius × corona_scale / 2)`, so
    it never crosses the far plane
  - the body is scaled to `radius` and the corona to
    `radius × corona_scale`
  - the sunlight shines along `−direction` with energy `light_intensity`
    and shadow opacity `shadow_strength`
  - the fill light comes from the far side, swung `fill_side_offset`
    towards the side, with `fill_intensity` and `fill_colour`, and is
    hidden at 0
  - the surface's `sun_energy` is `surface_energy` and the corona's
    `intensity` is `glow_intensity / 4` (Ayla's script set a surface
    uniform that didn't exist, so her sun showed 2.5)

### ThrustEffect (`scripts/effects/thrust_effect.gd`)
- Exports: `flight_input: InputComponent`, `fuel: FuelComponent` and
  `particles: GPUParticles3D` (Components), and `threshold` in [0, 1)
  (Thrust, 0.05). A bad threshold is reported and ignored.
- `refresh()` (each frame) requires all three components. Afterwards
  `particles.emitting` is true exactly when `|thrust_intent.z| > threshold`
  and `fuel.fuel > 0`.
- On the player it drives Ayla's `BlueThrust` smoke, scale 1, at
  (0, 0, 0.75) under the ship mesh, so it grows with the ship.
- Changed 2026-11-24 (see [pre-juice polish](16_pre_juice_polish.md),
  step 5.44): the smoke is emitted along the emitter's −Y, out of the
  back of the ship (+Y pointed forwards), and simulated in the ship's
  frame (local coordinates, no inherited velocity).

### CrashEffect (`scripts/effects/crash_effect.gd`)
- A `Node3D`. Exports: `lose_controller: LoseController` (optional) and
  `ship: Node3D` (Components), `explosion: PackedScene` (Ayla's ship
  explosion) and `lifetime > 0` (5 s, the longest particle lifetime)
  (Crash). A bad lifetime is reported and ignored.
- With a lose controller, `lost_game` calls `play()`.
- `play()` requires `ship` and `explosion`. Afterwards one new explosion is
  its child, at the ship's global position and scaled by the ship's scale
  (the mesh, so it matches growth). The explosion's particles are one-shot
  and start on entering the tree.
- `advance(delta)` (each frame) ages every explosion and frees each one
  once it has lived `lifetime`. Explosions are kept in flat arrays (node,
  age) with swap-remove.
- `active_count()` is the number of explosions not yet freed.
- `prewarm` (exported, default on, Crash; performance option E2): when it
  is ready, it instantiates one hidden explosion as its child and frees it
  at once, so the first crash doesn't pay the explosion's first creation.
  It never counts in `active_count()`.

### FuelGauge (`scripts/ui/fuel_gauge.gd`, `scenes/ui/fuel_gauge.tscn`)
- Ayla's holo thrust readout, top left: a `CanvasLayer` with a framed
  panel holding a "// THRUST RESERVE" title, a segmented bar with
  scanlines, and a readout line. Sized from the screen height.
- Exports: `fuel: FuelComponent` (Components); `bar_width_ratio` in
  [0.05, 0.5] (0.16), `bar_height_px ≥ 10` (14), `segments` in [2, 60]
  (20) and `margin_ratio` in [0, 0.2] (0.015) (Layout);
  `low_fuel_fraction` in [0, 1] (0.15) and `flash_hz > 0` (2) (Warning);
  `colour` (0.3, 0.9, 1) and `low_colour` (1, 0.25, 0.2) (Colours).
- `refresh(delta)` (each frame) requires `fuel`. Afterwards:
  - `fraction` is `fuel / tank_size`, clamped to [0, 1]
  - `warning` is `fraction < low_fuel_fraction`
  - the bar lights `fraction × segments` segments (the last one partly)
  - `bar_colour()` is `colour`, or while warning `low_colour` with an
    alpha flashing between 0.5 and 1 at `flash_hz`
  - the readout is `FUEL nn% | T-s.ss` (`%3d%% | T-%.1fs`): the percentage
    and the seconds of boost left, `fuel / burn_rate`
- Invariant: `0 ≤ fraction ≤ 1`.

### PathPredictor (`scripts/ui/path_predictor.gd`)
- A `RefCounted` that works over `GravityRegistry`'s flat arrays.
  Settings: `step > 0` (1/30 s), `duration > 0` (120 s), `max_steps > 0`
  (2400), `sample_every ≥ 1` (3) and `escape_factor ≥ 1` (1.5). A bad
  value is reported and ignored.
- `max_sources ≥ 0` (default 0, all): when positive, `predict` only
  simulates the `max_sources` heavier sources with the greatest
  `mass / distance²` at the start position (performance option B, agreed
  2026-11-23). A negative value is reported and ignored.
- `PathPredictor.focus_index(position, mass, positions, masses, depths)`
  requires equal-length arrays. Only sources heavier than `mass` at the
  deepest depth any heavier source has (the tier just above the ship) are
  candidates. It is the candidate with the greatest `mass / distance²`
  (distance² floored at 1), or −1 when none is heavier. Changed 2026-11-23
  after play: "the minimap should only consider one tier above its
  current mass", so a ring-sized ship focuses on its system, not the
  giant.
- `predict(position, velocity, forward, alignment, damping,
  gravity_constant, positions, masses, radii, mass, focus)` requires
  equal-length arrays, `damping ≥ 0`, `alignment` in [0, 1] and a
  non-zero `forward`. It steps the ship with no input, the bodies held
  still and the facing held at `forward`: the same pull as
  `GravityReceiverComponent` (only sources heavier than `mass`, distance
  floored at the source's radius), then linear damping, then the same
  turn as `ArcadeFlightComponent` (the velocity swings `alignment` of the
  way to `forward × speed`, keeping its speed). With `alignment` 1 the
  path runs straight along the facing, and with 0 it is Newtonian.
  Changed 2026-11-23 after play: the Newtonian-only path trailed off where
  the ship would go if arcade flight stopped steering it. Afterwards:
  - `points[0]` is `position`, then every `sample_every`th step, then the
    last position. There are at most `max_steps / sample_every + 2`
    points, and at most `min(duration / step, max_steps)` steps run.
  - `forecast` is `IMPACT` if the path enters a heavier source (it stops
    there), else `ORBIT` once it has swept a full turn around `focus` (it
    stops there), else `ESCAPE` if it ends more than `escape_factor` ×
    the starting distance from `focus`, else `NONE`
  - with nothing heavier, `forecast` is `ESCAPE` and `points` is just
    `position`
- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): `falloff_exponent` (2) and
  `drift_enabled` (off) settings, and a last `drift` argument. The pull
  is `GravityReceiverComponent.acceleration_at`; with drift, the drift
  takes the pull and is damped while only the own velocity is aligned.

### Minimap (`scripts/ui/minimap.gd`, `scenes/ui/minimap.tscn`)
- Top right: a square `0.34 × screen height` (at least 160 px), with
  Pablo's white arcade frame, hard drop shadow and "ORBIT" title (Pixelify
  Sans), Ayla's faint cyan grid (12 cells) and scanlines, over a
  transparent `SubViewport` with its own world.
- Exports: `player: Player` (Components); `edible_colour` (0.3, 1, 0.5),
  `danger_colour` (0.45, 0.25, 0.35, 0.45), `ship_colour` (white) and the
  path colours `impact_colour`, `escape_colour`, `orbit_colour`,
  `path_colour` (Colours); `size_ratio` (0.34), `margin_ratio` (0.015),
  `min_size_px` (160) (Layout); `camera_tilt_degrees` (35), `fit_padding`
  (1.15), `focus_fit` (1.2), `zoom_smoothing` (2), `min_view_radius` (150)
  and `max_view_radius` (20000, raised from 4000 so the 5000-radius giant
  fits) (View); and the predictor's `step` (0.25 s), `duration` (20 s), `max_steps`
  (2400) and `max_sources` (8) (Prediction; step and duration were 1/30 s
  and 120 s, coarsened in the performance review, option A).
- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): the predictor gets the receiver's
  exponent, drift setting and drift, and "heavier" (focus, prediction and
  map colours) uses the core mass, not `body.mass` with cargo.
- `refresh(delta)` (each frame) requires `player`. The prediction uses
  the player's facing (`−Z`) and its `ArcadeFlightComponent.alignment`
  (0 without one). Afterwards:
  - the focus is the body picked by `PathPredictor.focus_index` for the
    player from `pool`'s root and live bodies and their depths, or the
    player when there is none; the map is centred on it. Without a `pool`
    (optional export, Components) it picks from every registry source,
    all at one depth. The prediction still feels every heavier source.
  - there is one map sphere per live `MassBody` within
    `1.5 × view radius` of the focus (plus its radius), at its offset and
    scaled to its radius, coloured `danger_colour` if it's heavier than
    the player and `edible_colour` otherwise (`map_body_count()`)
  - a map sphere is hidden while it touches the segment from the map
    camera to the ship marker (including when it holds the camera), so a
    planet can never cover the ship (added 2026-11-23 after play)
  - the ship cone is at the player's offset, its tip along the player's
    facing (`−Z`)
  - the path is the prediction, coloured by its forecast and fading along
    its length. There is no forecast text. It is drawn as a Catmull-Rom
    curve through every predicted point, `smoothing_segments` (≥ 1,
    default 8, Prediction) segments per span, so coarse steps still draw
    a smooth line (agreed in the performance review, 2026-11-23).
    `Minimap.smooth(points, segments)` returns `(n − 1) × segments + 1`
    points (the input when there are fewer than 2), and passes through
    every input point.
  - the view radius eases towards the fit (the larger of
    `focus_fit × focus radius`, the ship distance and the near path, ×
    `fit_padding`), within [`min_view_radius`, `max_view_radius`].
    `focus_fit` (1.2, Ayla's value) keeps the whole focus body in view, so
    a body bigger than the view can't fill the map (added 2026-11-23 after
    play)
- Invariant: `min_view_radius ≤ view_radius ≤ max_view_radius`.

## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done.

### 4.1 Art assets ✅
- Copy only the chosen assets from dev-ayla into `resources/` with
  production names: the low-poly ship (`models/`), `BlueThrust` and its
  shader and textures (`vfx/`), the ship explosion (`scenes/effects/`), the
  vaporwave planet, sky, sun and corona shaders (`shaders/`), and Pixelify
  Sans (`fonts/`).
- **Done:** `godot --headless --import` is clean and smoke passes.

### 4.2 Frozen orbits ✅
- `Clock.running` (default on), off in `generated_level.tscn`.
  `PlayerSpawn` leaves out the home system's velocity while the clock is
  stopped.
- **Done:** clock and spawn tests pass (time holds while stopped; the
  player stays near home), and smoke passes.

### 4.3 Planet look ✅
- `planet_surface.gdshaderinc` (Ayla's vaporwave terrain, contours, rim
  and per-seed hue shift), `planet.gdshader` (live bodies, `instance
  uniform float seed`) and `planet_proxy.gdshader` (the orbit vertex). One
  shared material each. `PlanetSeed`, `MassBody.look_seed`,
  `OrbitRenderer.proxy_material`, and `LiveBodyPool` seeding promoted
  bodies.
- **Done:** seed, mass body, renderer and pool tests pass, and smoke
  passes.

### 4.4 Sky and sun ✅
- `resources/environments/space.tres` (vaporwave sky with Ayla's tuned
  values, ACES, ambient, glow) in a `WorldEnvironment`, and the `Sun`, in
  the generated level.
- **Done:** `tests/bodies/test_sun.gd` passes, and smoke passes.

### 4.5 Ship and camera ✅
- The low-poly ship replaces the CSG ship in `player.tscn` (longest side
  1.7). Camera distance 9.45 (2.7 × 3.5).
- **Done:** player and growth tests pass, and smoke passes.

### 4.6 Thrust effect ✅
- `ThrustEffect` with `BlueThrust` on the player.
- **Done:** `tests/effects/test_thrust_effect.gd` passes, and smoke
  passes.

### 4.7 Crash effect ✅
- `CrashEffect` in the generated level, on `lost_game`.
- **Done:** `tests/effects/test_crash_effect.gd` passes, and smoke passes.

### 4.8 Fuel gauge ✅
- `FuelGauge` in the generated level. The debug overlay is taken out of
  the level (it sat where the gauge goes).
- **Done:** `tests/ui/test_fuel_gauge.gd` passes, and smoke passes.

### 4.9 Path prediction ✅
- `PathPredictor`.
- **Done:** `tests/ui/test_path_predictor.gd` passes (focus pick, impact,
  orbit, escape, no sources).

### 4.10 Minimap ✅
- `Minimap` in the generated level.
- **Done:** `tests/ui/test_minimap.gd` passes, smoke passes, and the user
  has played the level with the HUD and art.

### 4.11 Clean-up ✅
- Delete what nothing uses any more: `orbit.gdshader`, `earth.tres`,
  `space.jpeg`, `space.avif` and `test_planet.tscn`, then `earth.jpg` and
  `milkyway.exr` once the prototype was deleted (`feature done`).
- **Done:** a grep finds no references outside the prototype, the full
  suite and smoke pass.

## Performance evaluation
The load measured, the budget, and each option weighed.

### Benchmark
`benchmarks/hud_and_art/bench.gd` (`godot --headless --fixed-fps 60 -s
benchmarks/hud_and_art/bench.gd -- contracts=0`). Agreed load: the
generated level (seed 12345) with the user's tuning, a 60-frame warm-up,
then 600 frames of real flight from the home ring's mid-radius (arcade
flight and physics on, boost held, turning on a fixed pattern, collisions
off). It eats 43 pickups. Five explosions are played, one a frame, from
frame 100. Each feature node's per-frame call is made and timed by the
benchmark (`Minimap.refresh`, `FuelGauge.refresh`, `Sun.follow`,
`ThrustEffect.refresh`, `CrashEffect.advance`), and the prediction is
also timed on its own every 10th frame. Options `step=`, `duration=`,
`max_steps=` and `experiment=` try the alternatives. Agreed budget: this
feature's code under 1ms mean and 2ms worst per frame; one-off actions
under 2ms. A rough rendered (windowed) run was also agreed.

### Baseline (contracts off, ms)
Contracts on add nothing measurable (within run-to-run noise).

| measured | mean | p95 | worst |
|---|---|---|---|
| `Minimap.refresh` | 26.2 | 28.1 | 34.4 |
| prediction alone | 25.6 | 27.0 | 29.5 |
| `FuelGauge.refresh` | 0.031 | 0.044 | 0.077 |
| `Sun.follow` | 0.013 | 0.017 | 0.042 |
| `ThrustEffect.refresh` | 0.003 | 0.004 | 0.008 |
| `CrashEffect.advance` | 0.001 | 0.002 | 0.003 |
| `CrashEffect.play` (5) | 1.67 | | 8.2 (first only) |
| frame, headless | 56.3 | 78.9 | 85.4 |

- The prediction is the whole problem. Under arcade flight (alignment 1)
  the path is a straight line that never completes an orbit, so it always
  runs the full 2400 steps (802 points), and each step loops over every
  heavier live source: 82 on average. That is ≈ 0.13µs per source-step.
- The first explosion's 8.2ms is the particles' first creation; later
  ones are ≈ 0.02ms.

### Hot spots and options

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |
| A. Coarser prediction defaults (step 0.25 s, 20 s, 80 steps) | 25.6 (prediction), 26.2 / 34.4 worst (minimap) | 0.88 (prediction), 1.11 / 3.82 worst (minimap) | none (exported values), but steps of ≈12 units can skip small bodies and it looks only 20 s ahead; worst still over 2 alone | taken with B (2026-11-23), on the minimap's exports |
| B. Prune to the 8 strongest pulls at the start | 25.6 | 3.58 | an extra rule (`max_sources`, 0 = all by default); can miss an impact with a body weak at the start | taken with A (2026-11-23): the minimap passes 8 |
| C. Exact straight-line forecast when alignment is 1 (ray against each heavier sphere) | 25.6 | 0.022 | a second short branch in `PathPredictor` and a contract addition; alignment < 1 still simulates | declined: the user wants a curved line |
| D. Predict every Nth frame | 25.6 | 25.6 / N mean, worst unchanged | laggy path; fails the worst-frame budget alone | declined |
| E2. Pre-warm the explosion at level start | 8.2 (first explosion) | 0.03 (worst crash) | a few lines in `CrashEffect` start-up; the cost moves to level start | taken (2026-11-23), `prewarm` on |
| E3. Reuse a pool of explosions, restarting their particles | 8.2 | 0.005 | a pool to manage and a bigger contract change, for one crash a run | declined |
| F. Smooth the drawn path (Catmull-Rom, 8 segments per span) | n/a | included in the final minimap figure | drawing only; `smoothing_segments` exported | taken (2026-11-23): the user wants the coarse path drawn as a smooth curve |

### Final figures (contracts off, ms)
Contracts on add nothing measurable.

| measured | mean | p95 | worst |
|---|---|---|---|
| `Minimap.refresh` (predict, sync, smooth, draw) | 0.39 | 0.89 | 1.08 |
| prediction alone (80 steps, 8 sources) | 0.18 | 0.28 | 0.62 |
| `FuelGauge.refresh` | 0.026 | 0.031 | 0.071 |
| `Sun.follow` | 0.011 | 0.013 | 0.018 |
| `ThrustEffect.refresh` | 0.002 | 0.003 | 0.009 |
| `CrashEffect.advance` | 0.001 | 0.002 | 0.006 |
| `CrashEffect.play` (5) | 0.023 | | 0.029 |
| frame, headless | 2.37 | 3.06 | 4.87 |
| frame, rendered, vsync off (2 runs) | 2.14 | 3.76 | 7.03 |

- The feature's own code is ≈ 0.44ms mean and ≈ 1.2ms worst per frame,
  within the 1ms / 2ms budget. The minimap is 26ms → 0.39ms.
- The rendered run (the user's machine, windowed, `--disable-vsync`)
  shows the planet shaders, sky, glow and the minimap viewport leave
  plenty of headroom: ≈ 470fps mean. With vsync on, frames sit at 16.7ms
  and CPU timings read about 3× higher (the CPU idles between frames), so
  vsync-off is the figure recorded.

### Decision
Within budget with A + B + F (coarse prediction from the 8 strongest
sources, drawn as a smooth curve) and E2 (pre-warmed explosion). The exact
straight-line forecast (C) was declined, so with arcade alignment 1 the
coarse path can still miss an impact with a small body between steps.
