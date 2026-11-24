# Controls
**Status:** in progress (Phase 1, steps 1.1 and 1.4a; 1.1 isn't ticked)

Every control on the keyboard and mouse and on a controller, read in one
place: `PlayerInputComponent`. Camera look is used by [camera](07_camera.md).

Agreed layout: boost is Shift / right trigger, pitch is W/S / left stick Y,
yaw is A/D / left stick X, roll is Q/E / bumpers, pause is Esc / Start, and
warp out is Space / A. The right stick moves the camera.

## Contracts

### PlayerInputComponent (`scripts/components/player_input_component.gd`)
- Held to the `InputComponent` contract. It adds no checks of its own.
- `rotation_intent.x` is `Input.get_axis("pitch_down", "pitch_up")`, so
  W / stick forward pitches down. `invert_pitch` flips the sign.
- Analogue input passes through as it is (a half-pulled trigger gives half
  thrust). Each action has its dead zone (0.2) in the input map, not in
  code.
- `look_intent: Vector2` is one `Input.get_vector("look_left",
  "look_right", "look_up", "look_down")` call on the right stick, and stays
  within [-1, 1].
- `mouse_look: Vector2` is this physics frame's mouse movement in radians
  (pixels × `mouse_sensitivity`, default 0.003). Motion is collected in
  `_unhandled_input`, moved into `mouse_look` at the start of each physics
  frame and then cleared, so each movement is used exactly once. It must be
  finite.
- It captures the mouse (`capture_mouse := true`). 1.5 releases it on pause.
- `active_device` (`Device.KEYBOARD_MOUSE` or `Device.CONTROLLER`) starts
  as `KEYBOARD_MOUSE` and is set from every input event (`_input`):
  - a key, mouse button or mouse motion sets `KEYBOARD_MOUSE`
  - a controller button, or stick/trigger motion past
    `device_switch_deadzone` (0.2), sets `CONTROLLER`, so stick drift can't
    flip it

  `device_changed(device)` is emitted once for each actual change.
- Changed 2026-11-24 (see [pre-juice polish](16_pre_juice_polish.md)):
  the device tracking moved to the `InputDevice` autoload
  (`DeviceTracker`), which keeps running while paused. The component no
  longer has `active_device`, `device_changed`, `device_switch_deadzone`
  or the `Device` enum, and the debug overlay reads the autoload.

## Steps

### 1.1 Controls and pitch
- Add `pitch_up`/`pitch_down`, `pause` and `warp_out` actions, plus
  controller bindings for every action. Stick actions get a small dead zone.
- `PlayerInputComponent` fills `rotation_intent.x` (pitch).
  `RotationComponent` gains `pitch_torque`.
- `warp_out` is an input action only. Phase 3 gives it behaviour, have debug print
statment only for now.

### 1.4a Input device flag ✅
- `PlayerInputComponent.active_device` and `device_changed` track whether
  the keyboard and mouse or a controller was used last. The debug overlay
  shows `Input     Keyboard/Mouse` or `Input     Controller`.
- **Done:** the tests in `tests/components/test_player_input_component.gd`
  cover:
  - it starts as keyboard and mouse
  - a controller button or a stick past the dead zone switches it
  - stick drift doesn't switch it
  - a key or mouse motion switches it back
  - the signal is emitted once for each change

  `tests/ui/test_debug_overlay.gd` checks the overlay line. The suite passes
  111/111.
