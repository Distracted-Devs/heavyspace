# Procedural generation
**Status:** done ✅ (Phase 2, steps 2.2 to 2.4 and 2.6 to 2.9)

A procedurally generated level of [mass bodies](02_mass_bodies.md) in a
hierarchy of orbits (moons upon moons upon moons), with mass pickups
spawning in orbit around bigger masses. The game must run at 60fps.

Agreed:
- Bodies move on scripted (kinematic) circular orbits around their parent.
  Mass objects still don't feel gravity.
- The level is a finite fractal: one huge central body with about 20 levels
  of nesting. Each body has smaller bodies orbiting it, down to a minimum
  size, with random size and orbit orientation. It should be easy to
  progress from one level to the next.
- The hierarchy is generated deterministically from an exported seed (0
  picks a random one) and each body's path. Children are spawned only when
  the player gets near and freed when they leave, but large bodies stay
  visible in the background.
- Each level's radius is about 0.6–0.7× its parent's (exported), which keeps
  the system within 32-bit float precision. A floating origin comes only if
  jitter shows up.
- When procedural generation replaces `test_level.tscn`, delete
  `test_level_body_is_heavier_than_player_starting_mass` (and
  `LEVEL_SCENE`) from `tests/bodies/test_mass_body.gd`. It tests the level,
  not the body.

## Idea
"I want you to prototype phase 2. At first lets get one non-procedurally
generated spawn how I want it and then scale it up. First lets get a planet
about 100x bigger than the player with about 100 planets orbiting it in a
ring (think saturn)"

## Prototype log
- v1: hand-built system in `prototypes/procedural_generation/`. A central
  body of radius 50 (100× the ship's 0.5) at (0, 0, -300), with 100 ring
  bodies (radius 0.2–3, biased small) orbiting at 1.6–2.6× its radius in a
  thin ring tilted 20°, on Kepler-style circular orbits. Ring mass scales
  with volume against the ship, so anything bigger than the ship is red.
  The user liked it and tuned: ring_count 500, ring_thickness 10,
  body_radius_min 1, inner_orbit_period 60.
- v2: scaled up. A giant (radius 5000, mass 1e7) with a ring of 10 Saturn
  systems at 1.6–2.6× its radius, each orbiting at the real circular-orbit
  speed (about 100 u/s). The player spawns with its home system's velocity,
  so they fall around the giant together. Spawning all 5,011 bodies cost
  about 14.5ms per physics frame, so a ring is spawned only within 2000 of
  its system and freed past 3000. Orbits are driven by time, so rings
  respawn in place. Now about 5.7ms per physics frame. Every ring body is
  heavier than the ship with the tuned values, and from rest the ship falls
  into its home system in about 10s (true of v1 too).
- v3: the user tested 500 systems (with giant and central mass 1) and the
  game struggled. There were 8,001 real bodies (about 32,000 nodes), and
  physics took 40–90ms per frame. Now drawn bodies are MultiMeshes with
  low-poly spheres, and a vertex shader (`orbit.gdshader`) works out each
  orbit from time. Real `MassBody` nodes exist only for ring bodies within
  60 of the player and systems within 3000. They sit at exactly the shader's
  position and hide their drawn copy. Systems keep at least 600 between
  centres. Result: 213 nodes and 42 bodies. A windowed run on an M1 holds
  60fps (worst frame 17.9ms, 24 draw calls), and also while flying through
  systems at 300 u/s. Awaiting feedback.

## Accepted behaviour
The v3 prototype was accepted. The rewrite generalises it to a list of
tiers (any depth) and starts with the prototype's three: a giant, its
systems, and each system's ring bodies.
- Every body is on a circular orbit around its parent, driven by elapsed
  physics time, so a body that streams back in is in the same place.
- Children are laid out deterministically from the seed and the parent's
  path. Siblings keep a minimum separation. Mass scales with volume against
  the player, so anything bigger than the ship is heavier.
- Drawn bodies are MultiMesh instances whose orbits run in a vertex shader.
  They cost no CPU.
- A real `MassBody` (collision and gravity) exists only near the player,
  sits at exactly the shader's position and hides its drawn copy.
- A parent's children are drawn within an expand distance and dropped past
  a larger collapse distance. Ancestors stay drawn in the background.
- The player spawns with its home system's velocity, so the ship and the
  system fall around the giant together.
- Tuned values: 500 systems at 1.6–2.6× the giant's radius (5000, thickness
  1000, separation 600); 500 ring bodies per system at 1.6–2.6× the central
  radius (50), thickness 10, radius 1–3, size bias 2, inner period 60s.
  Expand at 2000 and collapse at 3000. Ring bodies go live within 60 and
  are released past 90. Systems go live within 3000 and are released past
  3500. The camera's far plane is 60000.

