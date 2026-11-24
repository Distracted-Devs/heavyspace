# pre_juice_polish
Started 2026-11-24. The live phase is in `.claude/bin/feature status`.

## Idea
What the user imagines, in their words: how it should look, feel and play.

"We're going to clean up some things before working on proper juice"
- Add a pause menu that shows controls.
- When showing controls, switch between controller and keyboard and mouse
  depending on what's active.
- Use the icons in `resources/input_icons/` (coloured default Xbox for the
  controller, dark for the keyboard and mouse). Use the input texture SVGs
  (`resources/input_textures/`) to show the layout of the active device and
  put in the control for each button. When showing e.g. "X to boost", use
  the icons.
- Add jitter to the ring body positions so it doesn't look like they spawned
  on a grid. Make sure they don't overlap, by ensuring the body + jitter max
  is within the cell size.
- Make sure the player spawns facing the nearest planet.
- Make the player slightly bigger.
- When the player is fast, the blue_thrust is barely seen. Spawn more of it
  and have it follow the player more closely.

(The assets were renamed into `resources/input_icons/<device>/<style>/` and
`resources/input_textures/{controller,keyboard}_layout.svg` before the
prototype started, committed in e140d26.)

## Prototype log
One line per iteration: what changed and what the user said about it.

- v1: pause menu (Resume/Restart/Quit) with the active device's layout
  picture and icon labels from the input map; ring bodies jittered within
  cell − diameter; spawn faces the nearest planet; ship ×1.3 (collider too);
  thrust 90 particles, 0.8 s, inheriting the ship's velocity. User: yes to
  device-aware icon prompts for the shop hints and the crash message too.
- v2: shop hints (move/buy/zoom/warp) and the crash message use icon
  prompts read from the input map; one device tracker that runs while
  paused drives every prompt. User (after trying v1): remove the unused
  leader lines from the controller picture and make the icons all the same
  size. So unbound slots' lines are cut from the SVG, and icons are shown
  whole on the pack's shared 128 px canvas at one square size (cropping
  had made wide and arrowed icons a different scale); only keyboard key
  caps are still cropped, to fill their keys.
- User on v2: "Great, amazing." Next: play the warp in reverse when warping
  in; ring bodies pop (retexture or transform change?) at pickup distance;
  streamed-in bodies pop in, so ease their scale in; crash screen in the
  holo/vaporwave theme; a tutorial (step-by-step controls waiting for each
  input: turning and camera, then boost; then arrows to the nearest planet
  and the cargo, "mine your quota"); every run, highlight the warp-out
  prompt once there's enough mass; first shop, highlight how to buy the
  first item; every shop, highlight warp in once nothing's left to buy.
- v3: warp in = WarpEffect's curves played backwards at every run start.
  The pop was two things: the proxy draws its surface in the ring's
  (randomly tilted) frame while the live body was world-aligned, and the
  proxy sphere was 12 segments against the live 64. Live meshes now turn to
  the ring's frame and proxies use 64 segments (GPU cost to check in perf).
  New rings grow in over 0.6 s (ease 2.0, via instance scale only). Crash
  screen rebuilt as a holo panel. Tutorial (once per session): pitch, yaw,
  roll, look, boost, each held until a bar fills, then "MINE YOUR QUOTA"
  with a planet reticle/edge arrow and an arrow at the mass tanks until the
  first pickup. Every run: pulsing "QUOTA MET / WARP OUT" prompt at the
  bottom. Shop: BUY tag over the first buyable item until the first buy;
  pulsing WARP IN with an arrow once nothing can be bought.

## Accepted behaviour
Filled in before acceptance. This is the spec for the rewrite: the behaviours
to keep, the tuned values the user liked, and what was tried and dropped.
From `prototypes/pre_juice_polish/` (`main.gd`, `pause_menu.gd`,
`input_icons.gd`, `device_tracker.gd`, `prompts.gd`, `tutorial.gd`,
`warp_in.gd`, `holo.gd`, `polish_streamer.gd`, `polish_pool.gd`,
`polish_spawn.gd`), v3. The user accepted v3 as it was; no values were
retuned.

### Keep
- **Active device, everywhere.** One tracker follows the device used
  last, and keeps running while paused and in the shop: a key, mouse
  button or mouse motion means keyboard and mouse; a pad button, or a
  stick or trigger past the dead zone (0.2), means controller. Every
  prompt and the pause menu switch the moment it changes.
- **Icons from the input map.** Each prompt is a list of actions; its
  icons are read from their bindings for the active device, so they stay
  right if bindings change. Controller: `resources/input_icons/xbox/default/`
  (coloured A/B/X/Y). Keyboard and mouse:
  `resources/input_icons/keyboard_mouse/dark/`. Mouse look isn't an
  action, so it's shown with `mouse_xy`.
  - Sets that do one job merge into one icon: the four d-pad directions →
    `dpad`; a stick's four directions → `l_2d`/`r_2d`, up+down → `l_y`,
    left+right → `l_x`; wheel up+down → `mouse_scroll`. The arrow keys are
    dropped when other keys (WASD) are bound too.
  - Icons are shown whole on the pack's shared 128 px canvas at one square
    size, so buttons, triggers and sticks keep one scale. Only keyboard
    key caps on the keyboard picture are cropped to their visible pixels,
    so wide keys (Shift, Space) fill their keys.
- **Pause menu** (replaces the "Paused" label): `// PAUSED` title, a
  controls panel and RESUME / RESTART / QUIT buttons. Resume is focused on
  open; pad B also resumes. The panel is the same size for both devices.
  - Controller: `controller_layout.svg` with the leader lines recoloured
    cyan. Each bound control's icon and action name sit at the end of its
    line (left side right-aligned, right side left-aligned); the lines of
    unbound controls are removed. A stick's axes are grouped: pitch on Y
    and yaw on X show as `[l_y] Pitch [l_x] Yaw`; look on both axes as
    `[r_2d] Look`.
  - Keyboard: `keyboard_layout.svg` with cyan outlines. Each bound key is
    outlined magenta on a cyan glow, with its key cap and a short caption
    (`Pitch ↓`, `Yaw ←`, `Roll →`, `Boost`, `Warp out`, `Restart`).
    Bindings that aren't on the picture (Esc, mouse look) are listed
    underneath.
