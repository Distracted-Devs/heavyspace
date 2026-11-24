# game_loop
Started 2026-11-23. The live phase is in `.claude/bin/feature status`.

## Idea
In the user's words: "Let's start phase 3." From the roadmap (Phase 3: Game
Loop):
- "Ensure the player can collect mass, once enough has been collected then
  they can warp out"
- "Can spend that mass in the shop to upgrade for the next run."

From the game design: "The player collects as much as it can and if they
have enough can spend that mass to warp out. Once the player has warped out
there is a shop phase where they can upgrade various stats." Shop stats:
starting size, booster fuel tank size, booster fuel refill rate, booster
strength and pickup radius.

Agreed: one prototype covers the whole loop (collect, warp out, shop, next
run).

## Prototype log
One line per iteration: what changed and what the user said about it.
- v1: warp-out readout, warp out once `warp_cost` (10) mass is collected
  (the cost is spent, the rest banked), a warp stretch, zoom and fade, and a
  shop for the five stats (+% per level, cost 5 × 1.6^level). The bank and
  levels last across reloads. User: "This plays fairly well." They asked to
  test it without physical flight: go where the ship points, without having
  to manage thrust.
- v2: test-only arcade flight (velocity follows the facing, keeping its
  speed; boost only adds speed). User: "This is much better". Agreed: this
  phase changes the flight to this, and adds turn speed (pitch, yaw and
  roll) as a shop stat. Mass shouldn't affect turning, but momentum should
  be conserved, so the player slows down as it gains mass and its boost
  gets weaker.
- v3: momentum conserved on gaining mass (velocity × old / new mass), and
  turn speed added as a shop stat (+20% to all three torques per level).
  The user asked for every orbit period to be 0 for testing.
- v4: test-only frozen orbits (level clock held at 0) and start at rest.
  User: "great to get started with tuning parameters". The A button didn't
  work in the shop: Godot's default `ui_accept` has no controller button.
  Fixed by adding A to `ui_accept` at runtime. The user asked to implement
  it.

## Accepted behaviour
The spec for the rewrite, from `prototypes/game_loop/main.gd`. The user
accepted it to start tuning, so the values below are starting points, not
final.

### Keep
- **Run mass:** a run starts at `starting_mass × starting size multiplier`.
  The mass collected this run is `current_mass − run start mass`.
- **Warp out:** once collected ≥ `warp_cost`, pressing `warp_out` (Space /
  A) warps out. Warping spends `warp_cost` and banks the rest of the
  collected mass (`warp_spends_cost`). It can't happen after losing, while
  already warping, or in the shop. A crash during a warp doesn't lose.
- **Warp sequence:** `stop_flight()`, then over `warp_duration` the camera
  FOV widens to `warp_fov`, the ship mesh stretches ×6 along its length and
  shoots `warp_distance` forward (expo ease-in), and the screen fades to
  white over the second half. Then the shop opens.
- **Crash:** it loses only this run's collected mass. The bank and upgrade
  levels stay, and restart (R / Back) starts a new run as before.
- **Shop:** it pauses the level, shows the cursor and blocks the level's
  pause and restart. It shows the bank and one button per stat: name,
  level, current → next multiplier and cost. A button is disabled when you
  can't afford it. Buying spends the cost and adds a level. Focus starts on
  **Launch next run**, and moves back there when the focused stat becomes
  unaffordable. Launch reloads the level with the upgrades applied.