## Contracts
Agree each API's contract with the user at the start of its step.

### Orbit (`scripts/orbits/orbit.gd`)
- Stateless and static. Positions are in the parent's orbit frame: the
  parent is at the origin and the orbit lies in the XZ plane, offset by
  `height` along Y. The caller applies the plane's tilt and the parent's
  centre.
- `position`, `velocity` and `circular_angular_speed` require
  `orbit_radius > 0` and finite inputs. `circular_angular_speed` also
  requires `parent_mass > 0` and `gravity_constant > 0`. A broken
  pre-condition is reported and returns `Vector3.ZERO` (or `0.0`).
- `angular_speed` may be negative (a retrograde orbit).
- `position(orbit_radius, height, phase, angular_speed, time)`:
  - its distance from the Y axis is `orbit_radius`, and its `y` is
    `height`
  - its angle is `phase + angular_speed × time`, so it repeats every
    `TAU / |angular_speed|`
- `velocity(...)` (same arguments):
  - it has no `y` and is perpendicular to the offset from the axis
  - its length is `|angular_speed| × orbit_radius`
  - it is the time derivative of `position`
- `circular_angular_speed(parent_mass, orbit_radius, gravity_constant)`:
  - the result is positive and satisfies `ω² r = G M / r²`, the
    inverse-square rule of `GravityReceiverComponent`
  - it uses the in-plane `orbit_radius` only. `height` doesn't change it
    (the prototype's rule).

### Tier (`scripts/generation/tier.gd`)
- A Resource holding one level of the hierarchy's tuning. Its defaults are
  the ring tier.
- Orbit: `orbit_inner` and `orbit_outer` (× the parent's radius),
  `thickness` (world units either side of the plane), and
  `plane_tilt_max_degrees` (180 means any orientation).
- Size: `radius_min` and `radius_max` (absolute), `size_bias` (higher means
  more small bodies), and `mass_density` (mass = `mass_density × r³`).
- Spawning: `spawn_density` (children per unit volume of the ring),
  `cell_size` and `min_separation`.
- Speed: `inner_period_min` and `inner_period_max` (seconds for one lap at
  the inner edge), and `retrograde_chance`.
- Streaming (absolute): every field describes this tier's children. They
  are drawn while the player is within `expand_distance` of their parent,
  and dropped past `collapse_distance`. This is ignored for the root's
  children, which are always drawn. They become real `MassBody`s within
  `live_distance` of themselves, and go back to drawn-only past
  `release_distance`.
- `expected_count(parent_radius)` is `spawn_density × π(outer² − inner²) ×
  2 × thickness`.
- `cell_spawn_chance()` is `spawn_density × cell_size² × 2 × thickness`.
- `require_valid(parent_radius)` reports every broken rule and returns
  whether the tier is valid for that parent:
  - `0 < radius_min ≤ radius_max`, `orbit_inner ≤ orbit_outer`, and
    `thickness > 0`
  - `size_bias`, `mass_density` and `spawn_density` are > 0
  - `0 < inner_period_min ≤ inner_period_max`
  - `retrograde_chance` is in [0, 1], and `plane_tilt_max_degrees` is in
    [0, 180]
  - children can't touch the parent:
    `orbit_inner × parent_radius ≥ parent_radius + radius_max`
  - siblings can't touch: `min_separation ≥ 2 × radius_max`, and
    `min_separation ≤ cell_size`
  - `collapse_distance > expand_distance`, and
    `release_distance > live_distance`
  - `cell_spawn_chance() ≤ 1`, and the grid has at most 1,000,000 cells

### TierLayout (`scripts/generation/tier_layout.gd`)
- One parent's children, as packed `float64` arrays: `radius`, `mass`,
  `orbit_radius`, `height`, `phase` and `angular_speed`. It also holds
  `plane`, the rotation of the ring's plane.
- Invariant: every array is `size()` long.

### TierGenerator.generate (`scripts/generation/tier_generator.gd`)
- `generate(level_seed, path, parent_radius, tier, focus_mass := NAN) ->
  TierLayout`. `focus_mass` is only used by a mass-capped tier (see
  [player growth](11_player_growth.md)). `path`
  is the parent's indices from the root (`[]` is the root).
- Requires `parent_radius > 0`, a tier, and `tier.require_valid`. A broken
  pre-condition is reported and returns an empty layout.
- The ring is a jittered 2D grid of `cell_size` squares in its plane. Each
  cell holds at most one child, placed in the cell's central square of side
  `cell_size − min_separation`, with probability `cell_spawn_chance()`. It is
  kept only if it falls within the ring. Its height is random within
  ±`thickness`.
- Deterministic: the same seed, path, parent radius and tier always give an
  identical layout.
- Every child:
  - `radius` is in [`radius_min`, `radius_max`]
  - `mass = mass_density × radius³`, unless the tier is mass-capped
  - `orbit_radius` is in [inner, outer] × `parent_radius`
  - `|height| ≤ thickness`
  - `phase` is in [0, TAU)
  - `|angular_speed| = TAU / period × (inner / orbit_radius)^1.5`, for a
    random period in [`inner_period_min`, `inner_period_max`]. It is
    negative (retrograde) with probability `retrograde_chance`
- At time 0, siblings are at least `min_separation` apart. The grid
  guarantees this and the tests check it. Siblings drift as they orbit.
- `plane` is a rotation, tilted at most `plane_tilt_max_degrees` from the
  XZ plane. All of a parent's children share it, so a ring stays a flat
  disc.
- On average, the count is close to `tier.expected_count(parent_radius)`.

### Clock (`scripts/core/clock.gd`)
- A node in the level holding its elapsed time, so a restart resets it.
  Godot's own clocks don't fit: `Time` doesn't pause or reset, and the
  shader's `TIME` ignores pause and rolls over every hour.
- `time` starts at 0 and advances by `delta` every physics frame. It stops
  while the tree is paused.
- It ticks before anything that reads it (physics priority -5, then the
  streamer -4, the live bodies -3 and `GravityRegistry` -2).
- After each tick, and when it enters the tree, the global shader parameter
  `clock_time` (declared in `project.godot`) equals `time`.
- Invariant: `time ≥ 0`, and it never goes backwards.
- `running` (exported, default on; [HUD and art](13_hud_and_art.md) step
  4.2): while off, `time` holds and nothing orbits. The generated level
  turns it off for now.

### OrbitRenderer (`scripts/generation/orbit_renderer.gd`)
- A `MultiMeshInstance3D` that draws one parent's children as low-poly unit
  spheres (`proxy_segments`) with `proxy_material` (exported, required,
  default `resources/materials/planet_proxy.tres`, step 4.3). Its shader
  works out each orbit from the global `clock_time` (see `Clock`).
- `show_layout(layout)` requires a layout. Afterwards:
  - `count()` is `layout.size()`. Each instance is scaled to its child's
    radius, and its custom data is `(orbit_radius, height, phase,
    angular_speed)`
  - every instance is visible and untinted (white)
  - the node's basis is `layout.plane`
  - the culling box holds every child at every time
- The renderer keeps its own copy of the instance buffer and uploads it in
  one write. The headless renderer doesn't keep MultiMesh data, so the copy
  is what the tests read.
- `set_hidden(index, hidden)` and `set_tint(index, colour)` require
  `0 ≤ index < count()`. Afterwards `is_hidden(index)` and `tint(index)`
  report the new value. Each leaves the other alone.
- `layout` is the layout it draws (read-only).
- `reach()` is the furthest any child can be from the centre (orbit,
  height and radius together). Every child stays within it at every time.
- `child_positions(time)` returns every child's world position, equal to
  `child_position` for each index. It is cached for the last time and
  transform, so the streamer and the pool share one computation per frame.
  Callers mustn't change the array it returns.
- `child_velocity(index, time)` is `global_basis × Orbit.velocity(…)`: the
  child's velocity relative to its parent's centre.
- `child_position(index, time)` is
  `global_transform × Orbit.position(…)`, the CPU twin of the shader.
- The node's position is the parent's centre. Its owner moves it with the
  parent.

### HierarchyStreamer (`scripts/generation/hierarchy_streamer.gd`)
- A `Node3D` at the root's centre. Its exports are `level_seed` (0 picks a
  random seed when the level starts, kept in `resolved_seed`),
  `root_radius`, `root_mass`, `tiers: Array[Tier]`, the `Clock` and the
  focus (the player).
- `tiers[d]` generates the children of a parent at depth `d`; the root is
  depth 0. Every lookup goes through one method (`_tier_for(depth, path,
  parent_radius)`), so a procedural tier provider can replace the array
  later. Such a provider must derive its tiers from the seed and the path,
  and mustn't keep the path it's given, since the streamer reuses it.
- When it starts, it requires a non-empty list of tiers with no nulls, and
  each tier must be valid for both the smallest and largest radius its
  parents can have. If not, it reports the problem and stays empty.
- `update(focus_position, time)` runs each physics frame (priority -4,
  after `Clock`). Afterwards:
  - the root is expanded, and every expanded parent's ancestors are
    expanded too (no orphans)
  - a child of an expanded parent that has a tier of its own is expanded if
    it's nearer than `expand_distance`, and collapsed if it's further than
    `collapse_distance`. In between, it keeps its state (hysteresis). A
    whole chain of ancestors can expand in one update.
  - collapsing a parent frees its whole subtree and its renderers
  - every expanded parent's renderer sits at that parent's position at
    `time`
- Re-expanding a parent gives exactly the layout it had before, except
  that a mass-capped tier's masses follow the focus mass at the time it
  expands (see [player growth](11_player_growth.md)).
- `is_expanded(path)`, `renderer_for(path)`, `tier_of(path)` (the tier that
  made that parent's children) and `expanded_paths()` report the state. `expanded(path, renderer)` is emitted after a parent expands, and
  `collapsing(path, renderer)` before its renderer is freed.
- Expanded parents live in flat arrays, each parent before its children, so
  one pass moves every renderer, parents first.
- Each renderer is a direct child of the streamer, so it doesn't inherit its
  parent's ring tilt.

### LiveBodyPool (`scripts/generation/live_body_pool.gd`)
- Swaps drawn bodies for real `MassBody`s near the player. It exports only
  the `HierarchyStreamer`, and reads the clock and focus from it.
- It requires a streamer. Without one, it reports the problem and does
  nothing.
- The root is always a real body (`root_body`), at the streamer's centre
  with `root_radius` and `root_mass`.
- `update(focus_position, time)` runs each physics frame (priority -3,
  after the streamer and before `GravityRegistry`). Afterwards, for each
  drawn child of an expanded parent:
  - it is live if it's nearer than its tier's `live_distance`, and not live
    if it's further than `release_distance`. In between, it keeps its state.
  - a live body has its layout's radius and mass, and its drawn copy is
    hidden. It is moved to exactly `renderer.child_position(index, time)`.
    `MassBody` keeps `sync_to_physics` on, so it moves kinematically (with
    a velocity) and reaches that point when the physics step runs. A new
    body is placed before it enters the tree, so it never sweeps in from
    the origin.
  - a released body is freed and its copy shown again
  - a promoted body's `look_seed` is `PlanetSeed.of(orbit_radius, phase)`
    from its layout (step 4.3)
- `live_bodies()` and `live_depths()` ([HUD and art](13_hud_and_art.md),
  2026-11-23) are the live bodies and, at the same index, their depth in
  the hierarchy (the drawn parent's path length + 1: systems 1, rings 2).
  The root body is depth 0 and isn't in them. Callers mustn't change the
  arrays. Invariant: both are the same length as `live_count()`.
- A drawn parent whose `reach()` can't come within `live_distance` of the
  player is skipped, so only nearby rings are checked child by child.
- When the streamer emits `collapsing`, that parent's live children are
  freed before its renderer is.
- Invariant: live bodies and hidden instances match one to one.
- Live bodies are kept in flat arrays (body, renderer, index) with
  swap-remove.

### PlayerSpawn (`scripts/levels/player_spawn.gd`)
- It puts the player on a circular orbit around its home system: root child
  `home_index`. Its exports are the streamer, the player, `home_index` (0),
  `spawn_distance` (300), `spawn_angle_degrees` (0) and `camera_far`
  (60000).
- It runs once, when it's ready, after the streamer. It expands the home
  system (through `streamer.update`) to learn its ring plane.
- It requires a started streamer, a player, an existing home system, and a
  `spawn_distance` that clears the home ring: greater than the ring tier's
  `orbit_outer × home radius + thickness + radius_max`. If not, it reports
  the problem and leaves the player alone.
- Afterwards:
  - the player is in the home ring's plane, `spawn_distance` from the home
    centre, at `spawn_angle_degrees` around it
  - its velocity is the home system's velocity (only while the clock is
    `running`, step 4.2) plus the circular-orbit
    speed `√(G × home mass / spawn_distance)` along the prograde tangent
    (the direction the ring turns). `G` is the player's
    `GravityReceiverComponent.gravity_constant`.
  - it faces along that tangent (−Z forward), with up along the ring
    plane's normal
  - the camera's far plane is `camera_far`
- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): `start_at_rest` (off; on in the
  level) zeroes the velocity, spin and drift after placing and facing
  the player.
- The systems tier's speeds match real orbits around the giant (inner
  period 450s gives `GM ≈ 1e8`), so the ship falls around the giant with its
  home system. At 300 the ship is about half the home system's Hill radius
  out, so the giant's pull can slowly perturb its orbit.

## Steps

### 2.2 Orbit maths ✅
- `scripts/orbits/orbit.gd` (`Orbit`): pure static functions for a body's
  position and velocity at time *t* on a circular orbit (radius, height
  off the plane, phase, angular speed), and the circular-orbit angular speed
  from the parent's mass and the gravity constant.
- This is the CPU reference that the orbit shader (2.4) must match.
- **Done:** `tests/orbits/test_orbit.gd` passes (its contract and the
  circular-orbit rules), and smoke passes.

### 2.3 Tier generator ✅
- `scripts/generation/tier.gd` (`Tier`, a Resource) exports one level's
  tuning: orbit band, thickness, plane tilt, radius range, size bias, mass
  density, spawn density on a jittered grid, minimum separation, a random
  inner-period range and the retrograde chance.
- `scripts/generation/tier_generator.gd`: a pure, deterministic function
  from (seed, parent path, parent radius, tier) to a `TierLayout` of packed
  child arrays (radius, mass, orbit radius, height, phase, angular speed)
  and one tilted ring plane.
- Speeds come from period only. A gravity-based speed mode is dropped for
  now.
- The level holds a list of tiers, any depth, starting with the
  prototype's three (giant → systems → ring bodies).
- **Done:** `tests/generation/test_tier_generator.gd` passes
  (determinism, ranges, separation, mass from volume,
  speeds, plane tilt, expected count, pre-conditions), and smoke passes.