- **Shop hints** become icon prompts: `[W][A][S][D] MOVE`, `[Enter] BUY`,
  `[Q][E][wheel] ZOOM`, and the WARP IN button gets the `warp_out` icon.
  On a pad: `[dpad][l_2d] MOVE`, `[A] BUY`, `[LT][RT] ZOOM`, `[X]`.
- **Crash screen** in the holo look: a dimmed, magenta-scanlined backdrop
  and a magenta-bordered panel with `// CRASHED`,
  `HULL BREACH: YOU HIT SOMETHING HEAVIER` and a pulsing `[R] RESTART`
  prompt.
- **Warp out prompt, every run:** once the warp is ready
  (`WarpController.can_warp()`), a pulsing magenta panel at the bottom
  reads `QUOTA MET` / `[X] WARP OUT >>`. Hidden while warping, crashed
  or in the shop.
- **Shop guidance:** until anything has ever been bought, a bouncing
  `[A] BUY ▼` tag sits over the first buyable node and the BUY hint
  pulses. On every shop screen where nothing can be bought, WARP IN
  pulses with a bouncing `▼` above it.
- **Warp in:** every run starts with the warp-out effect played
  backwards: white, wide (FOV 130), stretched and 400 ahead, easing back
  to the ship in place at the normal FOV over the warp duration.
- **Tutorial, once per game session** (survives restarts and the shop),
  after the warp in, in a cyan holo panel at the bottom:
  1. Flight training, one control at a time: PITCH, YAW, ROLL, LOOK,
     BOOST, each with its icons, a hint and a bar that fills while it's
     held past 0.3. Mouse look fills by distance moved. "NICE!" then the
     next step.
  2. Objective, `MINE YOUR QUOTA` / `FLY INTO BODIES SMALLER THAN YOU TO
     FILL YOUR TANKS`, with a pulsing magenta diamond on the nearest
     planet (or an arrow at the screen edge if it's off screen, with its
     distance), and a gold arrow at the mass tanks gauge (`YOUR QUOTA`).
     After the first pickup: `NICE! KEEP MINING` / `FILL EVERY TANK, THEN
     WARP OUT` for 3 s, then it's done.
  If the run crashes mid-objective, only the objective comes back.
  Hidden while crashed or warping.
- **Ring bodies jitter** anywhere in their cell that keeps the whole body
  inside it (cell minus its diameter), so the grid disappears and bodies
  can't overlap.
- **No pop at live distance:** a live body's surface is turned to its
  ring's frame (the proxy draws in the ring's tilted frame), and the proxy
  sphere has the live sphere's tessellation (64 × 32), so the
  vertex-raised terrain keeps its shape.
- **Streamed-in rings grow in** from nothing to full size over 0.6 s,
  eased in. Only the drawn instance scale changes, so positions and
  pickups are unaffected.
- **Spawn facing:** the ship faces the nearest planet (the nearest root
  child), keeping the ring normal as up.
- **Bigger ship:** the ship's mesh is ×1.3 and its collider grows with
  it, before growth applies.
- **Thrust follows the ship:** 90 particles, 0.8 s lifetime, inheriting
  all of the ship's velocity.

### Tuned values
| value | setting |
|---|---|
| device switch dead zone | 0.2 |
| ring jitter | 1.0 (whole cell minus the body's diameter) |
| grow in | 0.6 s, ease curve 2.0 (ease in) |
| proxy segments | 64 (production was 12) |
| ship scale, collider | ×1.3, scaled too |
| thrust amount / lifetime / inherit velocity | 90 / 0.8 s / 1.0 (were 30 / 1 s / 0) |
| tutorial hold time, threshold | 0.7 s, 0.3 |
| tutorial mouse distance | 600 px |
| tutorial step gap, objective linger | 0.6 s, 3 s |
| planet marker hides within | 150 of the surface |
| prompt pulse | 1.4 Hz, bounce 8 px |
| pause menu controller picture, label column, icon | 420 px, 220 px, 36 px |
| pause menu keyboard picture, legend icon, key caption | 860 px, 36 px, 11 pt |
| pause menu panel | at least 860 × 356 |
| shop hint icons, crash icon, warp-out icon, tutorial icon | 26, 44, 40, 40 px |
| colours | the HUD's cyan, magenta, gold and glass panel (see [skill tree](15_skill_tree.md)) |

### Edge cases noticed
- Cropping icons to their visible pixels makes wide and arrowed icons a
  different scale from round buttons; show the whole canvas instead.
- Godot's SVG renderer draws no text, so the template's own "LT/RT/LS/RS"
  letters don't appear.
- The player's own device tracking stops while paused, so the menu and
  shop need a tracker that keeps running.
- Scaling the renderer node to grow a ring in would scale the CPU-side
  child positions too (pickups, live bodies). Scale the instances only;
  the proxy shader divides its orbit offset by the instance scale.
- A tag waiting outside the tree leaks at exit; keep it parented, hidden.
- A face-button or d-pad leader line is only ~20 px from its neighbours,
  so labels for adjacent slots would touch if both were bound.
- Found by the user after the rewrite: a short boost then coasting sends
  the thrust forwards. The ship's drag is proportional (`linear_damp`
  0.15/s) but particle damping is a flat 0.8–1.5 u/s², so particles that
  inherit all of the ship's velocity overtake it (at speed 100, after
  about 0.67 s of their 0.8 s life). Agreed fix, as a follow-up after the
  perf review: inherit `e^(−drag × lifetime)` of the velocity (≈ 0.89),
  derived from the ship's drag, so no particle can overtake within its
  lifetime at any speed. It changes the thrust contract and its test.

### Tried and dropped, or test-only
- Cropping every icon (v1).
- The template's unused leader lines (v1).
- The arrow keys alongside WASD in prompts.
- Test-only: the tutorial's `every_run`.

## Decision
- 2026-11-24: done. The prototype was deleted.
- 2026-11-24: accepted, moving to the rewrite.

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written. The user agreed the split on
2026-11-24 and asked to go ahead, being told of every new or changed
contract. Agreed then: one `InputDevice` autoload replaces the player's own
device tracking, and ring jitter is a general `Tier` rule.

