# Mass bodies
**Status:** done ✅ (Phase 0, step 0.4; Phase 2, steps 2.1 and 2.1a)

One `MassBody` type at every scale. A body lighter than the player is a
pickup, and a heavier one is deadly. It started as the test planet, and
[procedural generation](procedural_generation.md) spawns it.

## Contracts

### MassBody (`scripts/bodies/mass_body.gd`, was `Planet`)
- An `AnimatableBody3D` (kinematic, so orbits can move it in 2.3).
- Setting `radius` or `mass` requires a value > 0. A non-positive value is
  reported and ignored, so the old value stays.
- After the radius or mass is applied:
  - the `MeshInstance3D` uses the shared unit sphere and is scaled to
    `radius`
  - the collider uses the body's own `SphereShape3D` (made in `_ready`, so
    no two bodies share one), sized to `radius`
  - `GravityComponent.radius` and `.mass` equal `radius` and `mass`
- Every body joins the `mass_bodies` group.

### MassTintDebug (`scripts/ui/mass_tint_debug.gd`)
- When `enabled` (and only in debug builds), every `MassBody` is tinted
  `heavier_colour` (red) if its mass is strictly greater than the player's
  `current_mass`, and `lighter_colour` (green) otherwise. The earth texture
  is kept.
- There are two shared tinted materials, and a body's override is only
  reassigned when its class changes. When disabled, the override is cleared.
- With a `streamer` (optional, step 2.8), every drawn instance of every
  expanded parent is tinted the same way by its layout mass, through
  `OrbitRenderer.set_tint`. Instances are retinted when the player's mass
  or `enabled` changes, and a newly expanded parent is tinted at once. When
  disabled, drawn instances are untinted (white).

## Steps

### 0.4 Test planet ✅
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

### 2.1 MassBody ✅
- `test_planet.tscn` / `planet.gd` became `mass_body.tscn` / `mass_body.gd`
  (`MassBody`, an `AnimatableBody3D`). The UIDs are kept. It uses a shared
  `resources/meshes/unit_sphere.tres` (with `resources/materials/earth.tres`)
  scaled to the radius, instead of `CSGSphere3D`. `mass` is now exported on
  the body and passed to its `GravityComponent`.
- **Done:** `tests/bodies/test_mass_body.gd` covers:
  - the radius and mass reach the mesh, collider and gravity component
  - bad values are reported and ignored
  - bodies share the mesh but not the collider shape
  - the level body is heavier than the player
  - a moving body crashes the player

  The headless level run still ends in `[Debug] Lost: crashed into
  MassBody`.

### 2.1a Debug mass tint ✅
- `MassTintDebug` (in the test level) tints bodies green (lighter or equal)
  and red (heavier) relative to the player. Turn it off with `enabled`.
- **Done:** `tests/ui/test_mass_tint_debug.gd` covers:
  - red when heavier, green when lighter or equal
  - the texture is kept
  - the tint flips when the player outgrows a body
  - disabling clears the override

  The suite passes 140/140.
