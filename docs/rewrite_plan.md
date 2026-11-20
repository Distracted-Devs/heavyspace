# Phase 0
- Strip the project back to only the player movement by removing mass collectables and have a test planet in a test level with the player
- Fix any issues in the code.
- Ensure current code matches design paradigms.

Each step below is a single unit of work: break it down, enact it, check its
"Done" contract, commit, then move on. Steps are ordered so that each one
leaves the project opening and running.

## 0.1 Test harness ✅
Do this first so every later step has a pass/fail contract.
- Added GUT 9.7.1 under `addons/gut/` (the 9.7 line is made for Godot 4.7),
  enabled the plugin, and added `.gutconfig.json` pointing at `tests/`.
- Added `scripts/core/contract.gd` (`require` / `ensure` / `invariant`). A
  broken contract calls `push_error` once, and GUT 9.7 fails any test with an
  unexpected `push_error`. No separate violation log or base test class is
  needed.
- Added project settings `heavy_space/contracts/enabled` and
  `heavy_space/contracts/break_on_violation`.
- Wrote down the headless commands in `docs/developer_instructions.md`.
- **Done:** `tests/core/test_contract.gd` passes headless (5/5), a test that
  breaks a contract without expecting it fails with exit code 1, and the
  smoke command prints no errors.

## Contracts
Agree each API's contracts here, with the user, before building it.

### Contract (`scripts/core/contract.gd`)
- A broken check reports exactly one `push_error` (naming its kind and
  message) and returns `false`.
- A passing check has no side effects and returns `true`.
- With checks disabled, nothing is reported and every check returns `true`.

### Planet (`scripts/bodies/planet.gd`)
- Setting `radius` requires `radius > 0`. A non-positive radius is reported
  and ignored, so the planet keeps its old size.
- The planet owns its collider's `SphereShape3D` (made in `_ready`), so no
  two planets share a shape.
- After the radius is applied, the collider still uses the planet's own
  shape, and the mesh radius, the shape radius and `GravityComponent.radius`
  all equal `radius`.

### MassComponent (`scripts/components/mass_component.gd`)
- Setting `current_mass` requires `current_mass > 0`. A non-positive mass is
  reported and ignored, so the player keeps its old mass.
- After `current_mass` is set (and from `_ready`, where it starts at
  `starting_mass`), `body.mass` equals `current_mass`.
- Each accepted set emits `mass_changed` once. A rejected set doesn't emit it.

### InputComponent (`scripts/components/input_component.gd`)
- After each physics frame, every axis of `thrust_intent` and
  `rotation_intent` is within [-1, 1]. The base class checks this after
  calling `_update_intent`, so every implementation (e.g.
  `PlayerInputComponent`) is held to it.

### ThrusterComponent (`scripts/components/thruster_component.gd`)
- Applying thrust requires every axis of the thrust intent to be within
  [-1, 1], and `back_thrust_force` to be ≥ 0. If either is broken, it's
  reported, no force is applied and no fuel is drawn.
- `fuel` (a `FuelComponent`) is optional. Without it, thrust is unlimited.
- Each physics frame a thrust intent `z` asks for `burn_rate · |z| · delta`
  fuel. With no thrust it asks for nothing, so the tank can refill.
- The force is scaled by drawn / asked for, so a full tank gives full force,
  an empty tank gives none, and the last frame before empty gives the part
  it could pay for.

### RotationComponent (`scripts/components/rotation_component.gd`)
- Applying rotation requires every axis of the rotation intent to be within
  [-1, 1], and `pitch_torque`, `turn_torque` and `roll_torque` to be ≥ 0.
  If either is broken, it's reported and no torque is applied.
- Pitch (intent x) is torque about the ship's local X axis, so a positive
  intent lifts the nose.

### PlayerInputComponent (`scripts/components/player_input_component.gd`)
- Held to the `InputComponent` contract. It adds no checks of its own.
- `rotation_intent.x` is `Input.get_axis("pitch_down", "pitch_up")`, so
  W / stick forward pitches down. `invert_pitch` flips the sign.
- Analogue input passes through as it is (a half-pulled trigger gives half
  thrust). Each action has its dead zone (0.2) in the input map, not in
  code.

