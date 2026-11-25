# game_feel
Started 2026-11-25. The live phase is in `.claude/bin/feature status`.

## Idea
In the user's words: "We're going to juice things up so this prototype will
contain a few different elements before rewriting them all into the game.

- The camera isn't very reactive to player movement. I want some where I can
  see the ship turn and the camera is a bit delayed in making that work. Also
  when moving left and right the ship should tilt with the turn and then tilt
  back after the turn has finished.
- When using the booster the ship should pull ahead to some point and then
  move back. Using the thruster for longer and with a stronger boost should
  exaggerate this movement.
- I want particles flying past the ship as it moved, being stronger as you
  move faster. Using the boost should slightly blur the area around the ship
- Add controller shake that scales with ship speed up to a maximum and on
  ship death (explosion effect).
- The thrustfx should always be playing but be scaled based on ship engine
  speed (ie if you use the booster it runs harder)"

## Prototype log
One line per iteration: what changed and what the user said about it.

- v1: camera lag (slerp follow), yaw bank on the mesh, boost pull (camera
  spring back), speed lines and rumble by speed, radial boost blur, thrust
  FX always on and spooled by boost. User tuned follow 2 / boost follow 4,
  bank 75 per rad/s up to 50°, idle engine 0, and asked: "Instead of the
  rumble and particle going with speed make it go with accelleration".
- v2: lines and rumble driven by measured acceleration (smoothed). User:
  "The controller vibration doesn't go to zero after boost" (arcade
  steering, drag and gravity keep the measured value up).
- v3: rumble follows engine-only thrust acceleration, so it stops with the
  boost. User: "Now add controller vibration on pickup (a satisfying single
  rumble)".
- v4: pickup rumble, a short punchy hit on both motors as a pickup lands.
  User: "Add controller vibration for warping in/out".
- v5: warp rumble follows the warp curve (builds to the jump, settles on
  arrival). User: "Add the blur and line effect to the warp."
- v6: blur and lines follow the warp curve (lines along the nose up to 600
  u/s, 4x stretch). User: "I want the line effect to always be present but
  as v short particles moving lazily along".
- v7: always-on ambient motes (long-lived, short, lazy drift along travel).
  User asked for bank and blur settings explained, then: "Give me full
  unlockable stats (endgame build)" and "turn off tutorial".
- v8: EndgameBuild node maxes the whole skill tree (level 40) and marks the
  tutorial finished before the level starts. User asked for more juice ideas
  (suggest only), then: lines on boost only (keep the ambient motes), try
  FOV kick, camera roll, squash and stretch on absorbed bodies (not the
  ship), no thrust FX during warps, remove "ORBIT" from the minimap,
  hit-stop, camera shake on death and warps, shop purchase punch and unlock
  reveal, and an endgame build toggle.
- v9: all of the above. Lines follow engine thrust acceleration; F2 flips
  the endgame build and restarts. User: add chromatic aberration on warp;
  "the particles aren't there when you're moving quickly"; crash should go
  into slow motion, show the explosion, then the pop-up; drop the node
  scale on purchase and scale the slot square instead (keep the rest).
- v10: warp aberration in the blur shader; ambient motes replaced with a
  wrapping space-dust particle shader (constant density at any speed);
  lose pop-up held back until hit-stop + slow motion + 0.2s; purchase pops
  the newly filled slot square instead of the node. User: "On crash I want
  the ship to bounce of the planet in slow motion as part of the crash";
  add a title screen with Start, Options and Exit over an overview of the
  live scene at 10x speed, with the central planet's centre on the
  bottom-left third intersection.
- v11: crash bounce (reflect off the planet's normal, restitution 0.5,
  tumble, plays in the slow motion); title screen overlay with Start,
  Options (endgame build, vibration, invert pitch) and Exit. User: "Switch
  the sides in the title screen so the options are on the left and instead
  of having a small planet centred have the biggest planet".
- v12: menu on the left, planet on the bottom-right third. All top planets
  share radius 50 (systems tier), so "biggest" ties; it picks the one
  nearest the spawn and frames it closer (3 radii, was 9) so it fills more
  of the screen. User: "No there is the top tier planet (in this setting there
  are 3 tiers, with the parent being the biggest. Zoom out so that one is
  shown."
- v13: title frames the hierarchy's root body (streamer root, radius 5000)
  from 4 radii out. User: "That's much better, zoom in like 1.5x and
  increase system period by 10x".
- v14: title camera 2.67 radii out (1.5x closer); orbits at 100x speed. User: "The title screen will need to be deterministic
  so let me choose the seed".
- v15: `title_seed` export (default 1) sets the streamer seed for the title;
  every run prints its seed so a good one can be reused. User: "That default
  seed is perfect." Then: move the new title logo png somewhere appropriate
  and use it instead of the "HEAVY SPACE" text.
- v16: logo moved to `resources/ui/title_logo.png` (mipmaps on, it's
  4512x3012) and shown 520 px wide in place of the title text. User: "Where
  can I edit the title screen ui? And make all text use orbitron font."
- v17: title menu moved into `prototypes/game_feel/title_menu.tscn` (editable
  in the editor; the script wires buttons by unique name). Orbitron (OFL,
  from Google Fonts) in `prototypes/game_feel/fonts/`; a FontOverride node
  swaps it in at runtime for the holo theme default, the fallback font and
  every per-control font override, weight 500. Copying it into
  `resources/fonts/` was blocked, so the rewrite should move it there.
  User: no bottom text on the thrust reserve and mass tank gauges (e.g.
  "FUL 100%", "MASS 25.0/25"), and change references to mass to cargo.