### 2.4 Orbit renderer ✅
- `scripts/generation/orbit_renderer.gd` and
  `resources/shaders/orbit.gdshader`: draw one parent's children as a
  MultiMesh, with low-poly spheres orbiting on the GPU.
- It can hide and show single instances and tint them, and it keeps the
  shader's time in step with physics time.
- **Done:** `tests/generation/test_orbit_renderer.gd` passes (instance data
  matches the specs, hiding, tint, time), and smoke passes.

### 2.6 Hierarchy streaming ✅
- `scripts/generation/hierarchy_streamer.gd`: a parent's children are
  expanded (generated and drawn) within an expand distance and collapsed
  past a larger collapse distance (hysteresis).
- Ancestors stay drawn, so large bodies are always in the background.
- **Done:** `tests/generation/test_hierarchy_streamer.gd` passes (expand,
  collapse, hysteresis, a re-expanded parent gives the same children), and
  smoke passes.

### 2.7 Live bodies ✅
- `scripts/generation/live_body_pool.gd`: a drawn body becomes a real
  `MassBody` within its live radius, hiding its drawn copy, and goes back
  to drawn-only past its release radius.
- Each physics frame, live bodies move kinematically to exactly their
  drawn copy's position. The giant is always a real body.
- **Done:** `tests/generation/test_live_body_pool.gd` passes (promote,
  release, hysteresis, position matches the orbit, drawn copy hidden while
  live, one to one along a flight path, collapse frees live children). A
  live body crashing the player is covered by the existing
  `test_moving_body_crashes_into_the_player`, since it moves bodies the
  same way.