### FuelComponent (`scripts/components/fuel_component.gd`)
- `tank_size` (default 1.0), `burn_rate` (1.0 per second at full boost,
  so 1s of boost) and `refill_time` (5.0s from empty to full) must be > 0.
  `refill_delay` (default 0.0) must be ≥ 0. A value that breaks this is
  reported and ignored, so the old value stays.
- `draw(amount)` requires `amount ≥ 0`. It removes `min(amount, fuel)` and
  returns how much it removed, so an empty tank returns 0. A broken call is
  reported, removes nothing and returns 0.
- Any `draw` with `amount > 0` counts as boosting, even on an empty tank.
  The tank only refills on physics frames with no boosting, once
  `refill_delay` seconds have passed since the last boost. It refills at
  `tank_size / refill_time` per second. The component runs after the
  thruster (`process_physics_priority = 1`).
- Invariant: `0 ≤ fuel ≤ tank_size` after every draw, refill and tank
  resize. A shrinking tank clamps the fuel.
- The tank starts full. `fuel_changed(fuel)` is emitted once for each actual
  change (not while the tank is full and idle).

### GravityComponent (`scripts/components/gravity_component.gd`)
- Setting `mass` requires `mass > 0`, and setting `radius` requires
  `radius > 0`. A non-positive value is reported and ignored, so the old
  value stays.
- The parent must be a `Node3D` (checked in `_ready`). If it isn't, that's
  reported and the source doesn't register with any receiver.

### GravityReceiverComponent (`scripts/components/gravity_receiver_component.gd`)
- Applying gravity requires `gravity_constant >= 0`. If that's broken, it's
  reported and no force is applied.
- Only a source strictly heavier than `body.mass` pulls. A source of equal
  or smaller mass gives no force (as the design doc says).
- A freed source is dropped from the source list and gives no force.
- The force is `F = G·m·M / r²` through `apply_central_force`, so the
  acceleration doesn't depend on the receiver's mass. `r` is clamped to at
  least the source's radius, and at distance 0 the direction is zero, so no
  force is applied.
- Post-condition: every applied force is finite. A non-finite force is
  reported and not applied.

### GravityRegistry (`scripts/core/gravity_registry.gd`, autoload)
- `register(source)` requires a non-null source that isn't already
  registered. A null or duplicate source is reported and ignored.
- `unregister(source)` and `update(source)` require the source to be
  registered. A stray call is reported and ignored. A `GravityComponent` that
  never registered (non-`Node3D` parent) doesn't unregister.
- Invariant: after every register and unregister, `positions`, `masses` and
  `radii` (parallel packed arrays) all have length `count()`.
- `sources_heavier_than(mass)` returns the indices of every source with a
  mass strictly greater than `mass`, and no others. The indices are only
  valid until the next register or unregister.
- `register` also requires the source's parent to be a `Node3D` in the
  tree. If it isn't, that's reported and ignored.
- A source's mass and radius setters push changes to the registry. Once per
  physics frame, before the receivers run (`process_physics_priority = -2`),
  the registry refreshes positions from each source parent's
  `global_position`.

## 0.2 Housekeeping ✅
- `docs/developer_instructions.md`: the British English example is backwards
  (it should read "initialise over initialize"), and fix the typos
  ("effiecient", "changed be humans").
- `project.godot`:
  - Remove the empty `turn_right` input event (`null`).
  - Remove the unused `collector` global group.
- `player.gd`:
  - Remove `print(self.current_mass)` from `_process`.
  - Remove the `stop_motion` action. It breaks the physics pillar. If it's
    wanted for debugging, gate it behind `OS.is_debug_build()` and an
    `@export var debug_controls_enabled := false`.
  - Rename `_delta` to `delta`. The underscore means "unused", but it is used.
  - Fix the comment "dependant" → "dependent".
- **Done:** smoke passes, and grepping for `print(`, `stop_motion` and `collector`
  finds nothing in `scripts/` or `project.godot`.

## 0.3 Strip back to the player ✅
- Delete:
  - `scenes/collectables/mass_collectable.tscn`
  - `scripts/bodies/mass_collectable.gd` (+ `.uid`)
  - `scripts/managers/procedural_generation.gd` (+ `.uid`)
- Remove the `ProceduralGeneration` node and its ext_resources from
  `scenes/levels/test_level.tscn`.