- v18: both gauge readouts hidden; "MASS TANKS" shows as "CARGO TANKS";
  skill titles renamed in memory ("Cargo Tank +1", "Cargo efficiency
  +15%"). User: "Remove the borders for the thrust and cargo and change the
  text to BOOST and CARGO".
- v19: gauge panel borders removed; titles read "BOOST" and "CARGO". User: "Make the thrust not be cells but
  a solid bar".
- v20: boost gauge draws one solid fill instead of 20 segments. User:
  "Remove the black transparent background from thrust and cargo".
- v21: gauge panels draw no background (bars keep their dark track). User:
  each cargo tank a fixed width, 5 per row (5 tanks = the boost bar's
  width); reduce the padding between boost and cargo.
- v22: cargo tanks drawn at boost-width / 5, wrapping into rows (3 px row
  gap); gauge gap 2 px and the inner padding where they meet removed. User:
  "There's a bar behind cargo when I have less than 5 tanks. I don't want
  that. Only the cargo tank bars".
- v23: cargo gauge's full-width scanline overlay hidden; only the tanks draw.
  User asked whether the crash has slow motion (yes: hit-stop, 0.1x easing
  back over 1s, pop-up 0.3s later), then: "Centre the crash explosion on
  the shop [ship], not the impact location".
- v24: the explosion's particles switch to local coordinates and the blast
  follows the ship's model through the bounce (`explosion_follows_ship`).

## Accepted behaviour
Filled in before acceptance. This is the spec for the rewrite: the behaviours
to keep, the tuned values the user liked, and what was tried and dropped.
From `prototypes/game_feel/` (`game_feel.gd`, `shop_juice.gd`,
`title_screen.gd`, `title_menu.tscn`, `endgame_build.gd`,
`font_override.gd`, `ambient_dust.gdshader`, `radial_blur.gdshader`), v24,
with the values tuned in `main.tscn`. Agreed at the start of the rewrite:
the endgame build is debug builds only and isn't a setting, settings
(vibration, invert pitch) are saved, and the title screen is its own main
scene.

### Keep
- **Shared signals.** Boost is the boost input (0–1), or 0 with no fuel or
  after a crash. Strength is `back_thrust_force × thrust_multiplier ÷ 150`,
  capped at 2 where it scales an effect. Thrust acceleration is the
  engine's own (boost × force × multiplier ÷ mass), smoothed (rate 8), so
  it drops to 0 the moment the boost stops. The warp curve rises 0 → 1
  over a warp out and falls 1 → 0 over a warp in; it's 0 otherwise and
  after a crash.
- **Camera lag:** the camera rig slerps after the ship's rotation, at
  rate 2, rising to 4 with full boost. The look (yaw, pitch) sits on top.
- **Boost pull:** the camera trails behind by up to 0.35 camera distances
  × boost × strength × `ease(ramp, 0.5)`, where the ramp is seconds boosted
  ÷ 1.5 (held to 3× that, draining at 2/s off the boost). A spring
  (stiffness 30, damping 8) moves it, so it overshoots and settles back.
- **Bank:** the mesh rolls by 60° per rad/s of yaw rate, capped at 60°,
  easing at rate 50. The camera rolls with 0.15 of it.
- **FOV kick:** up to 5° wider at boost × strength (to 2×), easing at
  rate 4. Not during warps (the warp owns the FOV).
- **Thrust FX always on**, spooled by the engine level: target
  `max(idle 0, boost × min(strength, 2))`, spooling up at 6 and down at 3.
  Amount ratio 0.05 → 1, velocity ×0.3 → ×1.3, scale ×0.5 → ×1.2. Hidden
  during warps and after a crash.
- **Speed lines** on boost only: thin unshaded lines (alpha up to 0.6)
  from a box 3 camera distances wide, ahead of the ship, streaming past it.
  Driven by thrust acceleration, from 5 (none) to 150 (full): 400 lines,
  0.8 s life, 0.3 of the ship's speed on top of it, length 1.0 camera
  distance × (0.3 + level). In a warp they follow the curve along the nose,
  up to 600 u/s and 4× long.
- **Space dust**, always on: 250 short motes (0.04 camera distances long,
  alpha 0.35) in a box 2.5 camera distances across around the ship that
  wraps round its edges, so the density is the same at any speed. They
  drift lazily (0.15 camera distances/s) against the travel direction
  and fade out near the box's edges (from 0.6) so the wrap doesn't pop.
  Hidden after a crash.
- **Boost blur:** a radial blur centred on the ship on screen, clear
  within 0.05 of it and ramping over 0.35. Strength 2.0 × boost ×
  strength (to 2×), easing at rate 4. In a warp it follows the curve up to
  10, with chromatic aberration up to 1.0 (red out, blue in).
- **Camera shake:** trauma that decays at 1.2/s; the offset is trauma² ×
  0.06 camera distances of noise at frequency 25. A crash adds 2.0; a warp
  holds it at least at 3.0 × the curve. Runs in real time.
- **Rumble** (off when vibration is off), the strongest of:
  - thrust acceleration, from 5 (none) to 150: the light motor up to 0.35.
  - a pickup: light 0.04, heavy 0.07 for 0.1 s, fading as `t^10`.
  - a warp: light 0.6 × curve, heavy 1.0 × curve³.
  - a crash: 1.0 for 0.8 s, the light motor fading linearly and the heavy
    one squared. It replaces the others.
- **Absorb squash and stretch:** a body being sucked in squashes 30% along
  the pull for the first 0.2 of the suck, then stretches to 3× long,
  keeping its volume (across = 1 ÷ √along) and pointing at the ship. Not
  the ship.
- **Crash:** hit-stop for 0.12 real seconds at time scale 0.02, then slow
  motion from 0.01 easing (t²) back to 1 over 2 real seconds. The crash
  pop-up shows 0.3 s after that. The ship bounces off the body's normal
  (restitution 0.5, at least 1.5 camera distances/s out), slowing with drag
  1.2 and tumbling at 360°/s (slowing at half the drag), all in the slow
  motion. The explosion follows the ship through the bounce.
- **Shop juice** (runs while the shop pauses the game):
  - Purchase: a copy of the newly filled slot square pops from 2.5× back
    to its size (0.35 s, elastic) and the node flashes (×2 bright, fading
    over 0.21 s). The bank counts up to its new value over 0.45 s (cubic
    out) while its label settles from 1.15× (back out). Rumble 0.25 light,
    0.45 heavy for 0.12 s.
  - Unlock reveal: newly unlocked nodes light up nearest the bought one
    first, 0.12 s apart, starting halfway through the punch. Each grows
    from 0.6× and alpha 0.15 over 0.4 s (back out), flashing ×2, with a
    tiny rumble (0.09 light, 0.15 heavy, 0.06 s).
- **HUD:** the gauges show only their title and bar, titled BOOST and
  CARGO, with no border or background. Boost is one solid bar. Cargo
  tanks are a fixed width, 5 to a row (a full row is the boost bar's
  width), 3 px between rows and 0.08 of a slot between tanks (at least
  2 px), with no strip behind a part-filled row. The gauges sit 2 px apart
  with no inner padding where they meet. The minimap has no ORBIT title.
  Player-facing "mass" reads "cargo" (the skill tree's "Cargo Tank +1" and
  "Cargo efficiency +15%").
- **Font:** every piece of text in Orbitron (OFL), weight 500.
- **Ship ×2:** the mesh and its collider are twice the base size.
- **Title screen**, the main scene: the live system behind it, seed 1, at
  100× orbit speed, with no player, HUD or gameplay. The camera frames the
  hierarchy's root body from 2.67 radii out, 28° above the orbital plane,
  circling at 1.5°/s, with the body's centre on the bottom-right third
  (2/3, 2/3). The menu is on the left: the logo
  (`resources/ui/title_logo.png`, 520 px wide), then START, OPTIONS and
  EXIT. Options: VIBRATION (a test pulse 0.3/0.5 for 0.15 s when turned
  on) and INVERT PITCH, then BACK (also `ui_cancel`). Start loads the
  level, which warps in as normal. Debug runs print each level's seed.
- **Endgame build**, debug builds only: F2 flips it and restarts the run.
  On, it banks 1e12 and buys every skill until nothing more can be bought,
  and skips the tutorial. Off, progression starts fresh. No on-screen
  label (removed after acceptance, at the user's request).

### Dropped
- Rumble and speed lines following speed (v1), then measured acceleration
  (v2: drag, steering and gravity kept it up after the boost).
- Lines always on (v6), then lazy motes (v7), replaced by the wrapping
  space dust (v10), which stays at any speed.
- Banking from roll input (`bank_from_input` 0).
- Scaling the whole node on purchase (v9), replaced by the slot pop.
- The node-walking runtime font override: the rewrite sets the font in the
  theme.
- Endgame build as an option on the title screen.

## Decision
- 2026-11-25: accepted, moving to the rewrite.

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written.
The user agreed the split and the 17.1 contracts on 2026-11-25, and asked
to go ahead with every step, being told of each new or changed contract.

### Theme and fonts (17.1)
- `resources/fonts/orbitron.ttf` (OFL, `orbitron_OFL.txt`) is the holo
  theme's `default_font`, a `FontVariation` at weight 500. The holo theme
  is the project theme (`gui/theme/custom`), so every control uses it. No
  scene sets its own font.
- The skill tree's player-facing titles say cargo, not mass.

### FuelGauge, CargoGauge, Minimap (changed, 17.1)
- See the 2026-11-25 changes in [HUD and art](13_hud_and_art.md)
  (FuelGauge, Minimap) and [mass tanks](14_mass_tanks.md) (CargoGauge).

### GameSettings (`scripts/core/game_settings.gd`)
- The `Settings` autoload. Player options that last between launches:
  `vibration` (true) and `invert_pitch` (false). Exports `path`
  (`user://settings.cfg`) and `load_on_ready` (true).
- Setting an option to a new value saves the file and emits `changed`
  once; setting it to the value it has does nothing.
- `load_saved()` and `save()` require a `path`. Loading a missing or
  unreadable file, or a key that isn't a bool, keeps the current value;
  loading doesn't save. After `save()`, the file holds every option
  (ensured: the save succeeded).

### SettingsBinder (`scripts/levels/settings_binder.gd`)
- In the level. Export `player_input: PlayerInputComponent`; `settings`
  defaults to the `Settings` autoload (tests give their own).
- On ready it requires both, then applies the settings and again on
  every `changed`. After `apply()`, `player_input.invert_pitch` equals
  `settings.invert_pitch` (ensured).

### RumbleMixer (`scripts/core/rumble_mixer.gd`)
- The `Rumble` autoload, running while paused and in real time (slow
  motion doesn't stretch a rumble). Every effect rumbles through it; it
  alone talks to the pads.
- `pulse(light, heavy, duration, fade_power = 1)` requires motors in
  [0, 1], `duration > 0` and `fade_power > 0`. At age `a` the pulse is
  `motor × (1 − a ÷ duration)^fade_power`; it's gone once `a ≥ duration`.
- `hold(source, light, heavy)` requires motors in [0, 1]: a level that
  stays until changed or `release(source)`. Holding 0 on both releases it.
- `weak()` and `strong()` are the strongest of every held level and live
  pulse (0 with none). Invariant: both are in [0, 1].
- `advance(delta)` requires `delta ≥ 0` and ages the pulses.
- Every `send_interval` (exported, 0.03 s) it sends the mix to each pad
  (each command lasting `command_time`, 0.12 s), or stops them when the
  mix is 0. With `settings.vibration` off it sends nothing and stops the
  pads, and `sent_weak` and `sent_strong` (the last levels sent) are 0.
  On leaving the tree it stops every pad.

### EngineMeterComponent (`scripts/components/engine_meter_component.gd`)
- On the player; the engine's signals every effect reads. Exports
  `body: RigidBody3D`, `flight_input`, `fuel`, `thruster` (Components);
  `reference_force > 0` (150), `max_strength ≥ 1` (2) and
  `accel_smoothing > 0` (8) (Meter). A bad value is reported and ignored.
- `boost()` is `|thrust_intent.z|`, or 0 with no fuel or once flight has
  stopped (the body is frozen).
- `strength()` is `back_thrust_force × thrust_multiplier ÷
  reference_force`; `scaled_boost()` is `boost × min(strength,
  max_strength)`.
- `update(delta)` (each physics frame) requires every component and
  `delta ≥ 0`. `thrust_acceleration` eases towards `boost × force ×
  multiplier ÷ mass` by `1 − e^(−accel_smoothing × delta)`, and snaps to 0
  below 0.01, so it drops to 0 soon after the boost stops.
- Invariants: `boost()` in [0, 1]; `thrust_acceleration ≥ 0`.

### WarpEffect (changed, see [game loop](12_game_loop.md))
- `intensity()`: 0 when not playing; otherwise the progress `elapsed ÷
  warp_duration` (clamped to [0, 1]) on a warp out, and 1 − progress on a
  warp in. Always in [0, 1].

### ThrustEffect (changed, see [HUD and art](13_hud_and_art.md))
- Always on, spooled by the engine. Exports `engine_meter`, `particles`
  and an optional `warp_effect` (Components); `idle_level` in [0, 1] (0),
  `spool_up > 0` (6), `spool_down > 0` (3), `idle_amount` in [0, 1]
  (0.05), and `idle_velocity` (0.3), `boost_velocity` (1.3), `idle_scale`
  (0.5) and `boost_scale` (1.2), all ≥ 0 (Spool). A bad value is reported
  and ignored. `flight_input`, `fuel`, `threshold`, `refresh()` and
  `is_thrusting()` are gone.
- On ready the particles get their own copy of their process material;
  its velocity and scale ranges are the base.
- `update(delta)` (each frame) requires `engine_meter`, `particles` and
  `delta ≥ 0`. `engine_level` eases towards `max(idle_level,
  scaled_boost())`, at `spool_up` when rising and `spool_down` when
  falling. Afterwards:
  - `particles.emitting` is false once flight has stopped or while
    `warp_effect` plays, and true otherwise.
  - with `l = clamp(engine_level, 0, 1)`: `amount_ratio` is
    `lerp(idle_amount, 1, l)`, and the scale range is the base ×
    `lerp(idle_scale, boost_scale, l)`.
  - the velocity range is the base × `lerp(idle_velocity,
    boost_velocity, engine_level)` (so a stronger booster runs harder).
- Invariant: `0 ≤ engine_level ≤ max_strength`.

### BankEffect (`scripts/effects/bank_effect.gd`)
- Exports `ship: RigidBody3D` and `mesh: Node3D` (Components);
  `bank_per_yaw_rate ≥ 0` (60° per rad/s), `max_bank_degrees` in [0, 90]
  (60) and `bank_speed > 0` (50) (Bank). A bad value is reported and
  ignored.
- `update(delta)` (each physics frame) requires both and `delta ≥ 0`. Once
  flight has stopped (the ship is frozen) it leaves the mesh alone.
  Otherwise `bank` eases (`1 − e^(−bank_speed × delta)`) towards the
  ship's yaw rate in its own frame × `bank_per_yaw_rate`, clamped to
  ±`max_bank_degrees`, and the mesh's rotation is (0, 0, `bank`), keeping
  its scale and position.
- Invariant: `|bank| ≤ max_bank_degrees`.

### CameraComponent (changed, see [camera](07_camera.md))
- New `follow_rotation` (a unit quaternion, identity), `follow_offset`
  (zero) and `follow_roll` (0, radians), in the ship's frame, which the
  follow effect sets. A `follow_rotation` that isn't a unit quaternion is
  reported and ignored.
- The pivot's transform is `follow_rotation × look (pitch, yaw) × roll
  about its back axis`, at `follow_offset`. With the defaults that's the
  old pose.
- The framing invariant is now: the camera is `distance` from the pivot
  and looks at it.

### CameraFollowEffect (`scripts/effects/camera_follow_effect.gd`)
- On the player. Exports `ship: RigidBody3D`, `camera_component`,
  `engine_meter` and optional `bank_effect` and `warp_effect`
  (Components); `follow_speed > 0` (2) and `boost_follow_speed > 0` (4)
  (Lag); `max_pull ≥ 0` (0.35), `pull_ramp_time > 0` (1.5),
  `pull_stiffness > 0` (30), `pull_damping ≥ 0` (8) and `pull_drain ≥ 0`
  (2) (Pull); `camera_roll` in [0, 1] (0.15) (Roll); `fov_kick ≥ 0` (5)
  and `fov_speed > 0` (4) (FOV). A bad value is reported and ignored.
- On ready `base_fov` is the camera's FOV.
- `update(delta)` (each physics frame, before the camera) requires the
  three components and `delta ≥ 0`, and holds still once flight has
  stopped. Otherwise:
  - the lagged rotation slerps towards the ship's by `1 − e^(−rate ×
    delta)`, `rate = lerp(follow_speed, boost_follow_speed, boost)`.
  - `boost_time` grows by `delta × boost` while boosting (to at most 3 ×
    `pull_ramp_time`) and drains at `pull_drain` otherwise (to 0). The
    pull springs towards `max_pull × boost × strength × ease(min(boost_time
    ÷ pull_ramp_time, 1), 0.5) × distance`.
  - it sets the camera's `follow_rotation` (the lag in the ship's frame),
    `follow_offset` (the pull, behind the ship) and `follow_roll`
    (`camera_roll × bank`).
  - the FOV level eases (`fov_speed`) towards `scaled_boost()`, and the
    camera's FOV is `base_fov + fov_kick × level`, except while the warp
    plays (it owns the FOV then).
- `snap()` puts the lag on the ship's rotation. The first update snaps,
  so the spawn's turn doesn't swing the camera round.
- Invariant: the lagged rotation is a unit quaternion.

### CameraShakeEffect (`scripts/effects/camera_shake_effect.gd`)
- In the level, in real time (the crash slow motion doesn't slow it).
  Exports `camera_component` and optional `lose_controller` and
  `warp_effect` (Components); `death_shake ≥ 0` (2), `warp_shake ≥ 0` (3),
  `shake_decay > 0` (1.2), `shake_offset ≥ 0` (0.06) and `shake_frequency
  > 0` (25) (Shake). A bad value is reported and ignored.
- `add_trauma(amount)` requires `amount ≥ 0` and adds it. A lost game
  adds `death_shake`.
- `update(delta)` requires the camera component and `delta ≥ 0`. Trauma
  falls by `shake_decay × delta` (to 0). The shake is `max(trauma,
  warp_shake × warp intensity)`; the camera's `h_offset` and `v_offset`
  are noise (at `shake_frequency`) of size `shake² × shake_offset ×
  distance`, so they're 0 with no shake.
- Invariants: `trauma ≥ 0`, and both offsets are within that size.

### SpeedLinesEffect (`scripts/effects/speed_lines_effect.gd`)
- A `Node3D` on the player that builds its own `particles` (top level,
  world space, lines along their velocity). Exports `ship: RigidBody3D`,
  `engine_meter`, `camera_component` and an optional `warp_effect`
  (Components); `min_accel ≥ 0` (5), `max_accel > min_accel` (150),
  `amount ≥ 1` (400), `lifetime > 0` (0.8), `extra_speed ≥ 0` (0.3),
  `spread > 0` (3), `length > 0` (1), `max_alpha` in [0, 1] (0.6) and
  `colour` (Lines); `warp_speed ≥ 0` (600) and `warp_stretch ≥ 1` (4)
  (Warp). A bad value is reported and ignored.
- `level()` is the thrust acceleration's place between `min_accel` and
  `max_accel`, clamped to [0, 1] (0 once flight has stopped), or the warp
  intensity if that's higher.
- `update()` (each frame) requires the three components. Afterwards the
  particles emit exactly when `level() > 0`, at an amount ratio of
  `max(level, 0.01)` and alpha `max_alpha × level`. They stream
  backwards along the travel direction from a box `spread × distance`
  wide, ahead of the ship, at `extra_speed ×` the ship's speed on top of
  it, `length × distance × (0.3 + level)` long. In a warp they stream
  along the nose instead, at `warp_speed ×` the intensity, and up to
  `warp_stretch ×` long.

### SpaceDustEffect (`scripts/effects/space_dust_effect.gd`)
- A `Node3D` on the player that builds its own `particles`, processed by
  `resources/shaders/space_dust.gdshader`: motes in a box round the ship
  that wrap round its edges, so there are always `amount` nearby at any
  speed, fading out towards the edges so the wrap doesn't pop.
- Exports `ship: RigidBody3D` and `camera_component` (Components);
  `amount ≥ 1` (250), `drift ≥ 0` (0.15), `mote_length > 0` (0.04),
  `mote_radius > 0` (0.004), `alpha` in [0, 1] (0.35), `spread > 0` (2.5),
  `edge_fade` in [0, 1) (0.6) and `colour` (Dust), lengths in camera
  distances. A bad value is reported and ignored.
- `update()` (each frame) requires both components. Afterwards the dust
  is hidden exactly when flight has stopped; the box is centred on the
  ship with half-size `spread × distance`; the motes drift at `drift ×
  distance` per second against the travel direction (the nose when
  slower than 0.5); and each mote is `mote_length × distance` long.

### RadialBlurEffect (`scripts/effects/radial_blur_effect.gd`)
- A `CanvasLayer` under the HUD (layer −1) in the level, with a
  full-screen `rect` running `resources/shaders/radial_blur.gdshader`: a
  12-tap blur away from a centre, clear within `clear_radius` of it and
  ramping over `falloff`, with chromatic aberration (red out, blue in).
- Exports `engine_meter`, `camera: Camera3D`, `focus: Node3D` (the ship's
  mesh) and an optional `warp_effect` (Components); `blur_strength ≥ 0`
  (2), `clear_radius` in [0, 1] (0.05), `falloff > 0` (0.35), `reach ≥ 0`
  (0.12) and `blur_speed > 0` (4) (Blur); `warp_blur ≥ 0` (10) and
  `warp_aberration ≥ 0` (1) (Warp). A bad value is reported and ignored.
- `update(delta)` (each frame) requires the three components and `delta
  ≥ 0`. `strength` eases (`blur_speed`) towards `blur_strength ×
  scaled_boost()`, then is at least `warp_blur ×` the warp intensity;
  `aberration` is `warp_aberration ×` the intensity. The rect shows only
  while either is above nothing, and the blur is centred on the focus on
  screen (kept where it was while the focus is behind the camera).

### RumbleSource (`scripts/effects/rumble/rumble_source.gd`)
- The base of the rumble effects below, each feeding the `Rumble`
  autoload: `rumble` defaults to it once in the tree (tests give their
  own mixer). Motor settings must be in [0, 1]; bad settings are reported
  and ignored.
- `held_source` (empty for pulse-only sources) is the level it holds. It's
  released when the source leaves the tree and when the tree pauses it
  (the shop opening at the end of a warp, or the pause menu), since a
  paused source can't update its hold but the mixer keeps sending it.

### ThrustRumble (`scripts/effects/rumble/thrust_rumble.gd`)
- Export `engine_meter`; `min_accel ≥ 0` (5), `max_accel > min_accel`
  (150), `max_weak` (0.35). `update()` (each frame) requires the meter and
  holds `&"thrust"` at `max_weak ×` the thrust acceleration's place
  between them, clamped to [0, 1] (light motor only); it's released once
  flight has stopped.

### PickupRumble (`scripts/effects/rumble/pickup_rumble.gd`)
- Export `absorb_effect`; `weak` (0.04), `strong` (0.07), `duration > 0`
  (0.1) and `fade_power > 0` (10). Each `absorbed` pulses once.

### WarpRumble (`scripts/effects/rumble/warp_rumble.gd`)
- Export `warp_effect`; `weak` (0.6), `strong` (1.0) and `strong_power > 0`
  (3). `update()` (each frame) requires the warp and holds `&"warp"` at
  `weak × intensity` and `strong × intensity^strong_power`; it's released
  while no warp plays.

### CrashRumble (`scripts/effects/rumble/crash_rumble.gd`)
- Export `lose_controller`; `level` (1.0) and `duration > 0` (0.8). A lost
  game pulses the light motor at `level` fading linearly and the heavy
  one fading squared, over `duration`.

### AbsorbSquash (`scripts/effects/absorb_squash.gd`)
- `AbsorbSquash.along(t, anticipation, squash, stretch)`: a body's length
  along its pull at suck progress `t`. It requires `t` in [0, 1],
  `anticipation` and `squash` in [0, 1), and `stretch ≥ 0`. Before
  `anticipation` it's `1 − squash × sin(π t ÷ anticipation)`; after, with
  `u` the share of the rest, `1 + stretch × u²`. Ensured: it's positive.

### AbsorbEffect (changed, see [player growth](11_player_growth.md))
- New Squash exports: `squash_enabled` (on), `anticipation` in [0, 1)
  (0.2), `squash_amount` in [0, 1) (0.3) and `stretch_amount ≥ 0` (2). A
  bad value is reported and ignored.
- With squash on, `advance` gives each body's mesh a basis facing the
  ship, scaled by its size (shrunk as before with `shrink`) × `(across,
  across, along)`, `along = AbsorbSquash.along(t, …)` and `across = 1 ÷
  √along`, so its volume is kept. A body already on the ship isn't
  turned. Off, the mesh is scaled as before.

### TimeScaleEffect (`scripts/effects/time_scale_effect.gd`)
- In the level, in real time. Exports an optional `lose_controller`
  (Components); `hitstop_time > 0` (0.12), `hitstop_scale` in (0, 1]
  (0.02), `slowmo_scale` in (0, 1] (0.01) and `slowmo_time > 0` (2) (Time).
  A bad value is reported and ignored.
- `play()` (and a lost game) starts the hit-stop. `update(delta)`
  requires `delta ≥ 0`: for `hitstop_time` the engine's time scale is
  `hitstop_scale`; then over `slowmo_time` it eases (t²) from
  `slowmo_scale` back to 1; then it's 1, `playing` is false and
  `finished` is emitted once.
- Leaving the tree puts the time scale back to 1.
- Invariant: the time scale is in (0, 1].

### CrashBounceEffect (`scripts/effects/crash_bounce_effect.gd`)
- In the level. Exports `player: Player`, `mesh: Node3D` (the ship's
  mesh), `camera_component` and an optional `lose_controller`
  (Components); `restitution` in [0, 1] (0.5), `min_speed ≥ 0` (1.5,
  camera distances per second), `drag ≥ 0` (1.2) and `tumble_degrees ≥ 0`
  (360 per second) (Bounce). A bad value is reported and ignored.
- `bounce_off(other)` (and a lost game) requires the components. It
  reflects the player's velocity off the normal from `other` to the player
  (the ship's back when they share a point), keeping `restitution` of the
  speed into it, and at least `min_speed × distance` away from it. The
  tumble axis is the normal × that velocity.
- `update(delta)` (each physics frame, so it plays in the slow motion)
  requires `delta ≥ 0`. While bouncing, the player moves by the bounce
  velocity × `delta`, which slows by `e^(−drag × delta)`; the mesh turns
  about the tumble axis, its spin slowing at half the drag.
- Ensured after `bounce_off`: the bounce moves away from `other`.

### CrashEffect (changed, see [HUD and art](13_hud_and_art.md))
- `follow_ship` (exported, on): each explosion's particles are simulated
  in its own frame, and `advance` keeps every explosion on the ship, so
  the blast travels with the bouncing ship.

### LoseOverlay (changed, see [lose flow](09_lose_flow.md))
- Optional `time_scale_effect` and `popup_delay ≥ 0` (0.3 real seconds).
  With a time scale effect, a lost game shows the overlay `popup_delay`
  after that effect finishes; without one, at once as before.

### SkillNodeView (changed, see [skill tree](15_skill_tree.md))
- `slot_rect(index)` requires `0 ≤ index < slot_count` and is that slot
  square's rect in `slots` (`index × (slot_size + slot_gap)` along); the
  slots are drawn from it.

### ShopJuice (`scripts/ui/shop_juice.gd`)
- In the level, running while paused. Exports `shop: ShopOverlay`
  (Components); `slot_punch_scale ≥ 1` (2.5), `punch_time > 0` (0.35),
  `flash ≥ 1` (2), `bank_tick_time > 0` (0.45), `bank_punch ≥ 1` (1.15),
  `rumble_weak` (0.25), `rumble_strong` (0.45) and `rumble_time > 0`
  (0.12) (Purchase); `reveal_stagger ≥ 0` (0.12), `reveal_time > 0`
  (0.4), `reveal_from_scale` in (0, 1] (0.6), `reveal_from_alpha` in
  [0, 1] (0.15) and `reveal_rumble` (0.15) (Reveal). Motors in [0, 1]. A
  bad value is reported and ignored.
- On ready it requires the shop and its progression, and notes every
  view's state and buys and the bank. On each progression change it notes
  them again; only while the shop is open does it also play:
  - a purchase: `last_bought` is the view whose buys rose. It flashes
    `flash` × bright, settling over `punch_time × 0.6`; a copy of its
    newly filled slot pops from `slot_punch_scale` back to its size over
    `punch_time` (elastic) and is freed; the pad pulses; and the bank
    label counts from `bank_shown` to the new bank over `bank_tick_time`,
    settling from `bank_punch` ×. `bank_shown` is the new bank.
  - a reveal: `revealed` is the views that were locked and aren't now,
    nearest the bought view (or the first revealed) first. Each grows
    from `reveal_from_scale` and `reveal_from_alpha` to full over
    `reveal_time`, starting `index × reveal_stagger` in (after half the
    punch when something was bought), with a tiny pulse.

### EndgameBuild (`scripts/levels/endgame_build.gd`)
- The `Endgame` autoload, for testing the late game: it does
  nothing in a release build. Exports `toggle_key` (F2), `tree` (the skill
  tree) and `bank_amount > 0` (1e12). Off at launch.
- `apply(progression, tutorial)` requires both. Afterwards the bank is at
  least `bank_amount`, every skill has been bought until nothing more can
  be (ensured: no node can still be bought) and the tutorial is finished.
- `toggle()` flips `enabled`. On, it applies to `RunProgress`; off,
  `RunProgress.progression` starts fresh. Then it unpauses, puts the time
  scale back to 1 and reloads the current scene (with `reload_scene`, on;
  tests turn it off). The toggle key calls it.
- It shows nothing on screen (the `ENDGAME BUILD ON/OFF [F2]` label was
  removed at the user's request, 2026-11-25).

### Clock (changed, see [procedural generation](10_procedural_generation.md))
- `speed` (exported, 1, ≥ 0; a bad value is reported and ignored): time
  advances by `delta × speed`, so the title can run the orbits fast.

### HierarchyStreamer (changed, see [procedural generation](10_procedural_generation.md))
- Debug builds print each level's seed (`[Debug] Level seed n`), so a good
  one can be reused.

### TitleFraming (`scripts/title/title_framing.gd`)
- A resource: `distance_radii > 0` (2.67), `elevation_degrees` in
  (−90, 90) (28) and `screen_point` in [0, 1]² (2/3, 2/3). A bad value is
  reported and ignored.

### TitleCamera (`scripts/title/title_camera.gd`)
- `TitleCamera.frame(centre, radius, angle, framing, fov, aspect)`
  returns the overview camera's transform. It requires `radius > 0`, a
  framing, `fov` in (0, 180) and `aspect > 0`.
- The camera sits `distance_radii × radius` from the centre, at the
  elevation above the orbital plane and `angle` round it. Ensured: the
  centre projects to `screen_point` on screen, and is in front.

### TitleMenu (`scripts/ui/title_menu.gd`, `scenes/ui/title_menu.tscn`)
- A `CanvasLayer`: on the left, the logo then START, OPTIONS and EXIT, and
  an options page with VIBRATION and INVERT PITCH (each `NAME: ON/OFF`)
  and BACK. Signals `start_pressed` and `exit_pressed`.
- `settings` defaults to the `Settings` autoload and `rumble` to `Rumble`
  (tests give their own). On ready START has focus.
- OPTIONS shows the options page (VIBRATION focused); BACK or `ui_cancel`
  there goes back (OPTIONS focused). Pressing an option flips its setting
  and relabels it; turning vibration on pulses 0.3 / 0.5 for 0.15 s.
- Invariant: exactly one page shows.

### TitleScreen (`scripts/title/title_screen.gd`, `scenes/title/title_screen.tscn`)
- The main scene. Exports `level_scene` (the generated level),
  `game_scene` (its path, loaded by START), `title_seed` (1), `time_speed
  ≥ 0` (100), `orbit_speed_degrees` (1.5 per second) and `framing: TitleFraming`.
- On ready it adds the level with `title_seed` and the clock at
  `time_speed`, then quiets it: the player is stopped and hidden; the warp
  in, warp and lose controllers, pause and tutorial don't run; every HUD
  layer is hidden; its own camera is current; the mouse is visible.
- Each frame the camera circles the hierarchy's root body at
  `orbit_speed_degrees`, framed by `TitleCamera.frame`.
- START changes to `game_scene`; EXIT quits.

### PauseController (changed, see [pause](08_pause.md))
- Asked for 2026-11-25: Select no longer restarts; X restarts on a crash.
  The `restart` action is R and pad X (X is also `warp_out`, which can't
  fire once the run is lost).
- New export `lose_controller`. The `restart` action restarts only once
  that run is lost (still while paused), and is then handled so nothing
  else sees it. Mid-run, or without a lose controller, it does nothing;
  the pause menu's RESTART still restarts any time through `restart()`.
- `restart` leaves the control labels, so the pause menu's pictures don't
  show it; the crash screen prompts it.

## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done. The
user agreed the split on 2026-11-25.

### 17.0 Ship ×2 ✅
- `player.tscn`: the collider grows with the ×2 mesh (radius 1.0031625).
  The plume's own scale goes back to 0.745, so it grows with the ship.
- **Done:** `tests/player/test_player.gd` checks the collider radius is
  the base radius × the mesh scale, and finds the plume through
  `ThrustEffect.particles`.

### 17.1 Font and HUD look ✅
- Orbitron moves to `resources/fonts/` and is the holo theme's default
  font, weight 500.
- `FuelGauge`: titled BOOST, one solid bar, no readout, border or
  background. `CargoGauge`: titled CARGO, fixed-width tanks in rows, no
  readout, border, background or scanline strip, 2 px below the boost
  gauge. The minimap's title goes. Skill titles say cargo.
- **Done:** the gauge tests check the titles, the solid fill and the tank
  rows; the smoke run is clean.

### 17.2 Settings ✅
- `Settings` autoload: vibration and invert pitch, saved to
  `user://settings.cfg`. `PlayerInputComponent` reads invert pitch.
- **Done:** `tests/core/test_settings.gd` passes (defaults, changes
  notify and save, a saved file loads back).

### 17.3 Rumble ✅
- `Rumble` autoload: one-off pulses and held sources, mixed by the
  strongest per motor, sent to every pad; silent when vibration is off.
- **Done:** `tests/core/test_rumble.gd` passes.

### 17.4 Engine and warp signals ✅
- `EngineMeter` component on the player: boost, strength and smoothed
  thrust acceleration. `WarpEffect.intensity()`.
- **Done:** tests for both pass (thrust acceleration drops to 0 off the
  boost; intensity rises over a warp out and falls over a warp in).

### 17.5 Thrust always on ✅
- `ThrustEffect` spools the plume by the engine level instead of turning
  it on and off; hidden during warps and after a crash.
- **Done:** `test_thrust_effect.gd` checks idle, full boost and the spool.

### 17.6 Camera follow ✅
- `CameraFollowEffect`: turn lag, boost pull spring, camera roll and FOV
  kick on the camera rig. `CameraComponent`'s contract changes to suit.
- **Done:** tests check the lag converges, the pull overshoots and
  settles, and the FOV returns to its base.

### 17.7 Bank ✅
- `BankEffect`: the mesh rolls with yaw rate, capped.
- **Done:** `tests/effects/test_bank_effect.gd` passes.

### 17.8 Camera shake ✅
- `CameraShakeEffect`: decaying trauma plus the warp floor, in real time.
- **Done:** `tests/effects/test_camera_shake_effect.gd` passes.

### 17.9 Speed lines ✅
- `SpeedLinesEffect`, driven by thrust acceleration and the warp curve.
- **Done:** its test checks the level from thrust acceleration and warp.

### 17.10 Space dust ✅
- `SpaceDustEffect` with the wrapping particle shader.
- **Done:** its test checks the box follows the ship and the drift.

### 17.11 Boost blur ✅
- `RadialBlurEffect` and its shader: boost blur and warp aberration.
- **Done:** its test checks the strength and aberration levels.

### 17.12 Gameplay rumbles ✅
- Thrust, pickup, warp and crash rumbles feed `Rumble`.
- **Done:** a test drives each source and checks the motor levels.

### 17.13 Absorb squash and stretch ✅
- Bodies being absorbed squash, then stretch towards the ship.
- **Done:** a test checks the squash, stretch and kept volume.

### 17.14 Crash ✅
- `TimeScaleEffect` (hit-stop and slow motion), `CrashBounceEffect`, the
  explosion following the ship and the pop-up held back.
- **Done:** tests check the time scale curve, the bounce and the delay.

### 17.15 Shop juice ✅
- Purchase punch, bank count-up and unlock reveal.
- **Done:** tests check each fires on a purchase and settles.

### 17.16 Endgame build ✅
- Debug builds only, F2.
- **Done:** a test checks it maxes the tree and skips the tutorial.

### 17.17 Title screen ✅
- `scenes/title/title_screen.tscn` as the main scene: overview camera,
  menu and options. Start loads the level.
- **Done:** tests check the framing and the menu; the smoke run is clean.

## Contract changes during perf
Asked for by the user on 2026-11-25, after the rewrite:
- Rumble sources release their held level when paused (the vibration kept
  going after a warp out). See RumbleSource above.
- Select no longer restarts; X (and R) restart, only after a crash. See
  PauseController above.
  `ShopOverlay` checks `warp_out` before swallowing `pause` and `restart`,
  so X still warps in from the shop.
- The endgame build shows no label, and the crash screen loses its
  "HULL BREACH" line.
- Tests check rules, not presentation: no asserts on UI text, tuned values
  or node paths (now in `AGENTS.md` and the rewrite skill). The tests that
  did are rewritten to check the state or action behind the text.

## Performance evaluation
The load measured, the budget, and each option weighed:

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |
