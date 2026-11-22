# Roadmap
The phases in order, and the features in each. Every feature has its own
file in `docs/features/` with its contracts and its steps. Step numbers
(e.g. 2.3) are kept across files, since the commit history uses them.

Each step is a single unit of work: break it down, enact it, check its
**Done** contract, then move on. Steps are ordered so that each one leaves
the project opening and running.

# Phase 0: Strip back ✅
- Strip the project back to only the player movement by removing mass collectables and have a test planet in a test level with the player
- Fix any issues in the code.
- Ensure current code matches design paradigms.

Features:
- [Contracts and test harness](features/contracts.md) ✅ (0.1)
- [Mass bodies](features/mass_bodies.md): the test planet ✅ (0.4)
- [Flight](features/flight.md) ✅ (0.5, 0.6)
- [Gravity](features/gravity.md) ✅ (0.7–0.9)

Clean-up steps that don't belong to a feature:

## 0.2 Housekeeping ✅
- `docs/developer_instructions.md` (now split between `AGENTS.md` and the
  `.claude/skills/`): the British English example is backwards (it should
  read "initialise over initialize"), and fix the typos ("effiecient",
  "changed be humans").
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

Features:
- [Controls](features/controls.md) (1.1, 1.4a ✅)
- [Fuel](features/fuel.md) ✅ (1.2, 1.3)
- [Camera](features/camera.md) ✅ (1.4)
- [Pause](features/pause.md) ✅ (1.5)
- [Lose flow](features/lose_flow.md) ✅ (1.6, 1.7)

## Phase 1 done when
- Every control (boost, pitch, yaw, roll, camera look, pause, warp out)
  works on the keyboard and mouse and on a controller. ✅ (Manual check by
  the user is pending.)
- Gravity and mass work as intended. ✅ (Covered by the Phase 0 tests.)
- Touching a heavier body loses, stops the ship and offers a restart. ✅

# Phase 2: Procedural generation
- Add mass pickups and a procedural generation manager
- Make sure mass pickups spawn around ("in orbit") of bigger masses, in a
  hierarchy of orbits (moons upon moons upon moons)
- Game must be 60fps

Features:
- [Mass bodies](features/mass_bodies.md) ✅ (2.1, 2.1a)
- [Procedural generation](features/procedural_generation.md) (2.2–2.4,
  2.6–2.9)
- [Player growth](features/player_growth.md) (2.5)

# Phase 3: Game Loop
- Ensure the player can collect mass, once enough has been collected then they can warp out
- Can spend that mass in the shop to upgrade for the next run.

# Phase 4: HUD and art
- Add a HUD and minimap
- Integrate the art in dev-ayla

# Phase 5: Game Feel and Juice
- Add controller shake, camera shake, camera movement, VFX, etc
