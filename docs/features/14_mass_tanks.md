# mass_tanks
Started 2026-11-24. The live phase is in `.claude/bin/feature status`.

## Idea
What the user imagines, in their words: how it should look, feel and play.

"As phase 5 is generally making the game feel we're going to try out some
different things to follow the fun in this game. Firstly, we're going to
focus on the main game loop. Lets try instead of mass making you bigger,
you collect mass to fill up the tank and once the tank's filled up you can
warp out and spend it. In the shop a stat you can increase is number of
tanks. Show the number of tanks similar to the thrust holo readout but have
yellow-ish bars."

## Prototype log
One line per iteration: what changed and what the user said about it.
- v1: pickups fill tanks (`tank_capacity` 10) instead of growing the ship;
  warp once a tank is full, banking what's stored; "Mass tanks" shop stat
  (+1 tank per level); yellow tank gauge under the thrust reserve, one
  10-segment bar per tank. User: "I don't want to have like 30 tanks but
  like 3 tanks, each taking X amount of mass."
- v2: tanks capped at `max_tanks` (3), the shop's button locks at the cap.
  The gauge is one bar with one big segment per tank, each filling
  smoothly, with unbought tanks shown as dim empty slots. User: you should
  start with one tank and buying more adds it to the gauge (the dim slots
  looked like 3 tanks you couldn't fill); you shouldn't suck up mass while
  full; where is the mass maximum for collecting?
- v3: unbought slots hidden (the gauge grows as you buy tanks), pickups
  stop while every tank is full, and a `ship_mass` export (the collect
  ceiling) on the level root. User asked where to change the collectable
  mass values.
- v4: level-root overrides for the ring pickups' masses (a runtime copy of
  `rings_tier.tres`: `pickup_mass_min`, `pickup_mass_ceiling_fraction`,
  `pickup_mass_bias`) and `mass_conversion`. User: changing gravity on the
  player didn't work (the level overrides it to 10).
- v5: `gravity_constant` export on the level root, applied to the player's
  `GravityReceiverComponent`. User tuned `gravity_constant` 10000,
  `pickup_mass_min` 0.01, `pickup_mass_ceiling_fraction` 0.07, and asked
  for an exponent to control gravity falloff.
- v6: `gravity_falloff_exponent` (default 2, Newtonian): the player's
  gravity receiver is swapped for a prototype one using
  `1 / distance ^ exponent`. User tried exponent 3, and asked for values
  that are strong near a planet's rings but fall off quickly outside them.
  Suggested exponent 4 with `gravity_constant` 6e5 (pull ≈ 1.5× thrust at
  the inner ring, 0.2× at the outer, 0.04× at 200 units). User asked to
  surface the starting thrust and all the shop growth values.
- v7: `thrust` export (the booster force before upgrades) and a "Shop
  growth" group: step, base cost and cost growth for each of the six shop
  stats, applied to runtime copies of the upgrade resources. User asked
  for a starting speed of 0, facing tangential to the home planet's
  outward vector.
- v8: `start_at_rest` (on): after PlayerSpawn, the velocity is zeroed and
  the ship faces along the ring (in the ring's plane, at right angles to
  the outward vector). User: "Does the ship have a constant forward
  force? I want rid of that. The thrust should speed up the ship and then
  it should slow down again." (No such force: there's no drag, and arcade
  flight keeps the speed.)
- v9: `drag` export (0.5), set as the player's `linear_damp` (replace
  mode), so speed bleeds away without thrust. Top speed is thrust ÷ mass
  ÷ drag. User: "This is better." But the path prediction is just a
  straight line forward.
- v10: the prediction was right: arcade flight re-aimed all the velocity,
  gravity included, so gravity only became forward speed (also the
  "constant forward force"). Now `gravity_drift` (on) keeps gravity's
  velocity as a separate drift that steering leaves alone, so gravity
  bends the path. The minimap's predictor is swapped for one that models
  the drift and the falloff exponent. User asked to surface the starting
  value of each shop stat.
- v11: "Starting stats" group on the level root: ship mass (starting
  size), fuel tank size, refill time, thrust, pickup radius and the three
  turn torques, set before the upgrades multiply them. User: make mass
  affect speed ("if twice as heavy you need twice the thruster strength").
  Thrust was already force ÷ mass, but mass never changed in a run.