### PlayerSpawn (changed, see [procedural generation](10_procedural_generation.md))
- `face_nearest_planet` (exported, off; on in the level). When on, after
  the player is placed (and stopped, if `start_at_rest`), it faces (−Z)
  the centre of the nearest root child at the spawn time. Its up is as
  close to the home ring plane's normal as the facing allows (the normal
  projected off the facing). Its position and velocity are unchanged.
- Off, it faces along its orbit as before.

### Tier (changed, see [procedural generation](10_procedural_generation.md))
- `jitter` (exported, 0–1, default 1): how far each child may move from
  its cell's centre, as a share of its room.
- `min_separation` defaults to 0 (the ring tier's value). The systems tier
  keeps 400, which is its cell, so its children stay centred.
- `require_valid` replaces "min_separation ≥ 2 × radius_max" with
  "2 × radius_max ≤ cell_size" (every child fits in a cell) and
  "0 ≤ min_separation ≤ cell_size", and adds "jitter in [0, 1]".

### TierGenerator.generate (changed, see [procedural generation](10_procedural_generation.md))
- A child's radius is drawn before its position. Its space is
  `s = max(radius, min_separation ÷ 2)`, and on each axis it sits
  `(u − 0.5) × jitter × (cell_size − 2s)` from its cell's centre, `u`
  uniform in [0, 1). So the space never leaves the cell.
- At time 0, siblings never overlap and are at least `min_separation`
  apart. Still deterministic for the same inputs.

### MassBody (changed, see [mass bodies](02_mass_bodies.md))
- `surface_frame` (default identity): the rotation the body's surface is
  drawn in. Setting it requires a rotation (orthonormal, not mirrored); a
  bad value is reported and ignored.
- Afterwards, and after any radius change, the mesh's basis is
  `surface_frame × radius`. Its collider and gravity don't turn.

### LiveBodyPool (changed, see [procedural generation](10_procedural_generation.md))
- A promoted body's `surface_frame` is its renderer's global basis,
  orthonormalised: the frame its proxy drew the surface in. So the
  pattern doesn't jump round when a body goes live or is released.

### OrbitRenderer (changed, see [procedural generation](10_procedural_generation.md))
- `proxy_segments` defaults to the live unit sphere's radial segments
  (64), and the proxy's rings are half of them (32, the unit sphere's), so
  drawn and live bodies have the same vertex-raised shape. It stays
  exported for the performance review.
- `display_scale` (default 1) requires a finite value ≥ 0; a bad value is
  reported and ignored. Afterwards every instance is drawn at
  `max(display_scale, 0.001) × its radius` (`drawn_radius(index)`), so the
  proxy shader never divides by zero. Only the uploaded transforms change:
  `instance_radius`, `child_positions`, hidden and tint are untouched, and
  the shader keeps each body's centre on its orbit.
- At 1 it uploads its own buffer unchanged. Hiding or tinting while scaled
  keeps the scaled size.

### GrowInEffect (`scripts/effects/grow_in_effect.gd`)
- Exports the `HierarchyStreamer`, `grow_time` (0.6 s, ≥ 0) and
  `ease_curve` (2.0, > 0, Godot's `ease()`: above 1 eases in). Bad values
  are reported and ignored. It requires a streamer.
- Each renderer the streamer expands after the effect is ready starts at
  `display_scale` 0. Each frame (`advance(delta)`, `delta ≥ 0`) it becomes
  `ease(min(elapsed ÷ grow_time, 1), ease_curve)`, and once the time is up
  it is exactly 1 and the renderer is no longer tracked.
- `grow_time` 0 leaves new renderers at full size. A renderer the
  streamer collapses while growing is dropped. It pauses with the game.
- `growing_count()` is how many renderers are still growing. Renderers and
  their elapsed times are kept in flat arrays with swap-remove.

### WarpEffect (changed, see [game loop](12_game_loop.md))
- `play_in()` has `play()`'s pre-conditions. It records the camera FOV
  and the mesh scale and position as the pose to return to, then shows the
  warp-out's end pose at once: `warp_fov`, `scale.z × stretch`,
  `position.z − warp_distance` and fade 1. `playing` and `playing_in`
  become true.
- While playing in, `advance(delta)` shows the warp-out's pose at
  `t = 1 − elapsed ÷ warp_duration`, so at any moment it mirrors the warp
  out and every value only moves towards the recorded pose.
- Post-condition at the end: every value is back at the recorded pose
  (fade 0), `playing` and `playing_in` are false, and `finished` has been
  emitted exactly once.
- `play_in_on_ready` (exported, off; on in the level): plays in from
  `_ready`, after the player has applied its growth.

### DeviceTracker (`scripts/input/device_tracker.gd`, autoload `InputDevice`)
- `enum Device { KEYBOARD_MOUSE, CONTROLLER }`, moved from
  `PlayerInputComponent`. The project has one tracker, the `InputDevice`
  autoload; tests make their own.
- `device` starts as `KEYBOARD_MOUSE` and is set from every input event
  (`_input`), while the game runs, is paused or is in the shop
  (`PROCESS_MODE_ALWAYS`):
  - a key, mouse button or mouse motion sets `KEYBOARD_MOUSE`
  - a pad button, or a stick or trigger past `switch_deadzone` (exported,
    0.2, in [0, 1]; a bad value is reported and ignored), sets
    `CONTROLLER`, so stick drift can't flip it
  - any other event leaves it alone
- `device_changed(device)` is emitted once for each actual change.
- `is_controller()` is `device == CONTROLLER`.

### InputIconSet (`scripts/input/input_icon_set.gd`)
- A Resource naming one look of icons: `controller_folder` and
  `keyboard_folder`, `buttons` (pad button index →
  icon name), `left_stick` / `right_stick` (name prefixes, `l` / `r`) and
  `left_trigger` / `right_trigger` (`lt` / `rt`). The game's set,
  `resources/ui/input_icon_set.tres`, is Xbox default (coloured A/B/X/Y)
  and the dark keyboard and mouse.
- `path(name, device)` is `name.png` in the device's folder.

### InputIcons (`scripts/input/input_icons.gd`)
- Static. `names(actions, device, icon_set)`: for each action in order
  (unknown actions are skipped), the icon name of each of its bindings
  for that device, without repeats:
  - keys by `key_name` of the physical keycode (or the keycode); mouse
    buttons `mouse_left`, `mouse_right`, `mouse_middle`,
    `mouse_scroll_up`, `mouse_scroll_down`
  - pad buttons from `icon_set.buttons`; stick motion
    `<stick>_up/down/left/right` by axis and sign; triggers by the set's
    trigger names
  - then merged: the four d-pad directions → `dpad`; a stick's four →
    `<stick>_2d`, up and down → `<stick>_y`, left and right →
    `<stick>_x`; wheel up and down → `mouse_scroll`. A merged icon takes
    the place of the first of its set. The arrow keys are dropped when
    other icons remain.
- `paths(actions, device, icon_set)` is `icon_set.path` of each name.
- `merge(names, icon_set)` applies just the merges (and the arrow rule) to
  a list of names; `names` uses it.
- `key_name(code)`: letters and digits as themselves (lower case), F-keys
  `f1`…`f12`, and the pack's names for the rest (`shift`, `space`, `esc`,
  `ctrl`, `alt`, `tab`, `enter`, `backspace`, `capslock`, `up`/`down`/
  `left`/`right`, `comma`, `period`, `slash`, `semicolon`, `quotation`,
  `brackets_l`/`brackets_r`, `tilde`, `minus`, `plus`).
