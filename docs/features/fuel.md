# Fuel
**Status:** done ✅ (Phase 1, steps 1.2 and 1.3)

The booster's fuel tank, which refills over time (about 5s from empty to
full to start). The refill rate is a shop stat. The thruster's side of the
contract is under `ThrusterComponent` in [flight](flight.md).

## Contracts

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

## Steps

### 1.2 Fuel component ✅
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

### 1.3 Thrust uses fuel ✅
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
