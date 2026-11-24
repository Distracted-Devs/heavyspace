# Pause
**Status:** done ✅ (Phase 1, step 1.5)

Pause and unpause on Esc / Start, with restart still available while
paused.

## Contracts

### PauseController (`scripts/levels/pause_controller.gd`)
- It runs while the game is paused (`PROCESS_MODE_ALWAYS`).
  `set_paused(value)` sets `get_tree().paused`, and the `pause` action
  (Esc / Start) toggles it.
- `paused_changed(paused)` is emitted once for each real change. Setting
  the state it's already in does nothing.
- While paused, physics and the player's components stop, so the ship's
  position, velocity, fuel and camera don't change. Restart still works
  while paused (agreed). It's handled by `PauseController`, which unpauses
  first, because `reload_current_scene` keeps the tree paused.
- `PlayerInputComponent` releases the mouse on `NOTIFICATION_PAUSED` and
  recaptures it on `NOTIFICATION_UNPAUSED`, only if `capture_mouse` is on.
- A "Paused" label is visible only while paused.
- Changed 2026-11-24 (see [pre-juice polish](16_pre_juice_polish.md)):
  `PauseMenu` replaces the "Paused" label and `PauseOverlay` is removed.
  `restart()` is split out of the input handling, emits `restarting` and
  reloads the scene unless `reload_on_restart` is off.

## Steps

### 1.5 Pause ✅
- `PauseController` (`scripts/levels/pause_controller.gd`, in the test
  level) toggles pause on Esc / Start and handles restart (moved from
  `TestLevel`, which now only prints the warp debug message).
- `PauseOverlay` (`scenes/ui/pause_overlay.tscn`) shows a centred "Paused"
  label while paused.
- `PlayerInputComponent` releases the mouse when the game pauses and
  recaptures it when it resumes.
- **Done:** `tests/levels/test_pause_controller.gd` covers:
  - `set_paused` and the pause action toggle the tree
  - `paused_changed` is emitted once for each real change
  - the controller runs while paused
  - a paused ship and its fuel are frozen
  - unpausing resumes at the same velocity

  `tests/ui/test_pause_overlay.gd` checks the label. The suite passes
  119/119.
  - Manual (user): restarting while paused, and the mouse being released
    and recaptured. Neither can be tested headless.