- Keep `scripts/components/component_gravity.gd` (now `gravity_component.gd`), since the planet needs it.
- Leave textures alone for now. Clear unused assets out in Phase 4 with the
  art pass.
- **Done:** smoke passes, `test_level.tscn` holds only the Player (plus the
  environment), and no file references the deleted paths
  (`grep -r mass_collectable\|procedural_generation`).

## 0.4 Test planet ✅
- Rebuilt `scenes/bodies/test_planet.tscn` as a `StaticBody3D` ("Planet")
  with a `CSGSphere3D` mesh (earth material), a `CollisionShape3D` and a
  `GravityComponent`. The planet creates its own `SphereShape3D` in `_ready`,
  so the shape can't be the wrong type and instances never share one.
- Added a small `@tool` root script, `scripts/bodies/planet.gd` (`Planet`).
  Its single exported `radius` sizes the mesh, collider and
  `GravityComponent.radius` together.
- Starting values: radius 50, mass 10000, placed at `(0, 0, -300)` in
  `test_level.tscn`. With the level's `gravity_constant = 10` the player
  reaches the surface in about 22s.
- Stop-gap: `GravityComponent._ready` now sets `source_position`. Without
  this, the first physics tick saw the source at the origin and flung the
  player away. 0.9 removes the cached field entirely.
- The planet node comes after the Player in the level because of the
  startup-order bug (fixed in 0.8).
- **Done:** smoke passes; `tests/bodies/test_planet.gd` passes (the radius
  contract, each planet owning its collider sphere, and the level planet
  being heavier than the player's starting
  mass); a 60s headless run with no input drifts the player onto the surface,
  where it rests at a distance of 50.48 (planet radius + player radius).

## 0.5 Movement correctness ✅
Tested with gravity off: the level sets the player's `gravity_constant` to 0
until 0.9. The planet stays in the level as a solid obstacle.
- Thrust and rotation now use `body.global_basis` instead of `body.basis`.
- The player's RigidBody uses `linear_damp_mode` Replace with
  `linear_damp = 0`, so velocity no longer decays under the project default.
- Thrust is a force (`apply_central_force`). The old
  `sqrt(thrust_mass / current_mass)` scaling, `thrust_mass` and `thrust_rate`
  are gone. `vertical_thrust_force` and `back_thrust_force` (default 1.0, the
  old tuned feel at mass 1) sit under `@export_group("Thrust")`.
- Rotation is a torque (`apply_torque`), so mass slows turning through the
  body's inertia (a radius-0.5 sphere, I = 0.1·m). `angular_damp` stays as
  the non-physical rotational drag. `roll_torque` and `turn_torque` (0.05,
  which gives the old 0.5 rad/s² at mass 1) sit under
  `@export_group("Rotation")`.
- Moved here from gravity: `current_mass` keeps `body.mass` in sync, because
  thrust needs it to scale with mass.
