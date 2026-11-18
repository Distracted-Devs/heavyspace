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

## 0.3 Strip back to the player
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

## 0.4 Test planet
`scenes/bodies/test_planet.tscn` currently points at `scripts/bodies/planet.gd`,
which doesn't exist. Rebuild it as an entity made from components:
- Root `StaticBody3D` ("Planet") with:
  - `CollisionShape3D` (a sphere), so the player can't fly through it. The
    lose condition on impact is Phase 1.
  - A mesh (keep `CSGSphere3D` + earth material for now).
  - `GravityComponent` (`mass`, `radius`).
- No root script unless one is needed. Size the mesh and collider from one
  exported `radius` so they can't drift apart (a small `@tool` script, or
  keep it in the component).
- Starting values: radius 50, mass well above the player's `starting_mass`,
  placed ~300 units in front of the player in `test_level.tscn`. Tune by feel.
- **Done:**
  - Smoke passes, and the level shows the planet.
  - Test: the planet's `GravityComponent` mass > the player's starting mass.
  - Manual: with no input, the player drifts towards the planet and stops on
    its surface instead of passing through it.

## 0.5 Gravity correctness
Bugs in `player.gd` / `component_gravity.gd`:
- `remove_gravity_source` calls `append` instead of `erase`. Also stop
  `apply_gravity` from removing items from the array while it iterates over it.
- Registration depends on startup order: sources only register with nodes
  already in `gravity_affected` at the moment the source's `_ready` runs. Fix
  it with the registry from 0.6, not by reordering the scene.
- `source_position` is copied from the parent in `_process`, which runs one
  frame behind physics (the `# TODO - fragile`). Read the parent's
  `global_position` when it's needed instead, and remove the cached field.
- The gravity force scales with `current_mass`, but the RigidBody's `mass` is
  never set to match, so heavier players accelerate faster. Pick one model
  and test it:
  - **Recommended:** sync `body.mass = current_mass` and apply
    `F = G·m·M / r²`. The acceleration then doesn't depend on the player's
    mass, as Newton says.
- No softening: use `GravityComponent.radius` and clamp `r` to at least the
  radius, so the force can't blow up near a centre or divide by zero.
- Use `apply_central_force` (clearer about intent than `apply_force` with no
  offset).
- **Done (tests):**
  - A freed source is no longer in the player's source list.
  - A source added *before* the player is ready still pulls on the player.
  - The acceleration towards a source is the same at player mass 1 and 100.
  - A source with mass ≤ the player's mass gives zero force.
  - The force at distance 0 is finite.

## 0.6 Movement correctness
- Thrust and rotation use `body.basis` (relative to the parent), but they
  need `body.global_basis`. They only work today because the `Player` root is
  barely rotated.
- Thrust changes `linear_velocity` directly. Make it a force
  (`apply_central_force`) so it follows the same Newtonian model as gravity.
  Keep the old `sqrt(thrust_mass / current_mass)` scaling only if tuning
  shows it's needed. Booster strength becomes a shop stat later, so expose it.
- Rotation can stay non-physical (the design allows this). Keep the
  direct angular velocity with `angular_damp` as the rotational drag, but make
  the turn rates `@export`s under `@export_group("Rotation")`.
- **Done (tests):**
  - With the root rotated 90°, back thrust accelerates the ship along its
    *visual* forward.
  - With no input and no sources, linear velocity stays constant (Newton's 1st law).
  - The same thrust input gives half the acceleration at twice the mass.

## 0.7 Design paradigms (structure)
Bring the existing code in line with `developer_instructions.md` before
Phase 1 adds to it.
- **Player entity root:** make the root of `player.tscn` the `RigidBody3D`
  itself, rather than a `Node3D` wrapping one. Then `Player.global_position`
  is the ship's position and no system has to know about `player.body`.
- **Split `player.gd` into components** (children of the player entity, one
  small script each, each with `@export`/`@export_group` parameters):
  - `FlightInputComponent`: reads `Input` and outputs an intent (thrust
    vector, rotation vector). This is the only place that touches `Input`, so
    controller support in Phase 1 is a single-file change, and other
    components can be tested with fake intent.
  - `ThrusterComponent`: intent → force.
  - `RotationComponent`: intent → angular velocity.
  - `MassComponent`: `current_mass`, a `mass_changed` signal, and it keeps
    `body.mass` in sync.
  - `GravityReceiverComponent`: asks the registry for sources and applies
    gravity.
  - Restarting goes to the level or a game manager, not the player.
- **Gravity registry (data-oriented):** a `GravityRegistry` autoload.
  `GravityComponent` registers itself in `_enter_tree` and unregisters in
  `_exit_tree`. Receivers ask the registry each physics frame. Store
  positions/masses/radii in parallel `Packed*Array`s behind a small API
  (`register`, `unregister`, `sources_heavier_than(mass)`), so Phase 2 can
  scale to thousands of sources without changing the callers. This also
  fixes the startup-order bug from 0.5.
- **Naming:** rename `component_gravity.gd` → `gravity_component.gd` so file
  names match class names (`snake_case` of `class_name`). Rename in the
  editor so UIDs are kept.
- **Done:**
  - All 0.5 / 0.6 tests still pass against the new components.
  - Each component has its own test file.
  - `Input` is only referenced in `FlightInputComponent`
    (`grep -r "Input\." scripts/`).
  - Manual: the flight feels the same as it did at the end of 0.6.

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