- **Controller in menus:** `ui_accept` must include the A button (Godot's
  default doesn't), with the d-pad and left stick moving focus.
- **Upgrades:** multiplier = `1 + step × level`, and the cost of the next
  level = `round(base_cost × cost_growth ^ level)`. Applied at the start of
  each run:
  | stat | applies to |
  |---|---|
  | starting size | run start mass (growth makes the ship look bigger) |
  | fuel tank size | `FuelComponent.tank_size` × |
  | fuel refill rate | `FuelComponent.refill_time` ÷ |
  | booster strength | `ThrusterComponent.back_thrust_force` × |
  | pickup radius | `PickupComponent.pickup_radius` × |
  | turn speed | pitch, yaw and roll torques × (new stat, agreed) |
- **Persistence:** the bank, the levels and the run count last across level
  reloads for the session. Nothing is saved to disk.
- **Readout:** a temporary top-right label for the run, bank, collected /
  `warp_cost`, and READY / Warping / Run lost. The real HUD is Phase 4.
  Dropped in the rewrite (2026-11-23): the user doesn't want it.

### Flight changes (agreed for this phase)
- **Arcade flight replaces Newtonian steering:** each physics frame the
  velocity turns to the ship's facing while keeping its speed
  (`velocity.lerp(forward × speed, alignment)`, renormalised to the speed).
  Thrust only changes speed. Gravity still acts between frames.
- **Momentum is conserved on gaining mass:** velocity × old mass / new
  mass. Boost is a fixed force (`apply_central_force`), so it weakens with
  mass. Turning doesn't depend on mass (fixed inertia, torques don't scale).

### Tuned values
| value | setting |
|---|---|
| `warp_cost` | 10.0 (collected mass) |
| `warp_spends_cost` | on |
| `warp_duration` | 1.5 s |
| `warp_fov` | 130 |
| `warp_distance` | 400 |
| `base_cost` | 5 |
| `cost_growth` | 1.6 |
| starting size step | +0.5 per level |
| tank size, refill rate steps | +0.25 per level |
| booster strength, pickup radius, turn speed steps | +0.2 per level |
| `arcade_alignment` | 1.0 (instant) |
| `conserve_momentum` | on |

### Edge cases noticed
- The starting size is applied after the streamer's first expansion, so the
  first rings use the base mass for their ceiling. They stay suckable, just
  lighter.
- With orbits running, you spawn at orbit speed and arcade flight carries
  you forward at once. There's no brake.
- `free_warp` with nothing collected banks 0, not a negative amount.

### Tried and dropped, or test-only
- Test-only: `freeze_orbits` (clock held at 0), `start_at_rest`,
  `free_warp`, `starting_bank`.
- Newtonian steering (velocity independent of facing): replaced by arcade
  flight.

## Decision
- 2026-11-23: done. The prototype was deleted.
- 2026-11-23: accepted, moving to the rewrite.

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written.

### ArcadeFlightComponent (`scripts/components/arcade_flight_component.gd`)
- Exports: `body: RigidBody3D` (Components), and `alignment` in [0, 1]
  (Arcade flight, default 1.0): the fraction the velocity swings towards
  the facing each physics frame (1 instant, 0 Newtonian). Per physics
  frame, not per second (agreed). A value outside [0, 1] is reported and
  ignored.
- `align()` runs each physics frame, after `RotationComponent`
  (`process_physics_priority = 1`). It requires `body` to be set. A broken
  pre-condition is reported and changes nothing.
- With forward = `-body.global_basis.z` and speed = `|v|`, the new velocity
  is `v.lerp(forward × speed, alignment)` renormalised to `speed`. If that
  lerp is (almost) zero (flying straight backwards), it is `forward ×
  speed`.
- Post-conditions:
  - the speed is kept: only thrust and gravity change it
  - `alignment = 1` leaves the velocity along forward, and `alignment = 0`
    leaves it unchanged
  - a body at rest stays at rest
- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): with a `gravity_receiver` whose drift
  is enabled, only `velocity − drift` is aligned and the drift is kept.
- `Player.arcade_flight` (optional) is disabled by `Player.stop_flight()`
  (see [lose flow](09_lose_flow.md)).

### MomentumComponent (`scripts/components/momentum_component.gd`)
- Exports: `body: RigidBody3D` and `mass_component: MassComponent`
  (Components), and `conserve_momentum` (default on) and
  `momentum_exponent ≥ 0` (default 1, added after play-testing) (Momentum).
  A negative exponent is reported and ignored.
- `_ready` requires `body` and `mass_component`. A broken pre-condition is
  reported and the component stays inactive. Otherwise it records the
  current mass and listens to `mass_changed`.
