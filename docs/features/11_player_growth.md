# Player growth
**Status:** done ✅ (Phase 2, steps 2.5 and 2.10 to 2.14)

The player gets bigger as it collects mass, so it can consume mass that was
bigger than it. Agreed: the player's radius grows with its mass. Thrust
doesn't scale: only the shop changes booster strength.

## Idea
In the user's words: "Lets move onto player growth using bodies generated
from the hierarchystreamer. I want the player to have a radius that sucks in
objects that are smaller (or the same) mass as the player. When an object is
being sucked it should move with the player and lerp it's position to the
player and then delete. The mass should then be added onto the player, being
multiplied by some conversion. This conversion multiplier will be a shop stat
later in development. In the level, the lowest tier (smallest children)
should always be suckable by the player (so have some ceiling based on the
player mass) but the mass should be randomised but greater than some
minimum."

## Prototype log
- v1: pickup radius sucks in live bodies no heavier than the player, lerps
  and shrinks them onto the ship, then adds mass × conversion. Ring masses
  are rewritten to lie in [min_mass, player mass × ceiling]. The ship scales
  with mass^(1/3). User: "so hard to test" with everything orbiting.
- v2: test mode (on by default): orbits frozen, ship starts at rest inside
  the home ring, ship gravity off.
- v3: the user's editor changed production files (fuel and uids); these
  were reverted and an `infinite_fuel` test toggle was added. User: "The
  suck is perfect." Accepted.

## Accepted behaviour
The spec for the rewrite, from `prototypes/player_growth/main.gd`.