- v12: cargo weight: the body's mass is `ship_mass + stored ×
  cargo_weight` (0.1, so a full 10-mass tank doubles it), slowing thrust.
  Picking mass up keeps momentum (`cargo_conserves_momentum`). Gravity,
  drag, turning, collecting and crashes still use the core ship mass.
  User asked for an exponent on mass conservation (0 none, 1 realistic,
  above 1 stronger).
- v13: `cargo_mass_exponent` (1): the ship handles as `ship_mass ×
  (weight ÷ ship_mass) ^ exponent`, for both thrust and the pickup
  momentum loss. User tuned `thrust` 200, `drag` 0.25, `cargo_weight`
  0.5, `fuel_refill_time` 7.5, `refill_rate_step` 0.1,
  `gravity_constant` 10000 with exponent 3.5, and
  `pickup_mass_ceiling_fraction` 0.1. They asked for the cargo tank size
  (wanting 5).
- v14: `tank_capacity` renamed `cargo_tank_size` (group "Cargo tanks"),
  default 5. User: you need to fill all cargo tanks to warp out.
- v15: `warp_needs_all_tanks` (on): warping needs every owned tank full.

## Accepted behaviour
Filled in before acceptance. This is the spec for the rewrite: the behaviours
to keep, the tuned values the user liked, and what was tried and dropped.
From `prototypes/mass_tanks/` (`main.gd` and the tuned `main.tscn`). The
user accepted it to integrate into the main game with their values, and
asked that every value tuned in the prototype stays adjustable.

### Keep
- **Cargo tanks replace growth:** collected mass fills cargo tanks instead
  of growing the ship. The ship's core mass (`starting_mass × starting size
  multiplier`) stays fixed for the run, so the collect ceiling, the
  crash test (heavier contact) and the rings' mass ceiling stay fixed too.
- **Tanks:** each holds `cargo_tank_size` mass. A run starts with
  `base_tanks`, plus one per level of the new **Mass tanks** shop stat, up
  to `max_tanks` (the shop locks the stat at the cap). Stored mass fills
  the tanks in order and is clamped to `tanks × cargo_tank_size`.
- **No pickups while full:** once every tank is full, the ship catches
  nothing new. Pickups already flying in still arrive, and their extra is
  lost.
- **Warp out:** needs every owned tank full (`warp_needs_all_tanks`;
  otherwise `tanks_to_warp` full tanks). Warping banks the stored mass
  (`bank_partial_tank`: all of it, else only the full tanks) minus
  `warp_spend`, never below 0. It replaces the old `warp_cost` on
  collected growth.
- **Cargo weight:** the body handles as `core × (real ÷ core) ^
  cargo_mass_exponent`, where `real = core + stored × cargo_weight`.
  Thrust is a force, so it accelerates the ship by thrust ÷ that mass.
  Picking mass up keeps momentum (`cargo_conserves_momentum`): the
  velocity and the gravity drift are scaled by old ÷ new handling mass.
  Gravity's acceleration, drag, turning, collecting and crashes use the
  core mass, not the cargo.
- **Gravity falloff:** acceleration towards each heavier body is
  `gravity_constant × mass ÷ distance ^ gravity_falloff_exponent`, with the
  distance floored at the body's radius. It's an acceleration, so it
  doesn't depend on the ship's mass.
- **Gravity drift:** gravity's velocity is kept as a separate drift that
  arcade flight doesn't steer. Arcade flight aligns only `velocity −
  drift` to the facing and adds the drift back. The drift is damped by the
  ship's drag like the rest of the velocity. Without this, gravity only
  turned into forward speed (felt as "a constant forward force") and the
  path prediction was a straight line.
- **Drag:** the ship's `linear_damp` (replace mode), so speed bleeds away
  without thrust. Top speed is thrust ÷ mass ÷ drag.
- **Path prediction:** the minimap's predictor models the drift split and
  the falloff exponent, so the predicted path curves under gravity.
- **Start at rest:** after the spawn, the velocity (and drift) is zero and
  the ship faces along the home ring: in the ring's plane, at right angles
  to the planet's outward vector.
- **Cargo gauge:** a holo panel under the thrust reserve, styled like it
  but yellow: one segment per owned tank (buying one adds a segment),
  each filling smoothly, amber while filling and gold when full. Full
  tanks pulse once you can warp. Title `// MASS TANKS full/owned`,
  readout `MASS stored/capacity | FILLING` or `FULL | WARP READY`.