- On `mass_changed(new_mass)`, which requires `new_mass > 0` (as
  `MassComponent` guarantees), the velocity becomes `v × (old_mass /
  new_mass) ^ momentum_exponent`. It works both ways (agreed): losing mass
  speeds the ship up. Post-condition: the direction is unchanged, and the
  speed is scaled by exactly that factor. At exponent 1 momentum is
  conserved (`new_mass × v_after ≈ old_mass × v_before`), and at 0 the
  velocity is unchanged.
- With `conserve_momentum` off, or while `body.freeze` is set (after
  `stop_flight()`, while pickups already in flight still arrive), the
  velocity is left alone. The new mass is always recorded as the old mass
  for the next change.

### Upgrade (`scripts/progression/upgrade.gd`)
- A Resource. Exports: `id: StringName` (non-empty, the key progression
  stores levels under), `display_name: String`, `step ≥ 0`, `base_cost > 0`
  and `cost_growth ≥ 1`.
- `multiplier(level)` requires `level ≥ 0` and returns `1 + step × level`:
  at least 1, never decreasing with level. A broken pre-condition is
  reported and returns 1.
- `cost(level)` requires `level ≥ 0` and returns `round(base_cost ×
  cost_growth ^ level)`, never decreasing with level. A broken
  pre-condition (or a bad export) is reported and returns `INF`, so it is
  never affordable.
- `apply(player, level)` requires a player, valid exports and `level ≥ 0`,
  then calls the subclass's `_apply(player, multiplier(level))`. It
  multiplies the scene's base value, so it is applied once to a fresh
  player before its `_ready` (the run starter's job). A broken
  pre-condition is reported and changes nothing.
- Each subclass in `scripts/progression/upgrades/` changes only its own
  stat by `m = multiplier(level)`, leaves every other stat alone, and at
  level 0 changes nothing. Its resource in `resources/progression/upgrades/`
  has `base_cost` 5 and `cost_growth` 1.6.

- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): `max_level` (−1, no cap) makes
  `cost` INF at the cap; `is_maxed(level)`.

### StartingSizeUpgrade (`scripts/progression/upgrades/starting_size_upgrade.gd`)
An `Upgrade` (see above). Resource `starting_size_upgrade.tres`: id
`starting_size`, step 0.5.
- `_apply(player, m)`: `mass_component.start_multiplier × m`, so the run
  starts bigger and looks bigger.

### FuelTankUpgrade (`scripts/progression/upgrades/fuel_tank_upgrade.gd`)
An `Upgrade` (see above). Resource `fuel_tank_upgrade.tres`: id `tank_size`,
step 0.25.
- `_apply(player, m)`: `fuel_component.tank_size × m`.

### RefillRateUpgrade (`scripts/progression/upgrades/refill_rate_upgrade.gd`)
An `Upgrade` (see above). Resource `refill_rate_upgrade.tres`: id
`refill_rate`, step 0.25.
- `_apply(player, m)`: `fuel_component.refill_time ÷ m`, so the tank refills
  `m` times as fast.

### BoosterUpgrade (`scripts/progression/upgrades/booster_upgrade.gd`)
An `Upgrade` (see above). Resource `booster_upgrade.tres`: id
`booster_strength`, step 0.2.
- `_apply(player, m)`: `thruster.back_thrust_force × m`.

### PickupRadiusUpgrade (`scripts/progression/upgrades/pickup_radius_upgrade.gd`)
An `Upgrade` (see above). Resource `pickup_radius_upgrade.tres`: id
`pickup_radius`, step 0.2.
- `_apply(player, m)`: `pickup_component.pickup_radius × m`. Requires the
  player to have a pickup component: a broken pre-condition is reported and
  changes nothing.

### TurnSpeedUpgrade (`scripts/progression/upgrades/turn_speed_upgrade.gd`)
An `Upgrade` (see above). Resource `turn_speed_upgrade.tres`: id
`turn_speed`, step 0.2.
- `_apply(player, m)`: `rotator.pitch_torque`, `turn_torque` and
  `roll_torque` each × m.

### Progression (`scripts/progression/progression.gd`)
- A `RefCounted`, so tests make a fresh one. Read-only state: `bank`
  (banked mass), `runs` (runs started) and `level_of(upgrade)` (keyed by
  `upgrade.id`, 0 if never bought; requires an upgrade).
