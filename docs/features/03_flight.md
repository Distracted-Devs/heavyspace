# Flight
**Status:** done ✅ (Phase 0, steps 0.5 and 0.6)

Newtonian thrust and rotation, split into components that any input (the
player now, an AI later) can drive. Fuel is in [fuel](06_fuel.md), and the
player's input is in [controls](05_controls.md).

## Contracts

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

## Steps

### 0.5 Movement correctness ✅
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

### 0.6 Player components ✅
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