### Keep
- **Pickup:** each physics frame, catch every live body whose mass is at
  most the player's and whose surface is within the pickup radius of the
  ship's collider surface (`distance - body.radius <= pickup_radius +
  ship_collider_radius`). A heavier body is never caught.
- **Suck:** a caught body leaves its orbit (it is no longer moved by the
  live body pool, and its drawn copy stays hidden). Its collision turns off
  at once, so a caught body can't trigger a contact. It moves with the ship:
  `position = ship + start_offset * (1 - t²)`, with `t = elapsed /
  suck_duration`, and its mesh shrinks by the same factor. At `t = 1` it is
  deleted and the player gains `body.mass * mass_conversion`.
- **Consumed bodies stay gone:** a consumed child, keyed by its parent's
  path and its index, stays hidden if its ring collapses and expands again.
- **Lowest-tier masses:** when a lowest-tier ring is generated, each
  child's mass is `lerp(min_mass, ceiling, pow(t, mass_bias))`, where
  `ceiling = max(min_mass, player_mass * ceiling_fraction)` at generation
  time and `t` is the child's radius fraction within the tier's radius
  range (so bigger rocks are heavier). The player never loses mass, so at
  `ceiling_fraction <= 1` every lowest-tier body stays suckable. The debug
  tint must agree with these masses.
- **Ship growth** (from step 2.5, kept on through the prototype): the mesh,
  collider radius and camera distance scale by `(mass / starting_mass) ^
  size_exponent`, and the pickup radius scales with them.
- Thrust doesn't scale with mass (as agreed for step 2.5).

### Tuned values
| value | setting |
|---|---|
| `pickup_radius` | 8.0 (scales with ship size) |
| `suck_duration` | 0.5 s, ease `t²` |
| `shrink_while_sucked` | on |
| `mass_conversion` | 1.0 (a shop stat later) |
| `min_mass` | 0.1 |
| `ceiling_fraction` | 1.0 |
| `mass_follows_radius` | on |
| `mass_bias` | 1.5 |
| `size_exponent` | 1/3 |
| player starting mass | 1.0 (unchanged) |

### Edge cases noticed
- Only live bodies can be caught, so the pickup radius is capped in effect by
  the lowest tier's `live_distance` (60). A larger radius needs bodies to be
  promoted further out.
- The ceiling uses the player's mass when the ring is generated, so rings
  made later hold heavier bodies.
- As mass grows the ship accelerates more slowly (thrust is fixed). This is
  the agreed design, but the user hasn't yet tried it at a large mass.
- Bodies inside the pickup radius at spawn are eaten on the first frame.

### Tried and dropped, or test-only
- Pure random lowest-tier mass (`mass_follows_radius` off): not chosen.
- `thrust_scales_with_mass`: a toggle only, off.
- Test mode (frozen orbits, start at rest in the ring, no ship gravity,
  infinite fuel): only for testing, not for production.

## Contracts
Agree each API's contract with the user at the start of its step.

### Tier mass cap (`scripts/generation/tier.gd`)
Extends the `Tier` contract in
[procedural generation](10_procedural_generation.md).
- Mass cap group: `mass_ceiling_fraction` (default 0, uncapped),
  `mass_min` (default 0.1) and `mass_bias` (default 1.5).
  `is_mass_capped()` is `mass_ceiling_fraction > 0`.
- The defaults stay uncapped, so `systems_tier.tres` is unchanged.
  `rings_tier.tres` sets `mass_ceiling_fraction = 1.0`.
- `require_valid` adds: `mass_ceiling_fraction ≥ 0` and, for a capped
  tier, `mass_min > 0` and `mass_bias > 0`.

### TierGenerator.generate mass cap (`scripts/generation/tier_generator.gd`)
- `generate(level_seed, path, parent_radius, tier, focus_mass := NAN)`.
- A capped tier requires a finite `focus_mass > 0`. A broken pre-condition
  is reported and returns an empty layout. An uncapped tier ignores
  `focus_mass` and keeps `mass = mass_density × radius³`.
- For a capped tier, with `ceiling = max(mass_min, focus_mass ×
  mass_ceiling_fraction)`:
  - `mass = lerp(mass_min, ceiling, t ^ mass_bias)`, with `t = (radius −
    radius_min) / (radius_max − radius_min)`, or `t = 1` (the ceiling) when
    `radius_min == radius_max`
  - every mass is in [`mass_min`, `ceiling`], and mass never decreases as
    radius grows
  - if `mass_ceiling_fraction ≤ 1` and `focus_mass ≥ mass_min`, every mass
    is at most `focus_mass`
- The cap draws no random numbers, so every other field (radius, orbit,
  height, phase, speed, plane) is identical to the same tier uncapped.
- Deterministic for the same seed, path, parent radius, tier and
  `focus_mass`.

### HierarchyStreamer focus mass (`scripts/generation/hierarchy_streamer.gd`)
Extends the `HierarchyStreamer` contract in
[procedural generation](10_procedural_generation.md).
- Optional export `focus_mass: MassComponent` (Components group). Each
  expansion passes `focus_mass.current_mass` to the generator (NAN when
  unset).
- At start-up, if any tier is capped, `focus_mass` must be set. If not, it
  reports the problem and stays empty, like the other tier checks.
- `mass_cap_warning()` returns a message, or `""`, when a capped tier's
  `mass_min` is above `focus_mass.starting_mass × mass_ceiling_fraction`
  (its bodies could be heavier than the player). At start-up a debug build
  prints it with a `[Debug]` prefix. It is not an error.
- Re-expanding a parent gives the same geometry as before. In a capped
  tier, its masses follow the focus mass at the time it expands.

### HierarchyStreamer.remove (`scripts/generation/hierarchy_streamer.gd`)
An eaten body and everything below it leave the hierarchy for good.
- `remove(path)` requires a child path (not the root `[]`) whose parent is
  expanded and whose last index is within that parent's layout. A broken
  pre-condition is reported and does nothing.
- Afterwards:
  - `is_removed(path)` is true, and so is `is_removed` of every path below
    it
  - if `path` was expanded, its whole subtree has collapsed as normal
    (deepest first, `collapsing` emitted before each renderer is freed)
  - a removed path never expands again, however near the focus is
- `removed(path)` is emitted after the subtree is gone.
- `removed_indices(parent_path)` lists the removed children of a parent,
  so the pool can hide them when it expands without checking every child.
- Invariant: no expanded path is removed or below a removed path.
- The removed set lasts as long as the streamer, so a restart clears it.

### LiveBodyPool.take (`scripts/generation/live_body_pool.gd`)
- `take(body) -> TakenBodies` requires a live body that isn't
  `root_body`. A broken pre-condition is reported and returns an empty
  result.
- In order, it:
  1. takes `body` and every live body below it out of the pool, without
     freeing them or showing their drawn copies
  2. sums the masses of every drawn-only descendant in the expanded
     layouts (not live, not already removed) into `drawn_mass`
  3. calls `streamer.remove(path)`, so the collapse frees renderers but
     none of the taken bodies
- `TakenBodies` (`scripts/generation/taken_bodies.gd`) holds `bodies:
  Array[MassBody]` (`body` first, then its live descendants, all now owned
  by the caller) and `drawn_mass: float`.
- Afterwards, `live_count()` has dropped by `bodies.size()`, the pool never
  moves or frees them again, and `body`'s drawn copy stays hidden. When a
  parent expands, the pool hides its removed children's copies at once, so
  they are never promoted.
- Only expanded descendants count. A never-expanded grandchild ring has no
  masses yet, so it adds nothing.
- Invariant (extends the pool's): live bodies and hidden copies match one
  to one, and every other hidden copy is a removed child.

### AbsorbEffect (`scripts/effects/absorb_effect.gd`)
- A `Node` on the player that pulls caught bodies onto the ship. Exports
  `ship: Node3D` (Components), and `suck_duration` (0.5, > 0) and `shrink`
  (on) in the Absorb group.
- `absorb(body, extra_mass := 0.0)` requires a ship, a valid `MassBody`
  not already being absorbed, and `extra_mass ≥ 0`. A broken pre-condition
  is reported and the body is ignored.
- Straight away the body stops being a gravity source, is reparented under
  the effect (keeping its world position), and its collider is disabled
  (deferred, so it is off by the next physics step). Its
  `sync_to_physics` is turned off, so it moves directly rather than
  sweeping. `is_absorbing(body)` is true.
- `advance(delta)` runs each physics frame. For each body, with `t =
  elapsed / suck_duration`:
  - `position = ship + start_offset × (1 − t²)`, so it follows the ship
    however the ship moves
  - with `shrink`, its mesh scale is `start_scale × (1 − t²)`
- When `t ≥ 1` the body sits on the ship, is freed once, and
  `absorbed(mass)` is emitted once with `body.mass + extra_mass`.
- `absorbing_count()` is the number in flight. They are kept in flat
  arrays (body, offset, scale, elapsed, mass) with swap-remove.
- Changed 2026-11-25 (see [game feel](17_game_feel.md)): with squash on
  (the default), a caught body squashes, then stretches towards the ship.

### LiveBodyPool.bodies_within (`scripts/generation/live_body_pool.gd`)
- `bodies_within(centre, reach, max_mass) -> Array[MassBody]` requires
  `reach ≥ 0`. A broken pre-condition is reported and returns `[]`.
- It returns every live body (never `root_body`) with `distance(centre,
  body) − body.radius ≤ reach` and `mass ≤ max_mass`, in no set order.
  Positions are this frame's, so it is called after the pool's update
  (priority -3).
- `is_live(body)` reports whether the pool still owns a body.

### PickupComponent (`scripts/components/pickup_component.gd`)
- Exports, in Components: `body: RigidBody3D`, `mass_component`,
  `collider: CollisionShape3D` (with a sphere shape), `pool:
  LiveBodyPool` and `absorb: AbsorbEffect`. In Pickup: `pickup_radius`
  (8.0, ≥ 0), `mass_conversion` (1.0, > 0) and `size_scale` (1.0, > 0,
  set by the growth component in 2.5).
- `reach()` is `pickup_radius × size_scale + the collider sphere's
  radius`, so the radius is measured from the ship's surface.
- `collect()` runs each physics frame (default priority, after the pool).
  Without a pool or an absorb effect it does nothing, so the player works
  in a level without a pool. Otherwise:
  - it asks for `pool.bodies_within(body position, reach(), current
    mass)`. Equal mass is catchable.
  - it takes them heaviest first, skipping any no longer live (a parent
    taken earlier took its live children with it)
  - for each `pool.take` result, the first body goes to
    `absorb.absorb(body, drawn_mass)` and the rest to
    `absorb.absorb(child)`
  - afterwards every caught body is held by the absorb effect, and no
    body heavier than the player is ever caught
- On `absorb.absorbed(mass)`, `mass_component.current_mass += mass ×
  mass_conversion`.
- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): with a `cargo`, absorbed mass fills
  the cargo instead and nothing is caught while it is full.
- `Player.stop_flight()` also disables the pickup (see
  [lose flow](09_lose_flow.md)). Bodies already in flight still arrive.

### GrowthComponent (`scripts/components/growth_component.gd`)
- Exports, in Components: `mass_component` (required), and optionally
  `mesh: Node3D`, `collider: CollisionShape3D` (with a sphere shape),
  `camera: CameraComponent` and `pickup: PickupComponent`; an unset one is
  skipped. In Growth: `size_exponent` (0.3333, > 0).
- `size()` is `(current_mass / starting_mass) ^ size_exponent`, so 1 at
  the starting mass. It requires `starting_mass > 0`.
- At ready it records the base mesh scale, collider radius and camera
  distance, and duplicates the collider's shape, since every instance of
  `player.tscn` shares the scene's `SphereShape3D`.
- At ready and on every `mass_changed`: `mesh.scale = base × size()`, the
  collider radius `= base × size()`, `camera.distance = base × size()`
  and `pickup.size_scale = size()`.
- Thrust and torque are unchanged. The body's mass follows `MassComponent`,
  so a heavier ship accelerates more slowly (agreed).
- Turning is unaffected by growth: `player.tscn` fixes the body's
  `inertia` at `(0.1, 0.1, 0.1)`, so neither mass nor the grown collider
  changes it (agreed: slower turning was bad gameplay). This changes the
  flight contract in [flight](03_flight.md).
- A grown collider touching a heavier body loses, as any contact does.

## Steps
Order: 2.10, 2.11a, 2.11b, 2.12, 2.13, 2.5, 2.14. (2.12 and 2.13 were
swapped, so the absorb effect exists before the pickup that uses it.)

### 2.10 Capped tier masses ✅
- `Tier` gets an optional mass cap: `mass_min`, `mass_ceiling_fraction` (0
  keeps `mass_density × r³`) and `mass_bias`.
- `TierGenerator.generate` takes an optional `focus_mass`. A capped child's
  mass is `lerp(mass_min, max(mass_min, focus_mass × fraction),
  radius_fraction ^ mass_bias)`.
- `HierarchyStreamer` gets an optional `focus_mass: MassComponent` and
  passes its current mass to the generator. `rings_tier.tres` takes the
  tuned values (0.1, 1.0, 1.5). `generated_level.tscn` sets the
  streamer's `focus_mass` to the player's `MassComponent` (pulled forward
  from 2.14, since a capped tier needs it to start).
- **Done:** the generator and streamer tests pass (capped masses in range,
  never above the focus mass, ordered by radius, uncapped tiers unchanged,
  still deterministic for the same focus mass), and smoke passes.

### 2.11a Removing eaten paths ✅
- `HierarchyStreamer.remove(path)`: collapses an eaten body's subtree and
  never expands it again. `is_removed(path)` and the `removed` signal.
- **Done:** `tests/generation/test_hierarchy_streamer.gd` passes (removed
  subtree collapses, never re-expands, descendants count as removed, bad
  paths rejected), and smoke passes.

### 2.11b Taking live bodies ✅
- `LiveBodyPool.take(body) -> TakenBodies`: takes a live body and its live
  descendants out of the pool, sums the drawn-only descendants' mass, and
  removes the path from the streamer.
- A removed child's drawn copy stays hidden, also after its parent
  re-expands, and it is never promoted.
- Eating a parent eats its whole subtree: its live children are absorbed
  like any pickup, and the drawn ones' mass arrives with the parent.
- **Done:** `tests/generation/test_live_body_pool.gd` passes (a taken body
  is no longer moved or freed, descendants come with it, drawn mass is
  summed, copies stay hidden through release and re-expansion, the
  one-to-one invariant holds), and smoke passes.

### 2.12 Absorb effect ✅
- `scripts/effects/absorb_effect.gd`: turns off a caught body's collider,
  moves it with the ship (`ship + offset × (1 − t²)`) over
  `suck_duration` while shrinking it, then frees it and emits
  `absorbed(mass)`. A caught body stops being a gravity source.
- **Done:** `tests/effects/test_absorb_effect.gd` passes (follows a moving
  ship, reaches it at `suck_duration`, shrinks, can't collide, freed once,
  emits once with its mass), and smoke passes.

### 2.13 Pickup component ✅
- `scripts/components/pickup_component.gd` on the player. Each physics
  frame it catches every live body no heavier than the player whose
  surface is within `pickup_radius` of the ship's surface, takes it from
  the pool and hands it to the absorb effect.
- When a body is absorbed, the player gains `mass × mass_conversion`. A
  taken parent's `drawn_mass` arrives with the parent.
- **Done:** `tests/components/test_pickup_component.gd` passes (catches
  lighter or equal bodies in range, never heavier or out of range, mass
  gained with the conversion), and smoke passes.

### 2.5 Player grows with mass ✅
- `scripts/components/growth_component.gd`: the mesh, collider radius,
  camera distance and pickup radius scale by `(mass / starting_mass) ^
  size_exponent` (1/3). Thrust and torque are unchanged.
- **Done:** `tests/components/test_growth_component.gd` passes, and smoke
  passes.

### 2.14 Level wiring ✅
- Add the pickup component, absorb effect and growth component to
  `player.tscn`. Connect the pickup to the `LiveBodyPool`, and the
  streamer's `focus_mass` to the player, in `generated_level.tscn`.
- The player's `inertia` is fixed at `(0.1, 0.1, 0.1)`, so growth doesn't
  slow turning (agreed while wiring: Godot derived inertia from the grown
  collider, giving m^(5/3)). `test_player.gd`'s turning test now checks
  the same rate at 8× mass.
- **Done:** `tests/levels/test_generated_level.gd` passes a scenario of
  flying into the home ring and gaining mass without losing, and smoke
  passes.

## Performance evaluation

### Benchmark
`benchmarks/player_growth/bench.gd` (`godot --headless --fixed-fps 60 -s
benchmarks/player_growth/bench.gd -- scale=1 contracts=0`). Agreed load: the
generated level (seed 12345), the ship lapping its home ring at mid-ring
(105 from the planet), with the pickup radius and speed both scaled by 1×,
5× and 10× (8 / 20 u/s, 40 / 100 u/s, 80 / 200 u/s). 60 warm-up frames,
then 600 (10 s). The ship follows a fixed path, frozen with no collision,
so it can't crash. It times `PickupComponent.collect`,
`AbsorbEffect.advance` (which includes the mass gain and the growth
update), `MassTintDebug._process`, the whole frame, and the physics step.
Agreed budget: the feature's own code under 0.5ms mean and 2ms worst, and
the whole headless frame under 16.6ms.

### Baseline (contracts off, ms)
Contracts on add nothing measurable (within 0.01ms on every figure).

| scale | pickups/s | in flight (max) | live (mean) | collect mean / p95 / worst | absorb mean / worst | tint mean / p95 / worst | frame mean / p95 / worst | physics mean / worst |
|---|---|---|---|---|---|---|---|---|
| 1× | 10.0 | 8 | 74 | 0.04 / 0.16 / 0.38 | 0.008 / 0.05 | 1.14 / 7.34 / 8.61 | 2.65 / 8.66 / 10.15 | 1.05 / 3.88 |
| 5× | 40.6 | 54 | 18 | 0.05 / 0.19 / 0.32 | 0.020 / 0.16 | 2.98 / 7.74 / 9.54 | 4.19 / 9.04 / 11.51 | 0.78 / 3.98 |
| 10× | 34.1 | 80 | 18 | 0.04 / 0.20 / 0.39 | 0.016 / 0.18 | 1.67 / 7.55 / 9.22 | 2.89 / 9.08 / 11.28 | 0.78 / 4.00 |

- The feature's own code is well within budget at every rate: `collect`
  stays under 0.4ms worst, and `absorb` under 0.2ms with 80 in flight.
- The pickup rate saturates. At 5× and 10× the whole home ring is eaten
  (both gain 158.6 mass), so 10× has fewer pickups per second. The reach
  also grows with the ship (28 at 1×, 220 at 5×, 437 at 10×), far past
  the ring's `live_distance` (60), so catching is limited by which bodies
  are live, not by the radius.
- The hot spot is `MassTintDebug`. Each time the player's mass changes it
  re-tints every drawn body (about 10 renderers × 500), at about 7.5ms a
  time. Pickups now change the mass 10–40 times a second, so p95 frames
  went from about 2ms to about 9ms. It also runs with the tint disabled
  (`enabled = false`, as in release builds), rewriting the untinted
  colour: the same 7.5ms. Without the tint, the frame is 1.26–1.60ms mean
  and 1.76–2.42ms p95.

### Hot spots and options
Each was measured with the benchmark (contracts off) and then reverted.

| # | option | before → after | flexibility cost | recommendation |
|---|---|---|---|---|
| T1 | re-tint drawn bodies only when the tint is active (or has just switched on or off) | disabled tint (release): 2.91 → 0.02 mean, 10.28 → 0.05 worst. Frame 4.13 → 1.27 mean, 8.94 → 1.75 p95 | none: a one-line condition. It is really a bug fix | take |
| T2 | in `_tint_drawn`, only upload colours that change | active tint: about 7.5 → 5.2 per re-tint (p95 7.74 → 5.27) | small: one comparison | skip: T4 does much better |
| T4 | as T1, and when the mass only grew, recolour just the bodies that crossed (`old < mass ≤ new`) green; any other change does a full re-tint | active tint: 2.98 → 0.15 mean, 7.74 → 0.59 p95, 9.54 → 1.10 worst. Frame 4.19 → 1.39 mean, 9.04 → 2.07 p95 | about 15 lines in a debug tool, and a second path to keep in step with the full re-tint. The tint tests pass unchanged | take (includes T1) |

### Decision
- 2026-11-23: the user chose to remove `MassTintDebug` entirely for now
  (script, tests, level node, and its use in both benchmarks and
  `test_benchmark.gd`). They will add a different debug tint later.
  `OrbitRenderer.set_tint` stays. None of T1, T2 or T4 was applied. If a
  tint like the old one comes back, T4's approach (recolour only the bodies
  the player has just outgrown) is the measured way to keep it cheap.
- The pickup, absorb and growth code needed no optimisation.

### Final figures (contracts off, ms; contracts on within 0.3ms)
| scale | pickups/s | in flight (max) | collect mean / p95 / worst | absorb mean / worst | frame mean / p95 / worst | physics mean / worst |
|---|---|---|---|---|---|---|
| 1× | 10.0 | 8 | 0.04 / 0.16 / 0.34 | 0.008 / 0.04 | 1.56 / 2.16 / 4.08 | 1.09 / 3.62 |
| 5× | 40.6 | 54 | 0.05 / 0.19 / 0.25 | 0.020 / 0.14 | 1.26 / 1.81 / 3.76 | 0.82 / 3.34 |
| 10× | 34.1 | 80 | 0.04 / 0.20 / 0.45 | 0.017 / 0.16 | 1.23 / 1.85 / 4.98 | 0.79 / 4.23 |

Everything is within the agreed budget: the feature's own code is under
0.5ms worst, and the whole headless frame under 5ms worst.

### Systems retune (2026-11-23)
The user raised the systems tier to `spawn_density = 3e-9`, `cell_size =
400` and `min_separation = 400` (about 1,980 systems, up from 500), and
chose to keep it and optimise. The two count tests now expect 1,980
(`test_tier.gd`, ±5; `test_generated_level.gd`, ±300). `test_benchmark.gd`
then failed: orbit worst 17.8ms, fly mean 2.23ms.

The editor also dropped the level's Player overrides (the pickup's `pool`
and `gravity_constant = 10`), so nothing could be picked up. They are back,
and `test_level_wires_the_pickup_to_the_pool_and_sets_gravity` now guards
them.

Probe (`benchmarks/procedural_generation`, contracts on, ms, mean / worst):
`streamer.expand` 1.35 / 3.79 orbiting and 1.60 / 7.97 flying (the loop
over the giant's ~2,000 children, with a `_tier_for` call each), then
`pool.move` 0.36 / 0.74 and 0.58 / 1.41.

| # | option | before → after | flexibility cost | decision |
|---|---|---|---|---|
| E3 | `_move_or_release` reads the cached `child_positions(time)[index]` | `pool.move` 0.36 → 0.10 orbit, 0.58 → 0.17 fly. Own 2.22 → 1.90 orbit, 3.01 → 2.62 fly | none | applied |
| E1 | the costly checks (`_hierarchy_is_consistent`, `_live_bodies_match_hidden_copies`, `_children_in_range`, `TierLayout.append`'s invariant) skip under `if Contract.enabled:` | contracts off: own 1.94 → 1.82 orbit, 2.59 → 2.34 fly (fly worst 10.5 → 7.8) | small: one pattern for costly checks | applied |
| R1 | tuning: rings `expand_distance` 2000 → 1000 (collapse 1500) | seed 7, contracts on: rings drawn 36–39 → 9–13. Own worst 6.0 → 3.7 orbit, mean 1.84 → 1.75 | none in code. Rings appear later (1000 from their system) | applied by the user (`expand_distance = 1000`, collapse kept at 3000) |
| R1b | as R1 at 700 (collapse 1050) | drawn 4–8. Own worst 4.4 fly, mean 1.72 | none in code. Rings appear at 700 | not needed |
| E2b | cache each child's tier when its parent expands | not yet measured at this density (0.29 → 0.19 at 500 systems) | about 20 lines, kept in step with `_remove_slots` | not needed for now: take it if the mean budget is missed again |

After E3 and E1, `test_benchmark.gd` (random seed, contracts on) still
fails: orbit mean 1.64–1.90 and worst 17.3–27.7, fly mean 1.83–2.29 and
worst 8.1–26.6. The worst frames are ring generation when several dense
systems come within `expand_distance` at once.

With E3, E1 and R1, `test_benchmark.gd` passes on three runs (random seed,
contracts on): orbit mean 1.32–1.46ms and worst 4.1–7.7ms, fly mean
1.50–1.67ms and worst 4.5–9.6ms, with 6–20 rings drawn. The full suite
(346) and the smoke run pass.