### 2.8 Generated level ✅
- `scenes/levels/generated_level.tscn` replaces `test_level.tscn` as the
  main scene, with the prototype's tuned values.
- The player spawns with its home system's velocity, and the camera's far
  plane covers the system.
- `MassTintDebug` also tints drawn bodies through the renderer. (It was
  removed in [player growth](11_player_growth.md)'s performance review.)
- Delete `test_level_body_is_heavier_than_player_starting_mass` and
  `LEVEL_SCENE` from `tests/bodies/test_mass_body.gd`.
- **Done:** smoke passes with the generated level as the main scene, and
  the tests pass (`tests/levels/test_player_spawn.gd`,
  `tests/levels/test_generated_level.gd`, and the drawn tint in
  `tests/ui/test_mass_tint_debug.gd`). The user will check how well the
  spawn orbit holds over minutes when tuning at the end of phase 2.

### 2.9 Performance ✅
- `tests/generation/test_benchmark.gd`: a headless benchmark of the physics
  frame with the tuned values (500 systems × 500 ring bodies).
- **Done:** `tests/generation/test_benchmark.gd` drives the generated
  level's streamer, pool and tint for 120 frames orbiting the home system
  and 240 frames flying through the systems at 300 u/s. The mean frame
  must stay under 2ms and the worst under 16.6ms.
- The first measurement was about 15ms per frame, nearly all in the pool,
  which checked about 5,000 drawn children every frame. Culling renderers
  by `reach()` and sharing batched `child_positions` brought it to a mean
  of 0.35ms orbiting and 0.56ms flying (debug build). The worst frames (6ms
  and 10ms) are the hitches when a ring is generated on expand: the next
  candidate for the performance phase.

## Performance evaluation

### Benchmark
`benchmarks/procedural_generation/` holds the benchmarks. Each runs with
`godot --headless --fixed-fps 60 -s benchmarks/procedural_generation/<bench>.gd -- [key=value ...]`
(the fixed step gives one physics tick of 1/60s each frame).
- `bench.gd`: the generated level with seed 12345, 60 warm-up frames, then
  600 frames (10s). The player is frozen and moved along a fixed path, so
  it can't crash. Scenarios: `orbit` circles the home system at the spawn
  distance (300). `ring` skims through the home ring at mid-radius,
  overtaking its bodies at twice their speed (the most live bodies). `fly`
  flies straight through the systems at `speed` (300 by default). Any tier
  field can be set (`rings.live_distance=120`), and `probe=1` times each
  step of the streamer and pool.
- `expand.gd`: one ring expanding, which causes the worst frames:
  `TierGenerator.generate`, `show_layout` and the first `child_positions`.
- `sweep.sh` runs the settings below one change at a time, and
  `summary.py` turns its output into a table. `ab.sh` repeats each
  scenario for A/B checks. `results.jsonl` is the baseline sweep.

"own" is the streamer, pool and tint together (`Time.get_ticks_usec`).
"frame" is the whole headless frame, including the physics server's step.
`Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS` can't be used per
frame: they hold the worst frame of each second. Headless doesn't render,
so the GPU's share (the orbit shader and about 6,000 drawn instances) isn't
covered. The figures come from the editor's debug binary, and release
GDScript is somewhat faster.

### Baseline (contracts off, ms)
Contracts on and off are within noise of each other, because
`Contract.require/ensure/invariant` evaluate their conditions even when
disabled.

| setting             | bodies                | scenario | own mean | own worst | frame worst | live max |
| ------------------- | --------------------- | -------- | -------- | --------- | ----------- | -------- |
| tuned               | 495 systems, 501 ring | orbit    | 0.52     | 1.17      | 1.82        | 20       |
| tuned               |                       | ring     | 1.31     | 3.75      | 4.35        | 134      |
| tuned               |                       | fly 300  | 0.62     | 4.67      | 5.28        | 127      |
| systems ×0.25       | 96                    | ring     | 0.97     | 2.19      | 3.14        | 120      |
| systems ×1.8        | 906                   | orbit    | 0.92     | 3.54      | 3.98        | 42       |
| systems ×1.8        | 906                   | ring     | 1.73     | 4.49      | 5.25        | 156      |
| rings ×0.25         | 132 ring              | ring     | 0.68     | 1.66      | 2.33        | 51       |
| rings ×1.8 (denser) | 908 ring              | ring     | 1.97     | 8.36      | 9.24        | 226      |
| rings ×3 (wider)    | 1,613 ring            | fly 300  | 0.74     | 9.19      | 9.70        | 226      |
| rings ×6.5 (wider)  | 3,311 ring            | orbit    | 1.40     | 3.66      | 4.27        | 78       |
| rings ×6.5 (wider)  | 3,311 ring            | fly 300  | 0.89     | 17.85     | 18.33       | 240      |
| ring expand 8000    | 501 ring              | orbit    | 0.93     | 3.90      | 4.38        | 20       |
| ring live 120       |                       | ring     | 2.03     | 4.33      | 5.07        | 266      |
| ring live 240       |                       | ring     | 3.62     | 6.00      | 7.17        | 519      |
| system live 6000    |                       | ring     | 1.69     | 4.11      | 4.79        | 189      |
| fly 3000 u/s        |                       | fly      | 0.35     | 0.80      | 1.29        | 20       |

- The steady cost scales with the live bodies (the pool moves each one,
  and physics steps it) and with the number of systems (the streamer and
  pool check every system each frame: about 1ms per 1,000).
- The worst frames are when a ring expands. Generating a 501-body ring
  takes 1.42ms, `show_layout` 0.50ms and its first positions 0.06ms.
  This grows linearly: 3,315 bodies take 8.8 + 3.1ms, which is over budget
  in the worst frame (18.3ms).
- Loading the level takes 20ms with the tuned values (210ms with ring
  expand 8000).

### Hot spots and options
Notes for later: none of these were applied (see the decision below). Each
was measured with `ab.sh` (5 runs each, contracts off) or `expand.gd`, then
reverted. The recommendations are from the review.

| # | option | before → after | flexibility cost | recommendation |
|---|---|---|---|---|
| E3 | `LiveBodyPool._move_or_release` reads `renderer.child_positions(time)[index]` (cached, shared with promote) in place of `child_position` | ring mean 1.35 → 1.01, p95 2.59 → 2.10. orbit 0.51 → 0.45 | none: one line, and `child_positions` already equals `child_position` by contract | take |
| E1 | wrap the costly checks (`_hierarchy_is_consistent`, `_live_bodies_match_hidden_copies`, `TierLayout.append`'s invariant, `_children_in_range`) in `if Contract.enabled:` | generate 1.42 → 0.96 per ring. ring mean 1.35 → 1.23, worst 4.13 → 3.83 | small: one pattern to follow for expensive checks. The cheap ones stay as they are | take |
| E2b | the streamer calls `_tier_for` once per child when its parent expands, and keeps the tiers | `streamer.expand` 0.29 → 0.19. orbit own 0.51 → 0.38 | about 20 lines, a cache kept in step with `_remove_slots`. Inspector tuning still works, since it keeps `Tier` references | skip for now. Take it if systems go towards 1,000 |
| E2a | look up the tier once per parent, not per child | `streamer.expand` 0.29 → 0.13 | breaks the contract that every lookup goes through `_tier_for(depth, path, …)` (the hook for a procedural tier provider) | don't take |
| E4 | `TierGenerator.generate` reads the tier's fields into locals, compares squared radii and appends to the layout's arrays directly | generate 0.96 → 0.69 on top of E1 (1.42 → 0.91 alone) | bypasses `TierLayout.append`, and orbit radii change in the last digits (float64 `sqrt` in place of `Vector2.length`) | skip unless rings go past about 1,500 bodies |
| — | spread or thread ring generation, and reuse `MassBody` nodes | not measured | changes the streamer's contract (a near parent is expanded after `update`) | only if rings must be much bigger |

### Whole frame (headless, contracts off, ms)
The whole headless frame includes every script, gravity and the physics
server's step, but not rendering.

| setting | scenario | frame mean | frame worst | generation's share of the mean |
|---|---|---|---|---|
| tuned | orbit | 0.98 | 1.82 | 0.52 |
| tuned | ring | 1.96 | 4.35 | 1.31 |
| tuned | fly 300 | 1.08 | 5.28 | 0.62 |
| systems ×1.8 | ring | 2.41 | 5.25 | 1.73 |
| ring live 240 | ring | 4.81 | 7.17 | 3.62 |
| rings ×3 (wider) | fly 300 | 1.22 | 9.70 | 0.74 |
| rings ×6.5 (wider) | fly 300 | 1.36 | 18.33 | 0.89 |

Generation is about half to three quarters of the headless frame. The
GPU's share isn't measured. A windowed run of the benchmark would give the
true whole frame; the v3 prototype's windowed run on an M1 had a worst
frame of 17.9ms.

### Decision
- 2026-11-23: the user is happy with the performance as it is, so no
  optimisation was applied. The options above stay as notes. If the
  settings grow, take E3 and E1 first (nearly free). Then take E2b if the
  systems go towards 1,000, or E4 and spread-out generation if rings pass
  about 1,500 bodies (a 3,300-body ring's expand frame is over budget).
