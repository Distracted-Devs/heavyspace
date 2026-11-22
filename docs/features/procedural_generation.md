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

## Idea
"I want you to prototype phase 2. At first lets get one non-procedurally
generated spawn how I want it and then scale it up. First lets get a planet
about 100x bigger than the player with about 100 planets orbiting it in a
ring (think saturn)"

## Prototype log
- v1: hand-built system in `prototypes/procedural_generation/`. A central
  body of radius 50 (100× the ship's 0.5) at (0, 0, -300), with 100 ring
  bodies (radius 0.2–3, biased small) orbiting at 1.6–2.6× its radius in a
  thin ring tilted 20°, on Kepler-style circular orbits. Ring mass scales
  with volume against the ship, so anything bigger than the ship is red.
  The user liked it and tuned: ring_count 500, ring_thickness 10,
  body_radius_min 1, inner_orbit_period 60.
- v2: scaled up. A giant (radius 5000, mass 1e7) with a ring of 10 Saturn
  systems at 1.6–2.6× its radius, each orbiting at the real circular-orbit
  speed (about 100 u/s). The player spawns with its home system's velocity,
  so they fall around the giant together. Spawning all 5,011 bodies cost
  about 14.5ms per physics frame, so a ring is spawned only within 2000 of
  its system and freed past 3000. Orbits are driven by time, so rings
  respawn in place. Now about 5.7ms per physics frame. Every ring body is
  heavier than the ship with the tuned values, and from rest the ship falls
  into its home system in about 10s (true of v1 too).
- v3: the user tested 500 systems (with giant and central mass 1) and the
  game struggled. There were 8,001 real bodies (about 32,000 nodes), and
  physics took 40–90ms per frame. Now drawn bodies are MultiMeshes with
  low-poly spheres, and a vertex shader (`orbit.gdshader`) works out each
  orbit from time. Real `MassBody` nodes exist only for ring bodies within
  60 of the player and systems within 3000. They sit at exactly the shader's
  position and hide their drawn copy. Systems keep at least 600 between
  centres. Result: 213 nodes and 42 bodies. A windowed run on an M1 holds
  60fps (worst frame 17.9ms, 24 draw calls), and also while flying through
  systems at 300 u/s. Awaiting feedback.

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
