# Camera
**Status:** done ✅ (Phase 1, step 1.4)

A third-person camera that follows the ship's rotation, turned by the right
stick or the mouse. The input side (`look_intent`, `mouse_look`) is in
[controls](controls.md).

## Contracts

### CameraComponent (`scripts/components/camera_component.gd`)
- A pivot on the player that holds the `Camera3D` and follows the ship's
  rotation.
- The stick turns the view at `look_speed` (2.0 rad/s) × how far it's
  pushed. The mouse turns it by exactly `mouse_look`.
- Neither the stick nor the mouse springs back. The camera stays where it
  was left, starting at yaw 0 and `start_pitch`. (Agreed: the spring back
  was dropped.)
- `look_speed` must be ≥ 0, `distance` must be > 0, and `max_pitch` must be within (0°, 90°). A bad value is
  reported and ignored.
- Invariants, after every update: the pitch is within ±`max_pitch`, and the
  camera is `distance` from the ship and looks at it.

## Steps

### 1.4 Camera ✅
- Added the `look_left/right/up/down` actions on the right stick (0.2 dead
  zone). `PlayerInputComponent` reads them with one `get_vector` call into
  `look_intent`, collects mouse motion into `mouse_look`
  (`mouse_sensitivity`), and captures the mouse (`capture_mouse`).
- `CameraComponent` (`Player/CameraComponent`, a `Node3D` pivot holding the
  `Camera3D` and its spotlight) has the exports `look_speed`,
  `max_pitch_degrees` (80), `start_pitch_degrees` (-20) and `distance`
  (2.7). It has no spring back (agreed: dropped). The camera now looks
  straight at the ship. The old offset framed it slightly below centre.
- **Done:** `tests/components/test_camera_component.gd` covers:
  - the start pose
  - stick right turns the view right, and stick up raises it
  - pitch is clamped
  - the mouse moves the view by exactly `mouse_look`
  - a released stick leaves the view where it is
  - the camera follows the ship's rotation
  - bad settings are reported and ignored

  The input tests cover `look_intent` and check that each mouse movement is
  used exactly once. The suite passes 106/106, and a 10s headless run of the
  level reports no broken contracts.
  - Manual (user): check the camera feel, the mouse sensitivity and the
    start pitch.
