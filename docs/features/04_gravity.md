# Gravity
**Status:** done ✅ (Phase 0, steps 0.7 to 0.9)

The player feels gravity from mass bigger than itself, but not from smaller
mass. Mass objects don't feel gravity. Agreed: only a source *strictly*
heavier than the player pulls.

## Contracts

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
- Changed 2026-11-24 (see [mass tanks](14_mass_tanks.md)): the falloff is `G·M / r ^
  falloff_exponent` (2 by default, so the above still holds), only
  sources heavier than the core mass (`mass_component`, else `body.mass`)
  pull, the check is on the acceleration, and with `drift_enabled` the
  pull builds a damped `drift` added straight to the velocity instead of
  a force. `acceleration_at` is shared with `PathPredictor`.

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

## Steps

### 0.7 Gravity component ✅
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

### 0.8 Gravity registry ✅
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

### 0.9 Gravity correctness ✅
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