### Tuned values
The user's values from `main.tscn`, then the prototype's defaults for the
rest.

| value | setting |
|---|---|
| `cargo_tank_size` | 5 |
| `base_tanks` / `max_tanks` | 1 / 3 |
| `warp_needs_all_tanks` | on |
| `bank_partial_tank` | on |
| `stop_collecting_when_full` | on |
| `warp_spend` | 0 |
| Mass tanks stat | base cost 5, cost growth 2, +1 tank per level |
| `cargo_weight` | 0.5 |
| `cargo_mass_exponent` | 1 |
| `cargo_conserves_momentum` | on |
| `gravity_constant` | 10000 (was 10 in the level) |
| `gravity_falloff_exponent` | 3.5 |
| `gravity_drift` | on |
| `drag` (linear damp) | 0.25 (was 0) |
| `thrust` (back thrust force) | 150 (was 100) |
| fuel `refill_time` | 7.5 (was 5) |
| fuel `tank_size` | 1 |
| `pickup_radius` | 50 |
| pitch, turn, roll torques | 0.05 |
| `starting_mass` | 1 |
| `mass_conversion` | 1 |
| rings `mass_min` | 0.01 (was 0.1) |
| rings `mass_ceiling_fraction` | 0.1 (was 1.0) |
| rings `mass_bias` | 1.5 |
| refill rate upgrade step | 0.1 (was 0.25) |
| other shop steps, costs | unchanged (size 0.5, tank 0.25, others 0.2; 5 × 1.6^level) |
| `start_at_rest` | on |

### Edge cases noticed
- At rest beside a planet, arcade flight turned gravity's sideways pull
  into forward speed. The drift split fixes it.
- The dim slots for unbought tanks looked like tanks you couldn't fill,
  so the gauge shows owned tanks only.
- `gravity_constant` on `player.tscn` had no effect: the level overrides
  it. The rewrite should set it in one place.
- Changing the falloff exponent also changes the overall strength, so the
  constant has to be retuned with it.
- PlayerSpawn's orbit speed uses `gravity_constant` and 1/r², so with the
  new gravity it is wrong. Start at rest replaces it.

### Tried and dropped, or test-only
- Tank gauge with a 10-segment bar per tank: looked like many tanks.
- Showing locked (unbought) tank slots: dropped, off by default.
- Warping after one full tank: replaced by needing every tank full.
- Test-only: `starting_bank`, `override_ring_masses` (the rewrite changes
  the rings tier itself).
- Mass growing the ship (`GrowthComponent` on pickups) is no longer used
  in a run; the starting size upgrade still sets the ship's size.

## Decision
- 2026-11-24: done. The prototype was deleted.
- 2026-11-24: accepted, moving to the rewrite.

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written. The user agreed the split on
2026-11-24 and asked to go ahead, being told of every new or changed
contract.

### CargoComponent (`scripts/components/cargo_component.gd`)
- Exports (Cargo): `tank_size > 0` (5) and `tanks ≥ 1` (1). A bad value
  is reported and ignored.
- Read-only `stored`, starting at 0. `capacity()` is `tanks ×
  tank_size`. `full_tanks()` is the number of tanks completely full
  (`floor(stored / tank_size)`, at most `tanks`). `is_full()` is `stored ≥
  capacity()`. `fill_of(tank)` requires `0 ≤ tank < tanks` and returns
  that tank's fill in [0, 1], tanks filling in order.
- `add(amount) -> float` requires `amount ≥ 0` (a broken pre-condition is
  reported and adds nothing). It adds what fits and returns it: `min(amount,
  capacity() − stored)`. `changed(stored)` is emitted when `stored`
  changes.