- `texture(path, crop := false)`: the icon with mipmaps, or null if there
  is no such file. Whole, it keeps the pack's 128 px canvas, so every icon
  has one scale; cropped, it is cut to its visible pixels (for a key cap
  that must fill its key). Each (path, crop) is loaded once and cached.

### InputPrompt (`scripts/ui/input_prompt.gd`)
- An `HBoxContainer`: the icons for `actions` on the active device, then
  a label with `text` (no label when the text is empty). Exports:
  `actions`, `text`, `icon_size` (> 0, 32), `icon_set` (default the
  game's), `keyboard_fallback` and `controller_fallback` (an icon name to
  show when that device has no binding, e.g. `mouse_xy` for mouse look),
  and `label_type` (the label's theme type variation). Bad values are
  reported and ignored.
- `devices` defaults to `InputDevice` on entering the tree. Whenever its
  device changes, or any export changes once ready, the row is rebuilt:
  one whole-canvas icon per `InputIcons.paths`, each `icon_size` square,
  then the label. A missing icon file shows its name as text instead.
- `icon_paths()` is what it shows now. It never handles input and ignores
  the mouse.

### Holo theme (`resources/ui/holo_theme.tres`)
- The HUD's look as one Theme: the mono font, a `HoloPanel` glass panel
  with a thin cyan border, and label variations `HoloTitle` (magenta),
  `HoloText` (cyan), `HoloGold` and `HoloMagenta`.

### ControlLabels (`scripts/ui/control_labels.gd`)
- A Resource with parallel arrays: `actions`, `labels` (shown beside a
  controller line or in a list, e.g. `Pitch down`), `short_labels` (on a
  key cap, e.g. `Pitch ↓`) and `axis_labels` (for a stick axis, e.g.
  `Pitch`), plus `keyboard_extra_icons` / `keyboard_extra_labels` for
  controls with no binding (mouse look). The game's is
  `resources/ui/control_labels.tres`.
- `require_valid()` reports and returns false unless each pair of
  parallel arrays is the same length.
- `index_of(action)` is the action's row, or −1.

### ControllerLayout (`scripts/ui/controller_layout.gd`)
- A Resource for `controller_layout.svg`: `picture`, the line colour to
  swap (`line_colour` → `shown_line_colour`), and per slot (parallel
  arrays) `slot_names`, `slot_on_right`, `slot_heights` (the line's end,
  as a share of the picture's height) and `slot_lines` (the SVG ids of its
  line and hook). `button_slots` and `axis_slots` say which slot a pad
  button or axis belongs to. `require_valid()` checks the arrays match
  and every height is in [0, 1].
- `entries(labels, icon_set)`: slot name → `[[icon name, text], …]` in
  `labels` order. A button or trigger gives its icon and label. A stick's
  axes are grouped by axis label and merged (`InputIcons.merge`), so
  pitch on Y and yaw on X are `[l_y] Pitch`, `[l_x] Yaw`, and look on
  both axes is `[r_2d] Look`. Repeats are dropped.
- `unused_lines(used)`: the line ids of every slot not in `used`.

### KeyboardLayout (`scripts/ui/keyboard_layout.gd`)
- A Resource for `keyboard_layout.svg`: `picture`, the outline colour to
  swap, and parallel `key_codes` and `key_rects` (x, y, width, height as
  shares of the picture). A key code listed twice (Shift) uses its first
  rectangle. `require_valid()` checks the arrays match and every
  rectangle is inside the picture.
- `rect_of(code)` is its first rectangle (empty if it isn't drawn), and
  `has_key(code)` whether it is.
- `captions(labels)`: key code → the short labels of every action bound
  to it, for keys on the picture, in `labels` order.
- `extras(labels, icon_set)`: `[[icon name, label], …]` for keyboard and
  mouse bindings not on the picture (Esc, mouse buttons), then the
  labels' keyboard extras (mouse look).

### ControlsView (`scripts/ui/controls_view.gd`)
- A `Control` drawing the active device's controls. Exports the two
  layouts, the labels and the icon set (the game's by default), and the
  tuned sizes: `controller_width` 420, `label_column` 220,
  `controller_icon_size` 36, `keyboard_width` 860, `key_icon_share` 0.6,
  `key_caption_size` 11, `legend_icon_size` 36, `view_size` 860 × 356 and
  `svg_oversample` 2. `devices` defaults to `InputDevice`.
- It builds when it's ready if it's shown, and rebuilds whenever the
  device changes while it's shown. While hidden it only notes the change
  and rebuilds when it's next shown (perf review, option A), so a device
  switch in flight doesn't rebuild the hidden pause menu. Its minimum
  size is `view_size` (or the content, if bigger), centring the content
  in it, so the panel around it doesn't jump between devices.
- Controller: the picture (`controller_svg`: the layout's SVG with the
  line colour swapped and the lines of slots without entries removed) is
  `controller_width` wide, `label_column` in. Each slot with entries gets
  a row `Slot_<name>`, centred on its line's height: on the left it ends
  just before the picture, on the right it starts just after it. A row is
  each entry's whole-canvas icon then its label.
- Keyboard: the picture (outline colour swapped) is `keyboard_width`
  wide. Each key with captions gets `Key_<code>`, exactly over its
  rectangle: a lit panel holding its cropped key cap and the captions
  joined by " / ". Underneath, `Legend` lists the layout's extras as
  icon and label.
- The SVGs are read as files, so an exported build must include `*.svg`
  as non-resource files. It ignores the mouse.

### PauseController (changed, see [pause](08_pause.md))
- `restart()`: unpauses, emits `restarting`, then reloads the current
  scene unless `reload_on_restart` (exported, on) is off. The `restart`
  action calls it, paused or not.

### PauseMenu (`scripts/ui/pause_menu.gd`, `scenes/ui/pause_menu.tscn`)
- Replaces `PauseOverlay`. A CanvasLayer (layer 20) that runs while
  paused, in the holo theme. It requires `pause_controller`.
- Hidden until `paused_changed(true)`, hidden again on `false`. Shown, it
  dims the game and holds `// PAUSED`, a panel with a header naming the
  active device (`// CONTROLS : KEYBOARD & MOUSE` or
  `// CONTROLS : CONTROLLER`) over a `ControlsView`, and RESUME,
  RESTART and QUIT buttons. RESUME has focus each time it opens.
- RESUME unpauses. RESTART calls `pause_controller.restart()`. QUIT emits
  `quit_requested`, then quits unless `quit_on_request` (exported, on) is
  off. Pad B, while it's shown, resumes and is marked handled.
- `devices` defaults to `InputDevice` and is passed to its view.

### ButtonPromptIcon (`scripts/ui/button_prompt_icon.gd`)
- A Node that keeps a `button`'s icon on the first icon of `actions` for
  the active device (`InputIcons.paths`, whole canvas), and clears it
  when there is none. Exports `button` (required), `actions` and
  `icon_set`. `devices` defaults to `InputDevice`. It updates when ready
  and whenever the device changes.

### ShopOverlay (changed, see [skill tree](15_skill_tree.md))
- The hints `Move`, `Buy` and `Zoom` are `InputPrompt`s:
  `ui_up, ui_left, ui_down, ui_right` → `MOVE`, `ui_accept` → `BUY`,
  `shop_zoom_out, shop_zoom_in` → `ZOOM`, at 26 px in the `HoloHint` look
  (cyan at 0.6, 18 pt). WARP IN reads ` WARP IN >>` and a
  `ButtonPromptIcon` gives it the `warp_out` icon (at most 26 px wide).

### LoseOverlay (changed, see [lose flow](09_lose_flow.md))
- Still shown only after losing. The scene is in the holo theme: a dim,
  magenta-scanlined backdrop (ignoring the mouse) and a magenta-bordered
  `HoloAlertPanel` holding `// CRASHED`, `HULL BREACH: YOU HIT SOMETHING
  HEAVIER` and an `InputPrompt` for `restart` (`RESTART`, 44 px icons)
  pulsed by a `PulseEffect`.

### WarpPrompt (`scripts/ui/warp_prompt.gd`, `scenes/ui/warp_prompt.tscn`)
- A CanvasLayer (layer 12) at the bottom centre of the screen. It requires
  `warp_controller`.
- Each frame (`refresh()`), it is visible exactly while
  `warp_controller.can_warp()`: the quota is met and the run isn't
  crashed, warping or warping in (so never in the shop).
- It shows a magenta `HoloCallout` panel with `QUOTA MET` over an
  `InputPrompt` for `warp_out` (`WARP OUT >>`, 40 px), and a
  `PulseEffect` pulses the panel. It ignores the mouse.

### ShopGuide (`scripts/ui/shop_guide.gd`)
- A node in the shop scene that runs while the shop is open (the tree is
  paused). It requires `shop`, and exports the scene parts it drives: the
  `buy_tag` (an `InputPrompt` for `ui_accept`, `BUY`, over a `▼`), the
  `buy_hint`, the `warp_arrow` (a `▼` on WARP IN) and their effects
  (`buy_tag_bounce`, `buy_hint_pulse`, `warp_pulse`, `warp_arrow_bounce`),
  plus `show_buy_tag` and `show_warp_in` (both on).
- `refresh()` (each frame):
  - `buy_target()` is the first view whose node can be bought, but only
    while the shop is open and nothing has ever been bought (every count
    in `progression.buys_by_id()` is 0); otherwise null. With a target,
    the tag is a child of that view, centred just above it and bouncing,
    and the BUY hint pulses. Without one, the tag is hidden and both
    effects are off.
  - `is_highlighting_warp_in()` is true while the shop is open and no
    node can be bought. Then WARP IN pulses and its arrow shows, centred
    above it, bouncing. Otherwise the arrow is hidden and both are off.
- An effect is only switched when its state changes, so its time isn't
  reset every frame. The tag and arrow ignore the mouse.

### TutorialProgress (`scripts/progression/tutorial_progress.gd`)
- A RefCounted on `RunProgress` (`RunProgress.tutorial`), so it lasts the
  session through restarts and the shop. Nothing is saved to disk.
- `enum Part { CONTROLS, OBJECTIVE, NONE }`. `next_part()` is `CONTROLS`
  until the controls are done, then `OBJECTIVE` until the objective is
  done, then `NONE`.
- `finish(part)` requires `CONTROLS` or `OBJECTIVE` and marks it done;
  finishing it again changes nothing. `is_done(part)` reports it (`NONE`
  is never done). `reset()` marks both not done.

### TrainingStep (`scripts/tutorial/training_step.gd`)
- A Resource: `title`, `hint`, `actions` (any of them counts),
  `keyboard_fallback` (an icon to show when the keyboard has no binding)
  and `counts_mouse_motion` (mouse movement fills it too, for look).

### FlightTraining (`scripts/tutorial/flight_training.gd`)
- A Node that teaches `steps` in order. Exports `steps`, `hold_time`
  (> 0, 0.7 s), `input_threshold` (in (0, 1], 0.3), `mouse_distance`
  (> 0, 600 px) and `step_gap` (≥ 0, 0.6 s). Bad values are reported and
  ignored. It pauses with the game.
- `start()` requires at least one step. Afterwards `running`, `index` 0,
  `progress` 0, and `step_started(0)` has been emitted.
- `advance(delta)` (each frame) while running:
  - outside a gap, if the strongest of the step's actions is at least
    `input_threshold`, `progress` rises by `delta ÷ hold_time`. At 1 it
    stays at 1, `step_completed(index)` is emitted once and a gap of
    `step_gap` starts.
  - once the gap is over, the next step starts (`index + 1`, progress 0,
    `step_started`), or after the last step `running` becomes false and
    `finished` is emitted once.
- `add_mouse_motion(relative)` adds `|relative| ÷ mouse_distance` to a
  step that counts mouse motion, outside a gap (the node feeds it from
  captured mouse motion). Other steps ignore it.
- `current_step()` is the step being taught, or null when not running.
- Invariant: `0 ≤ progress ≤ 1`.

### TargetMarker (`scripts/ui/target_marker.gd`)
- A full-screen `Control` that marks a 3D point. Exports `colour`
  (magenta), `margin` (≥ 0, 70 px), `diamond_size` (26), `arrow_size`
  (26), `font_size` (16) and `pulse_hz` (1.4). `target`, `has_target` and
  `text` (a caption, e.g. the distance) are set by its owner. It ignores
  the mouse.
- `place(camera)` (each frame, with the viewport's camera): without a
  target or camera nothing is drawn. Otherwise, with the safe area being
  the camera's viewport inset by `margin`:
  - `on_screen` if the point is in front of the camera and projects
    inside the safe area. Then `marker_position` is its projection and a
    pulsing diamond with the caption below is drawn there.
  - otherwise `pointing` is the direction from the screen centre to the
    projection (reversed when the point is behind the camera, up if it's
    dead centre), `marker_position` is where that ray leaves the safe
    area, and an arrow pointing that way is drawn there with the caption
    just inside it.

### TutorialOverlay (`scripts/ui/tutorial_overlay.gd`, `scenes/ui/tutorial_overlay.tscn`)
- A CanvasLayer (layer 11) in the level, in the holo theme. It requires
  `player`, `streamer`, `lose_controller` and `warp_controller`; the
  `warp_effect` and `cargo_panel` are optional. Exports
  `objective_linger` (≥ 0, 3 s), `arrived_distance` (≥ 0, 150) and
  `every_run` (off; on resets the session's tutorial first). `tutorial`
  defaults to `RunProgress.tutorial`. Its `FlightTraining` child holds the
  course: PITCH, YAW, ROLL, LOOK (mouse motion counts, `mouse_xy` on the
  keyboard) and BOOST.
- `phase` is `WAITING` until the warp in has finished (at once without
  one playing), then `begin()` follows `tutorial.next_part()`:
  - `CONTROLS`: the training starts. Each step shows
    `// FLIGHT TRAINING n/N`, an `InputPrompt` of its actions titled with
    its title, its hint in capitals and a bar of its progress; a
    completed step shows `NICE!`. When the training finishes, the
    controls are marked done and the objective starts.
  - `OBJECTIVE`: `// OBJECTIVE`, `MINE YOUR QUOTA`, `FLY INTO BODIES
    SMALLER THAN YOU TO FILL YOUR TANKS`. While mining, the
    `TargetMarker` marks the nearest root child (captioned `PLANET nm`,
    the distance to its surface) unless the ship is within
    `arrived_distance` of that surface, and an arrow points at the
    `cargo_panel` (`YOUR QUOTA`). After the first pickup (cargo above 0):
    `NICE! KEEP MINING` / `FILL EVERY TANK, THEN WARP OUT`, both markers
    off, and after `objective_linger` the objective is marked done.
  - `NONE` or afterwards: `DONE`, nothing shown.
- The panel and markers fade in while the phase is `CONTROLS` or
  `OBJECTIVE` and the run isn't crashed or warping, and fade out
  otherwise. It ignores the mouse and pauses with the game.

### PulseEffect (`scripts/effects/pulse_effect.gd`)
- Brightens a `target` CanvasItem in a pulse. Exports `target`, `hz`
  (> 0, 1.4), `brightness` (≥ 1, 1.5) and `active` (on). Bad values are
  reported and ignored.
- `level()` is `0.5 − 0.5 cos(2π × hz × time)`: 0 when it starts, 1 half a
  period in, back to 0 each period. While active, `advance(delta)` (each
  frame, pausing with its owner) sets the target's modulate to
  `lerp(1, brightness, level)` in red, green and blue, keeping its alpha.
- Turning it off resets the time and sets the target's colour back to
  white, keeping its alpha. Without a target it only keeps time.

### BounceEffect (`scripts/effects/bounce_effect.gd`)
- Bobs a `target` Control. Exports `target`, `hz` (> 0, 1.4), `distance`
  (≥ 0, 8 px), `direction` (non-zero, normalised, up) and `active` (on).
  Bad values are reported and ignored.
- `offset()` is `direction × distance × |sin(π × hz × time)|`: none when
  it starts, `distance` half a period in. While active, `advance(delta)`
  puts the target at `base_position + offset()`. The owner sets
  `base_position` when it lays the target out.
- Turning it off resets the time and puts the target back at
  `base_position`.

### PlayerInputComponent (changed, see [controls](05_controls.md))
- `active_device`, `device_changed`, `device_switch_deadzone` and the
  `Device` enum are gone: `InputDevice` tracks the device for everyone.

### DebugOverlay (changed, see [controls](05_controls.md))
- `devices` (a `DeviceTracker`) defaults to `InputDevice` on entering the
  tree. The `Input` line shows its device (`Keyboard/Mouse` or
  `Controller`).

### WarpController (changed, see [game loop](12_game_loop.md))
- `can_warp()` is also false while `warp_effect` is playing, so a run
  can't warp out before it has finished warping in. Without an effect
  nothing changes.
## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done.

### 5.23 Ship size and thrust ✅
- `player.tscn`: the `Mesh` node ×1.3 and the collider's radius ×1.3.
- `blue_thrust.tscn`: 90 particles, 0.8 s lifetime, inherit velocity
  ratio 1.
- **Done:** a test checks the player scene's mesh scale and collider
  radius, and the thrust's amount, lifetime and inherited velocity.

### 5.24 Spawn faces the nearest planet ✅
- `PlayerSpawn.face_nearest_planet` (on): after placing the player, it
  faces the nearest root child, keeping the ring normal as up.
- **Done:** `tests/levels/test_player_spawn.gd` checks the facing, that
  off keeps the prograde facing, and that up stays the ring normal.

### 5.25 Ring jitter ✅
- `Tier.jitter` (0–1, default 1). `TierGenerator` places each child
  anywhere in its cell that keeps `max(radius, min_separation ÷ 2)` inside
  it, scaled by `jitter`. The rings tier's `min_separation` drops to 0, and
  "min_separation ≥ 2 × radius_max" becomes "2 × radius_max ≤
  cell_size".
- **Done:** `tests/generation/test_tier_generator.gd` checks that
  siblings never overlap and are at least `min_separation` apart, that
  jitter 0 centres each child in its cell, and that jitter 1 uses the
  whole room; `test_tier.gd` checks the new rule.

### 5.26 Live bodies match their proxies ✅
- `MassBody.surface_frame`: the rotation its surface is drawn in.
  `LiveBodyPool` sets it to the ring's frame when it promotes a body.
- `OrbitRenderer`'s proxy sphere has the live sphere's tessellation.
- **Done:** tests check a promoted body's mesh frame equals its
  renderer's, and the proxy's segments and rings equal the unit sphere's.

### 5.27 Rings grow in ✅
- `OrbitRenderer.display_scale`: draws every instance at that share of its
  size, without changing `child_positions`.
- `GrowInEffect` (`scripts/effects/grow_in_effect.gd`): eases each newly
  expanded renderer's `display_scale` from 0 to 1 (0.6 s, ease 2).
- **Done:** `test_orbit_renderer.gd` and `tests/effects/test_grow_in_effect.gd`
  pass (instance scales follow the display scale, positions don't move,
  the grow ends at exactly 1).

### 5.28 Warp in ✅
- `WarpEffect.play_in()`: the warp-out pose played backwards, emitting
  `finished` when the ship is back in place. The level plays it at the
  start of every run.
- **Done:** `tests/effects/test_warp_effect.gd` checks the warp in starts
  at the warp-out's end pose and ends at the start pose.

### 5.29 Active input device ✅
- `InputDevice` autoload (`scripts/input/input_device.gd`): `device` and
  `device_changed`, running while paused. `PlayerInputComponent` loses its
  own tracking; the debug overlay reads the autoload.
- **Done:** `tests/input/test_device_tracker.gd` passes (the rules moved
  from the player input component's tests), and the debug overlay's test.

### 5.30 Input icons ✅
- `InputIconSet` resource (the controller and keyboard icon folders) and
  `InputIcons` (`scripts/input/input_icons.gd`): the icons for a list of
  actions on a device, with the merges.
- **Done:** `tests/input/test_input_icons.gd` checks each binding kind's
  icon, every merge, that arrows drop beside WASD, and uniform vs cropped
  textures.

### 5.31 Input prompt ✅
- `InputPrompt` (`scripts/ui/input_prompt.gd`): a row of icons and text
  for a list of actions that follows `InputDevice`. The holo look as a
  shared theme, `resources/ui/holo_theme.tres`.
- **Done:** `tests/ui/test_input_prompt.gd` checks the icons for each
  device and that it rebuilds when the device changes.

### 5.32 Pulse and bounce effects ✅
- `PulseEffect` and `BounceEffect` (`scripts/effects/`): brighten a canvas
  item at a rate, and bob it by a distance.
- **Done:** their tests check the period, range and reset when stopped.

### 5.33 Controls layouts ✅
- `ControllerLayout` and `KeyboardLayout` resources (`scripts/ui/`), and
  their `.tres` for the two SVGs: leader-line slots and their SVG ids, key
  rectangles, and which bindings go where.
- **Done:** their tests check the slot and key mapping from the input map
  and the stick grouping.

### 5.34 Controls view ✅
- `ControlsView` (`scripts/ui/controls_view.gd`): the active device's
  picture, with labelled leader lines (unbound ones removed) or lit keys,
  at one size for both.
- **Done:** `tests/ui/test_controls_view.gd` checks each device's labels
  and the switch.

### 5.35 Pause menu ✅
- `PauseMenu` (`scenes/ui/pause_menu.tscn`) replaces `PauseOverlay`:
  title, controls view, RESUME / RESTART / QUIT, B resumes.
  `PauseController.restart()` is split out of its input handling.
- **Done:** `tests/ui/test_pause_menu.gd` and `test_pause_controller.gd`
  pass.

### 5.36 Shop hint prompts ✅
- The shop's hint labels become `InputPrompt`s, and WARP IN shows the
  `warp_out` icon.
- **Done:** `test_shop_overlay.gd` checks the hint prompts' actions.

### 5.37 Holo crash screen ✅
- `LoseOverlay` rebuilt in the holo look, with a pulsing restart prompt.
- **Done:** `test_lose_overlay.gd` passes.

### 5.38 Warp out prompt ✅
- `WarpPrompt` (`scenes/ui/warp_prompt.tscn`): shown while
  `WarpController.can_warp()`, pulsing.
- **Done:** `tests/ui/test_warp_prompt.gd` checks when it shows.

### 5.39 Shop guide ✅
- `ShopGuide` (`scripts/ui/shop_guide.gd`): the BUY tag over the first
  buyable node until anything's bought, and WARP IN highlighted while
  nothing can be bought.
- **Done:** `tests/ui/test_shop_guide.gd` checks both rules.

### 5.40 Tutorial progress ✅
- `TutorialProgress` on `RunProgress`: which parts are done this session.
- **Done:** its test passes.

### 5.41 Flight training ✅
- `TrainingStep` resource (title, hint, actions, mouse) and
  `FlightTraining` (`scripts/tutorial/flight_training.gd`): the steps in
  order, each done once held long enough.
- **Done:** `tests/tutorial/test_flight_training.gd` checks the hold, the
  mouse distance, the gap and the order.

### 5.42 Target marker ✅
- `TargetMarker` (`scripts/ui/target_marker.gd`): a diamond on a 3D point
  on screen, or an arrow at the screen edge towards it.
- **Done:** `tests/ui/test_target_marker.gd` checks on screen, off screen
  and behind the camera.

### 5.43 Tutorial overlay ✅
- `TutorialOverlay` (`scenes/ui/tutorial_overlay.tscn`): training, then
  the objective with the planet marker and the cargo arrow, once per
  session.
- **Done:** `tests/ui/test_tutorial_overlay.gd` checks the phases and the
  session rule.

## Performance evaluation
The load measured, the budget, and each option weighed:

**Load** (agreed 2026-11-24): the generated level, seed 12345, the
tutorial on its objective (planet marker up). The ship flies 20 units a
frame along the systems' orbit for 600 frames (after 30 to warm up), so
11 rings stream in and grow. Then 20 device switches, then 300 frames of
the shop open with a full bank (the BUY tag guiding).
`benchmarks/pre_juice_polish/bench.gd` (keys `contracts=0|1`, `grow`,
`menu`, and `gpu=1` for a windowed GPU run).

**Budget** (agreed): the feature's own work in flight ≤ 0.5 ms a frame
(mean: grow-in, tutorial overlay and marker, warp prompt, pulses); a
ring streaming in (the streamer's update, with the jittered generation
and the upload) ≤ 4 ms as a one-frame spike; a device switch ≤ 16 ms;
the shop guide ≤ 0.2 ms a frame. The far bodies' GPU cost is measured
in a window by the user.

**Baseline**, mean / p95 / worst in ms:

| Measure | Contracts off | Contracts on | Budget |
| ------- | ------------- | ------------ | ------ |
| feature's frame in flight | 0.18 / 0.41 / 1.06 | 0.18 / 0.42 / 1.01 | 0.5 ✅ |
| streamer update | 0.84 / 1.04 / 3.50 | 0.86 / 1.03 / 4.31 | 4 spike ✅ off |
| device switch | 6.9 / 10.2 / 10.5 (first 11.5) | 7.2 / 10.8 / 10.9 | 16 ✅ |
| shop guide | 0.019 / 0.019 / 0.19 | 0.019 / 0.024 / 0.19 | 0.2 ✅ |

Experiments (contracts off):
- Without the grow-in (`grow=0`) the feature's frame is 0.13 / 0.14 /
  0.42: the grow-in costs about 0.05 ms on average and up to ~0.6 ms on
  the frame a ring starts growing.
- Without the pause menu (`menu=0`) a device switch is 1.1 / 1.3 / 1.3
  (first 2.9): the hidden pause menu's controls view rebuilding is about
  85% of every switch, and a switch can happen mid-flight.
- Headless has no GPU, so the far bodies' 64 × 32 spheres (2,145
  vertices each, against 91 at 12 × 6) are measured in a window.

**GPU** (the user's machine, windowed, `gpu=1`, the spawn view of the
home ring and planet; GPU render time of the whole frame, mean / p95 /
worst in ms):

| Far-body segments | GPU frame | Primitives drawn |
| ----------------- | --------- | ---------------- |
| 12 (before the feature) | 1.01 / 1.03 / 1.28 | 2.3 M |
| 32 | 4.49 / 6.10 / 6.22 | 14.2 M |
| 64 (the feature) | 5.29 / 6.04 / 6.05 | 54.9 M |

About 13,000 bodies are drawn across the expanded rings, but only the
ring the ship is near can show a body going live, so most of the 64 ×
32 detail is spent where no pop can be seen.

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |
| A. The controls view rebuilds only when shown | device switch 6.9 / 10.2 / 10.5 | 1.08 / 1.32 / 1.34 (first 2.8); the one rebuild (~6–9) moves to pausing after a switch, while paused | A stale flag and a visibility hook; the `ControlsView` contract notes it; existing tests unchanged, `test_controls_view_hidden.gd` added | Taken (user, 2026-11-24) |
| B. The grow-in on the GPU (a scale uniform in the far-body shader) | grow-in ≈ 0.05 mean, ~0.6 on a ring's first frame | ≈ 0 | Ties the effect to the far-body shader; the drawn size can't be read headless, so `drawn_radius` and its tests lose their check; a contract change | Not taken: within budget |
| C. Planets' far bodies at 12 segments, rings at 64 (a `proxy_segments` per tier) | GPU 5.4–6.0 mean; 53.4 M triangles | GPU 3.0–3.6 mean; 12.9 M triangles | Each tier sets its far-body detail (more tunable); `OrbitRenderer`'s contract says so; a planet may change shape slightly when it goes live at 3,000 units (~20 px across) | Deferred by the user: a performance consideration (below) |
| D. C, plus only the near ring at 64 | as C | GPU 3.9–5.0; 10.9 M | A per-frame distance switch and a second mesh per ring | Not taken: no measurable gain over C |
| E. C, with rings at 32 | as C | GPU 3.1 (one run); 5.1 M | The live ring bodies would need their own 32 × 16 sphere: a `MassBody` contract change | Not taken: no measurable gain over C |

**GPU, measured inside the home ring** (`spot=1 detail=100`, three runs,
mean GPU frame in ms): everything at 12: 1.02 / 1.04 / 1.04 (2.8 M
triangles); everything at 64: 5.38 / 6.05 / 6.05 (53.4 M); planets 12,
rings 64: 2.99 / 3.59 / 3.29 (12.9 M); planets 12, near ring only 64:
4.38 / 3.94 / 5.05 (10.9 M); planets 12, rings 32: 3.11 (5.1 M). The
p95 sits at 5–6 ms for every layout but all-12, so the timing is noisy;
the triangle counts are exact. The 12-segment spheres the far planets
used before were about 40 M of the 53 M triangles.

**Final figures** (contracts off, with A): the feature's frame in flight
0.18 / 0.41 / 0.86; streamer update 0.85 / 1.35 / 3.58; device switch
1.08 / 1.32 / 1.34 (first 2.8); shop guide 0.019 / 0.019 / 0.19. All
within budget. The GPU cost of the far bodies is ~5.4–6.0 ms a frame
on the user's machine (+4.4–5 ms over before the feature), within 16.6
ms there.

**Performance consideration** (the user's call, 2026-11-24: noted, not
acted on now): the far bodies draw ~53 M triangles a frame because every
expanded ring and every far planet uses the live sphere's 64 × 32 detail.
On a weaker GPU this is the first thing to cut. Option C (far planets at
12 segments through a per-tier `proxy_segments`) measured about 2.5 ms
and 40 M triangles back on the user's machine, at the risk of a slight
shape change as a planet goes live at 3,000 units. The bench's GPU mode
(`gpu=1 spot=1`) re-measures it.

**Follow-up agreed before `done`**: the thrust plume fix noted under
edge cases (inherit `e^(−drag × lifetime)` of the ship's velocity),
made as a separate production change after this feature is done.