- **Done (tests, `tests/player/test_player.gd`):**
  - With the root rotated 90°, back thrust accelerates the ship along its
    *visual* forward.
  - With no input and no sources, linear velocity stays constant (Newton's 1st law).
  - The same thrust input gives half the acceleration at twice the mass.
  - The same turn or roll input gives half the angular acceleration at twice
    the mass.
  - `body.mass` follows `current_mass`, and a non-positive mass is reported
    and ignored.

## 0.6 Player components ✅
Gravity stays off in the level (`gravity_constant = 0`), and its code stays
on the player root, unchanged, until 0.7.
- The root of `player.tscn` is now the `RigidBody3D` (`Player`), so
  `Player.global_position` is the ship's position and `player.body` is gone.
- `player.gd` is split into components (`scripts/components/`), each wired
  through `@export` node paths:
  - `InputComponent`: the base class (interface) for anything that drives
    a ship. It holds `thrust_intent` (z only: forward is -1) and
    `rotation_intent` (y: turn, z: roll), runs before the other components
    (`process_physics_priority = -1`), and implementations override
    `_update_intent`. The thruster and rotation components take any
    `InputComponent` as `flight_input`, so they aren't tied to the player
    (e.g. an AI input later). The base class on its own intends nothing,
    which tests use as fake intent.
  - `PlayerInputComponent`: the only script that reads `Input`.
  - `ThrusterComponent.apply_thrust(intent)`: intent → force, with
    `back_thrust_force`. The vertical thrusters (`top_thruster`,
    `bottom_thruster`, `vertical_thrust_force`) were removed; the ship only
    thrusts forward.
  - `RotationComponent.apply_rotation(intent)`: intent → torque, with
    `turn_torque` and `roll_torque`.
  - `MassComponent`: `starting_mass`, `current_mass` and `mass_changed`, and
    it keeps `body.mass` in sync.
  - `Intent.is_within_unit` (`scripts/core/intent.gd`) is the shared
    [-1, 1] check.
- Restarting moved to `TestLevel._unhandled_input`.
- Added a debug overlay (`scenes/ui/debug_overlay.tscn`, `DebugOverlay`) to
  the test level. It shows the player's position, rotation, velocity, spin
  and mass, and is hidden in release builds. `decimals` is exported.
- **Done:** all 0.5 tests pass against the new components
  (`tests/player/test_player.gd`). Each component has its own test file in
  `tests/components/` (with the `FakeBody` helper). `Input.` only appears in
  `PlayerInputComponent`. The suite passes 38/38.
  - Manual (user): check the flight feels the same as at the end of 0.5.

## 0.7 Gravity component ✅
Agreed: only a source *strictly* heavier than the player pulls.
- Renamed `component_gravity.gd` → `gravity_component.gd` (the `.uid` moved
  with it, so the UID is kept).
- `GravityComponent` now checks that `mass` and `radius` are positive and
  that its parent is a `Node3D`.
- `GravityReceiverComponent` (`body`, `gravity_constant`) holds the player's
  old gravity code, with today's maths unchanged. `Player` only wires up its
  components now (`gravity_receiver`). The level's `gravity_constant = 0`
  override moved onto `Player/GravityReceiverComponent`.
- `remove_gravity_source` now erases instead of appending (the 0.8 registry
  still replaces the list). The startup-order bug remains until 0.8.
- **Done:** `tests/components/test_gravity_component.gd` and
  `tests/components/test_gravity_receiver_component.gd` pass, along with the
  0.4 and 0.6 tests. The suite passes 48/48.

## 0.8 Gravity registry ✅
Agreed: `sources_heavier_than` returns packed indices. Mass and radius are
pushed to the registry, and positions are refreshed each physics frame.
- `GravityRegistry` autoload (`scripts/core/gravity_registry.gd`). It holds
  parallel `PackedVector3Array positions`, `PackedFloat64Array masses` and
  `PackedFloat64Array radii`, plus a source → index dictionary, and removes
  sources with an O(1) swap-remove. The API is `register`, `unregister`,
  `update`, `count`, `index_of` and `sources_heavier_than(mass)`.
- `GravityComponent` registers in `_enter_tree` and unregisters in
  `_exit_tree`. `GravityReceiverComponent` reads the registry's packed
  arrays each physics frame. The `gravity_affected` group and the
  receiver's own source list are gone, along with the startup-order bug.
- **Done:** `tests/core/test_gravity_registry.gd` covers the contract. The
  receiver tests show that a freed source no longer pulls, and that a source
  added before the receiver still pulls. The suite passes 58/58.

## 0.9 Gravity correctness ✅
- The cached `source_position` field is gone (along with the `_process`
  copy and the 0.4 stop-gap). `GravityComponent.source_node` is the parent
  `Node3D`, and the registry reads its `global_position` each physics frame.
- `GravityReceiverComponent` applies `G·m·M / r²` with `apply_central_force`,
  clamps `r` to the source radius, and reports a non-finite force.
- Gravity is back on in the level (`gravity_constant = 10` on
  `Player/GravityReceiverComponent`).
- **Done:**
  - Tests: the acceleration is the same at body mass 1 and 100, the force is
    inverse square outside the radius and constant inside it, the force at
    distance 0 is finite (zero), equal or lighter sources give no force, and
    registry positions follow their parents. The suite passes 64/64.
  - The 60s headless drift run lands the player on the surface by 20s and
    rests at a distance of 50.48, as in 0.4.

## Phase 0 done when ✅
- The project opens headless with no errors, and the full test suite passes.
- The test level contains only the player and one test planet.
- The player flies with correct Newtonian thrust and gravity, and can't
  pass through the planet.
- The code is in components, parameters are exposed through exports, and
  there are no Americanisms.

# Phase 1: Core flight
- Add all controls with controller support
- Ensure gravity and mass works as intended (agreed: Phase 0's tests cover
  it, so there is no separate step)
- Add the lose condition

Agreed layout: boost is Shift / right trigger, pitch is W/S / left stick Y,
yaw is A/D / left stick X, roll is Q/E / bumpers, pause is Esc / Start, and
warp out is Space / A. The right stick moves the camera. The lose condition
is any contact with a body heavier than the player. The booster has a fuel
tank that refills over time (about 5s from empty to full to start). Refill
is a shop stat.

## 1.1 Controls and pitch
- Add `pitch_up`/`pitch_down`, `pause` and `warp_out` actions, plus
  controller bindings for every action. Stick actions get a small dead zone.
- `PlayerInputComponent` fills `rotation_intent.x` (pitch).
  `RotationComponent` gains `pitch_torque`.
- `warp_out` is an input action only. Phase 3 gives it behaviour, have debug print
statment only for now.

## 1.2 Fuel component ✅
- `FuelComponent` (`scripts/components/fuel_component.gd`) has `tank_size`
  1.0, `burn_rate` 1.0, `refill_time` 5.0 and `refill_delay` 0.0 under
  `@export_group("Fuel")`. It exposes a read-only `fuel`, `draw(amount)` and
  `fuel_changed`. It sits on the player (`Player.fuel_component`) but nothing
  draws from it until 1.3.
- The debug overlay shows `Fuel      <remaining> / <tank_size>`.
- **Done:** `tests/components/test_fuel_component.gd` covers the contract:
  - the tank starts full
  - a draw is clamped to what's left
  - a negative draw is reported
  - an empty tank refills in `refill_time`
  - a boost (even on an empty tank) blocks the refill, but a zero draw
    doesn't
  - `refill_delay` is respected
  - a shrinking tank clamps the fuel
  - bad settings are reported and ignored
  - `fuel_changed` is emitted once for each change, and never while the
    tank is full and idle

  The overlay test checks the fuel line. The suite passes 87/87.

## 1.3 Thrust uses fuel ✅
- `ThrusterComponent` has an optional `fuel` export (the player links its
  `FuelComponent`). `apply_thrust(intent, delta)` asks for
  `burn_rate · |z| · delta` and scales the force by drawn / asked for.
- **Done:** tests in `tests/components/test_thruster_component.gd` show:
  - full boost from a full tank lasts 1s and then gives no more
    acceleration
  - releasing the boost refills the tank in 5s
  - half boost lasts twice as long
  - a thruster with no fuel link never runs out
  - a rejected call draws no fuel

  `tests/player/test_player.gd` checks that the player's boost drains its
  own tank. The suite passes 93/93.
  - Manual (user): check how 1s of boost and a 5s refill feel.

## 1.4 Camera
- A camera component on the player that the right stick orbits around the
  ship.

## 1.5 Pause
- Esc / Start pauses and unpauses the game. While paused, physics stops.

## 1.6 Crash detection
- `CrashComponent`: contact with a body heavier than the player emits a
  crash signal once.
- In debug builds, a crash prints `[Debug] Lost: crashed into <body>`.

## 1.7 Lose flow
- On a crash the level shows a lose message, stops the player, and offers a
  restart.

# Phase 2: Procedural generation
- Add mass pickups and a procedural generation manager
- `scenes/bodies/test_planet.tscn` becomes a standard spawnable body (rename
  it to match). The spawner sets its `radius` and mass. Swap `CSGSphere3D`
  for a `MeshInstance3D` (CSG is too costly at scale).
- When procedural generation replaces `test_level.tscn`, delete
  `test_level_planet_is_heavier_than_player_starting_mass` (and
  `LEVEL_SCENE`) from `tests/bodies/test_planet.gd`. It tests the level,
  not the planet.
- Make sure mass pickups spawn around ("in orbit") of bigger masses
    - There is a hierarchy of orbits for the procedural generation (moons upon moons upon moons)
- Game must be 60fps

# Phase 3: Game Loop
- Ensure the player can collect mass, once enough has been collected then they can warp out
- Can spend that mass in the shop to upgrade for the next run.

# Phase 4: HUD and art
- Add a HUD and minimap
- Integrate the art in dev-ayla

# Phase 5: Game Feel and Juice
- Add controller shake, camera shake, camera movement, VFX, etc