- `empty()` sets `stored` to 0.
- Invariant, after every change: `0 ≤ stored ≤ capacity()`.

### PickupComponent (changed, see [player growth](11_player_growth.md))
- New optional export `cargo: CargoComponent` (Components). With it:
  - absorbed mass goes to `cargo.add(mass × mass_conversion)`, and
    `mass_component` is left alone (the ship doesn't grow)
  - `collect()` catches nothing while `cargo.is_full()`. Bodies already
    in flight still arrive, and what doesn't fit is lost.
- Without a cargo it behaves as before (absorbed mass grows the ship).

### PassThroughComponent (`scripts/components/pass_through_component.gd`)
Added at the user's request: "Turn off collision for any mass smaller or
equal to the player when you've filled up the tank (I don't want to be able
to hit a random small planet when you don't expect it)."
- Exports: `body: RigidBody3D`, `mass_component`, `cargo` and `pool:
  LiveBodyPool` (Components), and `reach ≥ 0` (Pass through, 100): how far
  from the ship's centre bodies are made passable.
- Each physics frame, the passable set is `pool.bodies_within(body
  position, reach, current_mass)` while `cargo.is_full()`, else empty.
  Without a cargo or a pool it is always empty.
- Post-condition: the body has a collision exception with exactly the
  passable set's bodies (of those still valid): new ones are added, and
  ones that left the set (out of reach, no longer lighter, or the cargo no
  longer full) are removed. So a full ship passes through lighter or equal
  bodies, and never through heavier ones.
- `passable()` returns the current set.

### CargoWeightComponent (`scripts/components/cargo_weight_component.gd`)
- Exports: `body: RigidBody3D`, `mass_component`, `cargo` and an optional
  `gravity_receiver` (Components); `cargo_weight ≥ 0` (0.5),
  `mass_exponent ≥ 0` (1) and `conserve_momentum` (on) (Cargo weight). A
  bad value is reported and ignored.
- `handling_mass()` is `core × (real ÷ core) ^ mass_exponent`, with `core
  = current_mass` and `real = core + cargo.stored × cargo_weight`. At
  exponent 0, or with an empty cargo, it is `core`.
- `_ready` requires `body`, `mass_component` and `cargo`. A broken
  pre-condition is reported and the component stays inactive. Otherwise it
  sets `body.mass` and follows `cargo.changed` and
  `mass_component.mass_changed`.
- Post-condition after each change: `body.mass == handling_mass()`.
- On a cargo change with `conserve_momentum` on and the body not frozen,
  the velocity (and the receiver's drift) is scaled by old ÷ new handling
  mass, keeping momentum. A core mass change only sets `body.mass` (the
  `MomentumComponent` owns that case).
- Thrust is a force, so it accelerates the ship by thrust ÷
  `handling_mass()`. Gravity, turning, collecting and crashing use the
  core mass.

### GravityReceiverComponent (changed, see [gravity](04_gravity.md))
- New exports (Gravity): `falloff_exponent > 0` (2) and `drift_enabled`
  (off); and an optional `mass_component` (Components).
- The acceleration from each source strictly heavier than the ship's core
  mass (`mass_component.current_mass`, or `body.mass` without one) is `G ×
  M ÷ r ^ falloff_exponent`, with `r` floored at the source's radius. It
  is an acceleration, so it doesn't depend on the ship's mass (cargo weight
  included). The static `acceleration_at(position, sources, positions,
  masses, radii, G, exponent)` gives the total, shared with
  `PathPredictor`.
- With `drift_enabled` off, it is applied as the force `acceleration ×
  body.mass`, as before. With it on, `drift` (Vector3) becomes `(drift +
  a × dt) × max(0, 1 − body.linear_damp × dt)` and the body's velocity
  gains `a × dt`: gravity's share of the velocity, damped like the rest.
- `reset_drift()` sets `drift` to zero. The post-condition that every
  acceleration is finite still holds (a non-finite one is reported and
  not applied).

### ArcadeFlightComponent (changed, see [game loop](12_game_loop.md))
- New optional export `gravity_receiver` (Components). With it (and its
  drift enabled), only `velocity − drift` is aligned to the facing, keeping
  its speed, and the drift is added back. So gravity bends the path, and
  steering doesn't cancel it.
- Without one, it behaves as before.

### PathPredictor (changed, see [HUD and art](13_hud_and_art.md))
- New settings: `falloff_exponent > 0` (2) and `drift_enabled` (off).
  `predict` gains a last optional argument `drift` (Vector3.ZERO).
- The pull is `GravityReceiverComponent.acceleration_at`, so it uses the
  exponent. With `drift_enabled`, it splits the velocity as the ship does:
  the drift gains the pull and is damped, the own velocity is damped and
  aligned to the facing, and the ship moves by their sum.
- With both at their defaults, it predicts as before, except that a step
  whose segment passes through a heavier source now forecasts `IMPACT`
  (ending at the first point of contact). Found in the rewrite: with
  drift on, a 0.25 s step jumped through small heavy bodies.

### Minimap (changed, see [HUD and art](13_hud_and_art.md))
- The predictor takes the player's receiver's `falloff_exponent`,
  `drift_enabled` and `drift`, and the player's core mass (not
  `body.mass`, which includes cargo) for what is heavier.

### Upgrade (changed, see [game loop](12_game_loop.md))
- New export `max_level ≥ −1` (−1, no cap). With a cap, `cost(level)` for
  `level ≥ max_level` is `INF`, so it can never be bought.
  `is_maxed(level)` is true exactly then.
- `ShopOverlay` shows `MAX` instead of the multiplier and cost for a
  maxed stat (its button is already disabled, as it's unaffordable).

### CargoTanksUpgrade (`scripts/progression/upgrades/cargo_tanks_upgrade.gd`)
An `Upgrade`. Resource `cargo_tanks_upgrade.tres`: id `cargo_tanks`,
display name "Mass tanks", step 1, base cost 5, cost growth 2, max level 2
(so 1 to 3 tanks).
- `_apply(player, m)`: `player.cargo.tanks += roundi(m − 1)`, so `step`
  tanks per level. Requires the player to have a cargo: a broken
  pre-condition is reported and changes nothing.

### Player (changed)
- New optional export `cargo: CargoComponent`.

### WarpController (changed, see [game loop](12_game_loop.md))
- `warp_cost` and `warp_spends_cost` are replaced (Warp) by
  `warp_needs_all_tanks` (on), `tanks_to_warp ≥ 0` (1), `bank_partial_tank`
  (on) and `warp_spend ≥ 0` (0). `_ready` requires `player.cargo` as well.
- `collected()` is `cargo.stored`. `can_warp()` is `not warping and not
  lost and cargo.full_tanks() ≥ required`, where `required` is
  `cargo.tanks` with `warp_needs_all_tanks`, else `min(tanks_to_warp,
  cargo.tanks)`.
- `warp_out()`: `banked = max(0, (stored, or full_tanks × tank_size
  without bank_partial_tank) − warp_spend)`. The rest is as before.

### PlayerSpawn (changed, see [procedural generation](10_procedural_generation.md))
- New export `start_at_rest` (off). With it on, the player ends with zero
  linear and angular velocity (and the receiver's drift reset), still
  facing along the ring's prograde tangent: in the ring's plane, at right
  angles to the outward vector.

### CargoGauge (`scripts/ui/cargo_gauge.gd`, `scenes/ui/cargo_gauge.tscn`)
- The thrust reserve's holo style in yellow, under it: a framed panel
  with a title, a bar with one segment per owned tank, and a readout.
- Exports: `cargo` and an optional `warp_controller` and `below: Control`
  (the panel to sit under) (Components); `bar_width_ratio` (0.16),
  `bar_height_px ≥ 10` (14), `margin_ratio` (0.015), `gap_px ≥ 0` (6)
  (Layout); `filling_colour` (0.95, 0.7, 0.15), `full_colour` (1, 0.88,
  0.3) and `ready_flash_hz > 0` (1.5) (Colours).
- `refresh(delta)` requires `cargo`. Afterwards:
  - `fills` has one entry per owned tank, `cargo.fill_of(i)`
  - `warp_ready` is `warp_controller.can_warp()` (false without one)
  - the title is `// MASS TANKS full/owned`, the readout `MASS
    stored/capacity | FILLING`, or `| WARP READY` when ready, or `| FULL |
    WARP READY` when full and ready
  - a full tank is drawn `full_colour` (pulsing towards white at
    `ready_flash_hz` while ready), a filling one `filling_colour`
  - with `below` set, the panel sits `gap_px` under it
- Invariant: `fills.size() == cargo.tanks`, and every fill is in [0, 1].

## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done.

### 5.1 Cargo component ✅
- `CargoComponent` on the player (`Player.cargo`), 5 per tank, 1 tank.
- **Done:** `tests/components/test_cargo_component.gd` passes (fills in
  order, clamps at capacity, rejects negative amounts, invariant holds).

### 5.2 Pickups fill the cargo ✅
- `PickupComponent.cargo`: absorbed mass goes to the cargo, and nothing is
  caught while it's full.
- **Done:** `tests/components/test_pickup_component.gd` passes, with new
  tests for the cargo case; the old growth tests still pass.

### 5.3 Pass through lighter bodies when full ✅
- `PassThroughComponent` on the player, wired to the level's pool.
- **Done:** `tests/components/test_pass_through_component.gd` passes
  (exceptions added when full, removed when not, never for heavier
  bodies).

### 5.4 Cargo weight ✅
- `CargoWeightComponent` on the player (0.5, exponent 1, momentum on).
- **Done:** `tests/components/test_cargo_weight_component.gd` passes
  (handling mass, exponent 0 and 2, momentum kept, thrust slows).

### 5.5 Gravity falloff and drift ✅
- `GravityReceiverComponent`: `falloff_exponent`, `drift_enabled`,
  core-mass filter, `acceleration_at`.
- **Done:** `tests/components/test_gravity_receiver_component.gd` passes,
  with new exponent and drift tests; the old tests still pass.

### 5.6 Arcade flight leaves the drift alone ✅
- `ArcadeFlightComponent.gravity_receiver`.
- **Done:** `tests/components/test_arcade_flight_component.gd` passes,
  with a test that the drift survives alignment.

### 5.7 Path prediction with falloff and drift ✅
- `PathPredictor` exponent and drift; the minimap passes them and the core
  mass.
- **Done:** `tests/ui/test_path_predictor.gd` and `test_minimap.gd` pass,
  with a test that the predicted path curves with drift on.

### 5.8 Mass tanks upgrade ✅
- `Upgrade.max_level`, `CargoTanksUpgrade` and its resource in the run
  starter, `MAX` in the shop.
- **Done:** `tests/progression/test_upgrade.gd`,
  `tests/progression/upgrades/` and `tests/ui/test_shop_overlay.gd` pass.

### 5.9 Warp from full tanks ✅
- `WarpController` on the cargo.
- **Done:** `tests/levels/test_warp_controller.gd` passes, rewritten for
  the cargo rules.

### 5.10 Start at rest ✅
- `PlayerSpawn.start_at_rest`.
- **Done:** `tests/levels/test_player_spawn.gd` passes, with a rest test.

### 5.11 Cargo gauge ✅
- `CargoGauge` and its scene in the level, under the fuel gauge.
- **Done:** `tests/ui/test_cargo_gauge.gd` passes.

### 5.12 Tuning and level wiring ✅
- The user's tuned values: player (thrust 150, drag 0.25 with drift on,
  refill 7.5, gravity 10000 with exponent 3.5, set on the player only, the
  level's override removed), rings tier (`mass_min` 0.01,
  `mass_ceiling_fraction` 0.1), refill upgrade step 0.1, and the level
  wiring (pass-through pool, cargo gauge, spawn at rest).
- **Done:** `tests/levels/test_generated_level.gd` passes, updated for the
  new loop, and smoke passes.

## Performance evaluation
The load measured, the budget, and each option weighed:

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |

- 2026-11-24: skipped at the user's request ("There isn't a performance hit
  really so lets bypass it for now and move on"). Nothing was measured.
  Candidates if it shows up later: `PassThroughComponent` checks set
  membership with `Array.has` (O(n²) in the bodies in reach), and the
  path predictor now tests each step's segment against every heavier
  source.