- `changed` is emitted after any change to the bank, a level or `runs`.
- `bank_mass(amount)` requires `amount ≥ 0` (the warp controller clamps),
  and raises the bank by `amount`. A broken pre-condition is reported and
  changes nothing.
- `can_afford(upgrade)` is `upgrade.cost(level_of(upgrade)) ≤ bank`. A
  broken upgrade costs `INF`, so it is never affordable.
- `buy(upgrade) -> bool`: if it can't be afforded, returns false and
  changes nothing (not an error). Otherwise the bank drops by exactly the
  cost at the old level, the level goes up by 1, `changed` is emitted and
  it returns true.
- `start_run()` adds 1 to `runs`.
- Invariant, after every change: `bank ≥ 0` and every level `≥ 0`.

### RunProgress (`scripts/progression/run_progress.gd`)
- An autoload Node holding one `progression := Progression.new()` for the
  session. It survives level reloads. Nothing is saved to disk.
- Users (run starter, warp controller, shop) have a
  `progression: Progression`. If it is null when they enter the tree, they
  take `RunProgress.progression`. Tests set their own.

### RunStarter (`scripts/levels/run_starter.gd`)
- Exports: `player: Player` (Components) and `upgrades: Array[Upgrade]`
  (Upgrades: the six resources; the shop reads the same list from here).
  `progression: Progression` defaults to `RunProgress.progression` when it
  is null on entering the tree.
- `_enter_tree` starts the run. It requires `player` to be set and not yet
  ready, and every upgrade to be set with a unique id. A broken
  pre-condition is reported and nothing is applied.
- Post-conditions: every upgrade has been applied exactly once at
  `progression.level_of(upgrade)`, `progression.start_run()` has been
  called once, and `started` is true. Entering the tree again does
  nothing.
- So the player's `MassComponent._ready` starts the run at the upgraded
  mass, and (the player being before the streamer) the streamer's first
  expansion sees it.

### WarpController (`scripts/levels/warp_controller.gd`)
- Exports: `player: Player` and `lose_controller: LoseController`
  (Components), and `warp_cost ≥ 0` (default 10) and `warp_spends_cost`
  (default on) (Warp). `progression` defaults to `RunProgress.progression`
  on entering the tree. The optional `warp_effect` arrives in 3.7: without
  one, `warp_finished` is emitted at once.
- `_ready` records `run_start_mass` from `player.mass_component`
  (already upgraded). `collected()` is `current_mass − run_start_mass`.
- `can_warp()` is `not warping and not lose_controller.lost and
  collected() ≥ warp_cost`.
- `warp_out() -> bool`: if it can't warp, returns false and changes nothing
  (not an error). Otherwise `banked = max(0, collected − warp_cost)` (or
  `max(0, collected)` with `warp_spends_cost` off) is banked exactly once,
  `warping` becomes true, the lose controller is disarmed,
  `player.stop_flight()` is called, `warp_started(banked)` is emitted, then
  `warp_finished` once when the effect ends, and it returns true.
- Post-conditions: the bank rose by exactly `banked` and `warping` is true.
  A second call returns false.
- Pressing `warp_out` calls `warp_out()`, and marks the event handled when
  a warp starts. While the tree is paused (the shop) it gets no input.
- `LoseController.disarm()` (see [lose flow](09_lose_flow.md)).

- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): `warp_cost`, `warp_spends_cost` and
  `run_start_mass` are gone. Warping needs full cargo tanks and banks the
  cargo (`warp_needs_all_tanks`, `tanks_to_warp`, `bank_partial_tank`,
  `warp_spend`).

### WarpEffect (`scripts/effects/warp_effect.gd`)
AI generated placeholder: it MUST be reworked in Phase 5 (see the
[roadmap](../roadmap.md)).
- Exports: `camera: Camera3D` and `mesh: Node3D` (required) and `fade:
  ColorRect` (optional) (Components); `warp_duration > 0` (1.5 s),
  `warp_fov` in (0, 180) (130), `warp_distance ≥ 0` (400), `stretch ≥ 1`
  (6), `stretch_fraction` in (0, 1] (0.6) and `fade_start` in [0, 1) (0.5)
  (Warp). A bad value is reported and ignored.
