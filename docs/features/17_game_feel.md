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

## Decision

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written.

## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done.

## Performance evaluation
The load measured, the budget, and each option weighed:

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |
