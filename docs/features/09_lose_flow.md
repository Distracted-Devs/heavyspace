# Lose flow
**Status:** done ✅ (Phase 1, steps 1.6 and 1.7)

The lose condition is any contact with a body heavier than the player. It
stops the ship and offers a restart. Contacts are sorted by mass, so pickups
(Phase 3) can use the lighter ones.

## Contracts

### ContactComponent (`scripts/components/contact_component.gd`)
- It only notices contacts and sorts them by mass. Others react: the lose
  flow to heavier contacts, and pickups (Phase 3) to lighter ones.
- In `_ready` it turns on `body.contact_monitor` and makes sure
  `body.max_contacts_reported ≥ 1` (a post-condition), and it listens to
  `body_entered`.
- The other body's mass comes from a `GravityComponent` directly under it,
  falling back to `RigidBody3D.mass`. A body with neither has no mass and
  emits nothing.
- Each new contact emits exactly one of these, comparing against
  `mass_component.current_mass`:
  - `heavier_contact(other, other_mass)` when the other mass is strictly
    greater
  - `lighter_contact(other, other_mass)` when it's equal or less (agreed:
    equal counts as lighter, as with gravity)

  There's no latch: every new contact emits.
- Later (Phase 3), it may take an optional `Area3D` sensor for the pickup
  radius, which feeds the same signals.

### LoseController (`scripts/levels/lose_controller.gd`)
- It listens to the player's `contact_component.heavier_contact`.
- The first heavier contact sets `lost = true`, emits `lost_game(other)`
  exactly once, calls `player.stop_flight()`, and in debug builds prints
  `[Debug] Lost: crashed into <name>`. Later contacts do nothing, and
  `lost` stays true until the level reloads. A lighter contact never
  loses.
- `LoseOverlay` shows "Crashed! Press R / Back to restart", only after
  losing. Restart (via `PauseController`) and pause still work.

### Player.stop_flight (`scripts/player/player.gd`)
- It freezes the body where it is, and disables the input, thruster,
  rotation, fuel, gravity receiver and camera components (agreed: the
  camera stops too), and the pickup component when the player has one (see
  [player growth](11_player_growth.md)). The changes are deferred, because a contact arrives
  during the physics step.
- Post-condition, once applied: the body is frozen and every listed
  component has `PROCESS_MODE_DISABLED`. From then on, the ship's position,
  fuel and camera don't change.

## Steps

### 1.6 Contact component ✅
- `ContactComponent` (`Player/ContactComponent`) sorts the player's
  contacts into `heavier_contact` and `lighter_contact` (renamed from
  `CrashComponent`, since pickups will use it too). `mass_of(other)` reads a
  child `GravityComponent`, then `RigidBody3D.mass`, and returns `NAN` for a
  body with no mass. Nothing listens to it yet (1.7).
- **Done:** `tests/components/test_contact_component.gd` covers:
  - the body reports contacts
  - flying into a heavier planet emits `heavier_contact` once, with its mass
  - lighter and equal-mass bodies emit `lighter_contact`
  - a massless body emits nothing, though the bodies did touch
  - touching again emits again
  - a `GravityComponent` mass wins over `RigidBody3D.mass`

  The suite passes 126/126.

### 1.7 Lose flow ✅
- `LoseController` (`scripts/levels/lose_controller.gd`, in the test level)
  latches on the first `heavier_contact`, calls `Player.stop_flight()`,
  prints `[Debug] Lost: crashed into <name>` and emits `lost_game`.
- `Player.stop_flight()` freezes the body and disables the input, thruster,
  rotation, fuel, gravity receiver and camera components (deferred, because
  the contact arrives mid-physics-step).
- `LoseOverlay` (`scenes/ui/lose_overlay.tscn`) shows "Crashed! Press R /
  Back to restart" after losing.
- **Done:**
  - `tests/levels/test_lose_controller.gd` covers:
    - the first heavier contact loses once
    - a lighter contact never loses
    - after losing, the ship, its fuel and the camera stay put, even with
      boost held
    - flying into a real planet loses

    `tests/ui/test_lose_overlay.gd` checks the message. The suite passes
    132/132.
  - In a 30s headless run of the level (`--fixed-fps 60`), the player
    drifts onto the planet and prints `[Debug] Lost: crashed into Planet`,
    with no broken contracts.