- `play()` requires not `playing` and `camera` and `mesh` set. A broken
  pre-condition is reported and nothing plays. It records the camera FOV
  and the mesh scale and position, and `playing` becomes true.
- `advance(delta)` (from `_process`, driven by hand in tests), with `t =
  elapsed / warp_duration`:
  - FOV goes from its start to `warp_fov`, reached at `stretch_fraction`
  - mesh `scale.z` goes from its base to `base × stretch` over the same
    time
  - mesh `position.z` goes from its base to `base − warp_distance` with an
    expo ease-in over the whole duration (local −z is forward)
  - fade alpha goes from 0 to 1 between `fade_start` and the end
  - every value is monotonic in `t`
- Post-condition at `t ≥ 1`: every value is at its end value, `playing` is
  false and `finished` has been emitted exactly once. Advancing afterwards
  changes nothing.
- `WarpController.warp_effect` (optional): `warp_out()` plays it, and
  `warp_finished` is emitted on its `finished`. Without one it is emitted
  at once.
- Pickups still in flight arrive after banking, so they don't count, and
  the effect's per-frame scale overrides `GrowthComponent`.

### Menu input (`project.godot`)
- `ui_accept` is exactly Enter and joypad A (any device), agreed. Space
  and Kp Enter are removed, so Space only warps out.
- `ui_up`, `ui_down`, `ui_left` and `ui_right` keep Godot's defaults,
  which include the d-pad and the left stick. The test asserts those
  events too.
- Checked by `tests/test_project_input.gd`.

### ShopOverlay (`scripts/ui/shop_overlay.gd`, `scenes/ui/shop_overlay.tscn`)
- A CanvasLayer with `process_mode = ALWAYS`. Exports: `warp_controller`
  and `run_starter` (Components; the upgrades are `run_starter.upgrades`)
  and `reload_on_launch` (Shop, default on; tests turn it off).
  `progression` defaults to the autoload. No pause controller (agreed).
- The layout is in the scene. The code fills the upgrades box with one
  button per upgrade, in order, and starts hidden.
- `open()`, on `warp_finished`, requires the shop to be closed. Afterwards
  it is visible, the tree is paused, the mouse is visible and Launch has
  focus.
- While open, `pause` and `restart` are marked handled in `_input`, so
  nothing behind the shop reacts to them.
- Each upgrade button's text contains the display name, level, current and
  next multiplier and cost, and the bank label contains the bank. Tests
  check the values appear, not the wording (agreed).
- A button is disabled exactly when `not progression.can_afford(upgrade)`.
  Pressing it calls `progression.buy(upgrade)`. On `progression.changed`
  the buttons and bank label refresh, and if the focused button became
  disabled, focus moves to Launch.
- Invariant while open: one button per upgrade, each disabled exactly when
  it can't be afforded. Text isn't part of it.
- `launch()` requires the shop to be open. It unpauses, emits `launched`
  and, with `reload_on_launch`, reloads the current scene.
- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): a maxed
  upgrade's button reads `name   Lv n (xm)   MAX`.

### MassComponent start multiplier (`scripts/components/mass_component.gd`)
Extends the `MassComponent` contract in [flight](03_flight.md).
- Export `start_multiplier` (Mass, default 1) must be positive. A
  non-positive value is reported and ignored.
- `_ready` sets `current_mass = starting_mass × start_multiplier`.
  `starting_mass` stays the base that `GrowthComponent` scales from, so a
  bigger start looks bigger.

## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done.

### 3.1 Arcade flight ✅
- `scripts/components/arcade_flight_component.gd` on the player. Each
  physics frame the velocity turns to the ship's facing, keeping its speed
  (`alignment`, default 1.0). Thrust only changes speed.
- `Player.stop_flight()` disables it with the other flight components.
- **Done:** `tests/components/test_arcade_flight_component.gd` passes
  (speed kept, velocity follows the facing, partial alignment, at rest
  stays at rest), and smoke passes.

