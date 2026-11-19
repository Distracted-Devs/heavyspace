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
  reported and no force is applied.

### RotationComponent (`scripts/components/rotation_component.gd`)
- Applying rotation requires every axis of the rotation intent to be within
  [-1, 1], and `turn_torque` and `roll_torque` to be ≥ 0. If either is
  broken, it's reported and no torque is applied.

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
- Keep `scripts/components/component_gravity.gd`, since the planet needs it.
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

## 0.7 Gravity component
Agree the `GravityComponent` and `GravityReceiverComponent` contracts with the
user before building (e.g. bad mass or radius). Also decide whether a source
of exactly the player's mass pulls (today it does; the design doc says only
bigger mass pulls).
- **Naming:** rename `component_gravity.gd` → `gravity_component.gd` so file
  names match class names (`snake_case` of `class_name`). Move the `.uid`
  with it so the UID is kept.
- **`GravityReceiverComponent`:** move the player's gravity code into its own
  component, carrying over today's maths and today's source list unchanged
  (the registry replaces the list in 0.8).
- **Done:** each gravity component has its own test file, and the 0.4 and 0.6
  tests still pass.

## 0.8 Gravity registry
Agree the `GravityRegistry` contract with the user before building (e.g.
duplicate register, stray unregister, the packed arrays staying the same
length, what `sources_heavier_than` returns).
- **Data-oriented registry:** a `GravityRegistry` autoload.
  `GravityComponent` registers itself in `_enter_tree` and unregisters in
  `_exit_tree`. Receivers ask the registry each physics frame. Store
  positions/masses/radii in parallel `Packed*Array`s behind a small API
  (`register`, `unregister`, `sources_heavier_than(mass)`), so Phase 2 can
  scale to thousands of sources without changing the callers.
- This replaces the `gravity_affected` group and the receiver's own source
  list, which removes the `append`/`erase` bug and the startup-order bug.
- **Done (tests):**
  - A freed source is no longer returned by the registry.
  - A source added *before* the player is ready still pulls on the player.

## 0.9 Gravity correctness
Fix the gravity maths in `GravityReceiverComponent` / `GravityComponent`,
then turn gravity back on in the level (`gravity_constant = 10`).
- `source_position` is copied from the parent in `_process`, which runs one
  frame behind physics (the `# TODO - fragile`). Read the parent's
  `global_position` when it's needed (or refresh the registry's packed
  positions each physics frame) and remove the cached field, including the
  0.4 stop-gap in `GravityComponent._ready`.
- The force uses `F = G·m·M / r²` with `body.mass` already synced (0.5), so
  the acceleration doesn't depend on the player's mass, as Newton says.
- No softening: use `GravityComponent.radius` and clamp `r` to at least the
  radius, so the force can't blow up near a centre or divide by zero.
- Use `apply_central_force` (clearer about intent than `apply_force` with no
  offset).
- **Done (tests):**
  - The acceleration towards a source is the same at player mass 1 and 100.
  - A source that isn't heavier than the player (as agreed in 0.7) gives
    zero force.
  - The force at distance 0 is finite.
  - The 0.4 60s drift run still lands the player on the planet surface.

## Phase 0 done when
- The project opens headless with no errors, and the full test suite passes.
- The test level contains only the player and one test planet.
- The player flies with correct Newtonian thrust and gravity, and can't
  pass through the planet.
- The code is in components, parameters are exposed through exports, and
  there are no Americanisms.

# Phase 1: Core flight 
- Add all controls with controller support
- Ensure gravity and mass works as intended
- Add the lose condition

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
