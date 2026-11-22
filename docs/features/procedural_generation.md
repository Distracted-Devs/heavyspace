# Procedural generation
**Status:** planned (Phase 2, steps 2.2 to 2.4, 2.6 and 2.7)

A procedurally generated level of [mass bodies](mass_bodies.md) in a
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

## Contracts
None agreed yet. Agree each API's contract with the user at the start of its
step.

## Steps

### 2.2 System generator
- A pure, deterministic function from (seed, body path) to a body spec:
  radius, mass, orbit radius, speed, phase, orbit plane and child count.
  Its rules cover the size ratio and jitter, the minimum size, the maximum
  depth, and orbits that don't overlap.

### 2.3 Orbit system
- A data-oriented system (packed arrays) that moves every live body along
  its orbit each physics frame, parents before children, and writes the
  transforms.

### 2.4 Hierarchy streaming
- A body's children are expanded when the player comes within a multiple of
  that body's system radius, and collapsed past a larger multiple
  (hysteresis). Ancestors and their siblings stay live, so large bodies are
  always in the background. The camera's far plane covers the system.

### 2.6 Generated level
- A generated level replaces `test_level.tscn` as the main scene. The
  player warps in at a safe spot among the smallest bodies. Delete the
  level-specific body test (see above).

### 2.7 Performance
- A headless benchmark of the physics and orbit frame time with a typical
  number of live bodies, held to a 60fps budget (16.6ms).