### 3.2 Momentum on growth ✅
- `scripts/components/momentum_component.gd` on the player. On
  `mass_changed` it scales the velocity by old mass / new mass
  (`conserve_momentum`, default on).
- **Done:** `tests/components/test_momentum_component.gd` passes (momentum
  is conserved when mass grows, off leaves the velocity alone), and smoke
  passes.

### 3.3 Upgrades ✅
- `scripts/progression/upgrade.gd`: a Resource with `display_name`,
  `step`, `base_cost` and `cost_growth`. `multiplier(level) = 1 + step ×
  level`, `cost(level) = round(base_cost × cost_growth ^ level)` and
  `apply(player, level)`.
- One small subclass per stat (starting size, fuel tank size, fuel refill
  rate, booster strength, pickup radius, turn speed), and a `.tres` for
  each in `resources/progression/upgrades/` with the tuned values.
- `MassComponent.start_multiplier` (default 1, moved here from 3.5): a run
  starts at `starting_mass × start_multiplier`, and growth still scales
  from `starting_mass`.
- **Done:** `tests/progression/test_upgrade.gd` passes (multiplier and cost
  formulas, each upgrade changes only its own stat by its multiplier), and
  smoke passes.

### 3.4 Progression ✅
- `scripts/progression/progression.gd`: the bank, the level of each
  upgrade and the run count. `can_afford`, `buy`, `bank_mass` and
  `start_run`.
- An autoload, `RunProgress`, keeps it for the session across level
  reloads. Nothing is saved to disk.
- **Done:** `tests/progression/test_progression.gd` passes (buying spends
  the cost and adds a level, unaffordable buys are refused, the bank never
  goes negative, runs count up), and smoke passes.

### 3.5 Run start ✅
- `scripts/levels/run_starter.gd` applies every upgrade at its level to the
  player before the level's nodes are ready, and starts the run. The
  streamer's first expansion sees the upgraded starting mass.
- **Done:** `tests/levels/test_run_starter.gd` passes (upgrades are applied
  once at their levels, the run starts at the upgraded mass, the run count
  goes up), and smoke passes.

### 3.6 Warp controller ✅
- `scripts/levels/warp_controller.gd`: `collected()` and `can_warp()`
  against `warp_cost`. `warp_out` banks `collected − warp_cost` (or all of
  it with `warp_spends_cost` off, never below 0), stops flight and emits
  `warp_started`, then `warp_finished` when the warp effect ends.
- No warp after losing or while already warping. `LoseController` ignores
  crashes once a warp has started.
- **Done:** `tests/levels/test_warp_controller.gd` passes (can't warp below
  the cost, banks the right amount once, no warp after losing, no loss
  while warping), and smoke passes.

### 3.7 Warp effect ✅
- `scripts/effects/warp_effect.gd`: over `warp_duration` the FOV widens to
  `warp_fov`, the mesh stretches and shoots `warp_distance` forward (expo
  ease-in), and the screen fades to white over the second half. Emits
  `finished`.
- **Done:** `tests/effects/test_warp_effect.gd` passes (reaches its end
  values at `warp_duration`, emits `finished` once), and smoke passes.

### 3.8 Menu input ✅
- `ui_accept` is only Enter and the controller A button in
  `project.godot`. The d-pad and left stick move focus.
- **Done:** a test checks the input map, and smoke passes.

### 3.9 Shop overlay ✅
- `scripts/ui/shop_overlay.gd` and `scenes/ui/shop_overlay.tscn`. On
  `warp_finished` it pauses the level, shows the cursor and blocks the
  pause controller. One button per upgrade (name, level, current → next
  multiplier, cost), disabled when unaffordable. Focus starts on **Launch
  next run** and returns there when the focused upgrade becomes
  unaffordable. Launch reloads the level.
- **Done:** `tests/ui/test_shop_overlay.gd` passes (buttons match the
  progression, buying refreshes them, focus rules, pause blocked), and
  smoke passes.

### 3.10 Wire up the game loop ✅
- `generated_level.tscn` holds the run starter, warp controller, warp
  effect (with its fade) and shop overlay, with the tuned values.
- **Done:** `tests/levels/test_generated_level.gd` passes with the loop in
  place, smoke passes, and the user has played collect → warp → shop → next
  run.

## Performance evaluation
The load measured, the budget, and each option weighed.

### Benchmark
`benchmarks/game_loop/bench.gd` (`godot --headless --fixed-fps 60 -s
benchmarks/game_loop/bench.gd -- contracts=0`). Agreed load: the generated
level (seed 12345) with the user's tuning (system `inner_period` 10000,
`momentum_exponent` 0.5), a fresh progression and a 60-frame warm-up, then:
- fly, 600 frames: real flight from the home ring's mid-radius (arcade
  flight and physics on, boost held, turning on a fixed pattern),
  collisions off so it can't crash. It eats 53 pickups
- warp, 91 frames: `warp_out()` and the whole warp effect
- shop, 51 frames: the shop opens with a bank of 1000, then 50 buys, one a
  frame, rotating through the six upgrades
- then 20 `RunStarter.start_run()` calls on fresh players

It times `ArcadeFlightComponent.align`, the `MomentumComponent` handler,
`WarpEffect.advance`, `ShopOverlay.open`, each buy (including the
refresh), `RunStarter.start_run`, the whole frame and the physics step.
Agreed budget: per frame, this feature's code under 0.1ms mean and 0.5ms
worst. Each one-off action under 2ms worst. The whole headless frame under
16.6ms in every phase.

### Baseline (contracts off, ms, worst of 3 runs)
Contracts on add nothing measurable (within 0.05ms on every figure, and
the frame within run-to-run noise).

| measured | mean | p95 | worst |
|---|---|---|---|
| `align` (per physics frame) | 0.003 | 0.005 | 0.010 |
| momentum (per mass change, 56) | 0.003 | 0.004 | 0.005 |
| `WarpEffect.advance` | 0.009 | 0.007 | 0.369 |
| `ShopOverlay.open` | 0.262 | | 0.262 |
| buy + refresh | 0.068 | 0.096 | 0.151 |
| `RunStarter.start_run` | 0.093 | 0.159 | 0.159 |
| frame, flying | 2.27 | 3.44 | 6.02 |
| physics, flying | 1.76 | 2.80 | 4.23 |
| frame, warping | 1.93 | 2.83 | 3.93 |
| frame, shop | 1.39 | 1.53 | **15.37** |

- The feature's own code is far within budget. Every per-frame cost is a
  few microseconds, and every one-off action is under 0.3ms.
- The warp effect's worst (0.37ms) is its last frame, which emits
  `finished` and opens the shop.
- The one hot spot is the first frame after the shop opens: 15.0–15.4ms,
  every run. `open()` itself is 0.26ms. Experiments (each a change to
  `open()` in the benchmark) showed the cost is the engine's first layout
  and draw of the shop's text (new font sizes 26, 28, 32 and 56): pausing
  alone 0.09ms, showing the empty shop 2.2ms, showing it with its text
  16.3ms. Later refreshes are cheap (shop frames 1.4ms). Laying the text
  out while hidden doesn't help. Showing the shop with its text for one
  frame during warm-up moves the 15ms there and the shop then opens in
  0.7ms.

### Hot spots and options

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |
| A. Leave it: the hitch is one frame under a fully white fade, so it can't be seen, and it is within 16.6ms headless | 15.4 | 15.4 | none | taken (2026-11-23): left as it is |
| B. Pre-warm: show the shop, with its text and invisible, for one frame at level start (the warp-in, where loading already hitches) | 15.4 (shop open) | 0.7 (shop open), about 15 moved to level start | an extra start-up step in `ShopOverlay`, and its contract ("starts hidden") changes. The text is laid out twice | declined |
| C. Fewer font sizes (one size for the shop) | 15.4 | not measured | the shop looks flatter, and the Phase 4 HUD will add sizes anyway | declined |

### Decision
The game loop is within budget, with no optimisation taken. The one-frame
text hitch when the shop opens is left, since it sits under the white
fade. Revisit it with the Phase 4 HUD and art (real fonts).
