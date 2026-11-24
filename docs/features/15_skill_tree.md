# skill_tree
Started 2026-11-24. The live phase is in `.claude/bin/feature status`.

## Idea
What the user imagines, in their words: how it should look, feel and play.

"Lets rework the shop into a skill tree. [A diagram of the tree.]

The tree is a DAG where each node has a requirement, a cost and an effect.
To begin with lets have the levels shown. Each will also have a maximum
number of times it can be bought, each buy stacking it additively.

For visuals I want to have nodes with arrows and square slots that highlight
when a slot has been purchased, with n / N displaying the total bought out
of how many available.

Note that not every one will be a stat, it may also be an ability (eg. 10%
booster strength per 10% missing fuel)."

The diagram, left to right (costs in full cargo tanks per buy, slots = max
buys):
1. Mass Tank +1 (cost 1, 1 slot).
2. Fuel tank size +N, Fuel refill rate +N, Booster strength +N (cost 2,
   5 slots each), each needing 1.
3. Two Mass Tank +1 nodes (cost 5, 2 slots each), each needing all of 2.
4. Pickup radius +1, Mining efficiency +1, Manoeuvring +1, Mass
   efficiency +1 (cost 2, 5 slots each) and the ability "10% booster
   strength per 10% missing fuel" (cost 3, 1 slot), each needing both
   tier-3 Mass Tank nodes.
5. Mass Tank +1 (cost 5, 1 slot), needing all of 4.

Answers: a node with several parents needs at least one level in every
parent. Mining efficiency raises the mass to cargo conversion, mass
efficiency lowers the cargo weight.

## Prototype log
One line per iteration: what changed and what the user said about it.
- v1: the shop is replaced by a skill tree overlay (after a warp, and
  once at start with a 100-mass test bank). Twelve nodes as in the
  diagram, each a `tree_node.gd` resource on `main.tscn` (title, effect,
  step, cost in full tanks, max buys, requires, grid position). Curved
  arrows (gold once the parent is bought), square slots under each node
  (gold when bought) and `n / N`. Locked nodes are dim, maxed ones gold.
  The ability scales thrust by +10% per whole 10% missing fuel. Starting
  size is gone from the shop. User: "This is good. Right now it's very
  hard to read." Remove the arrows for a level requirement (each buy
  raises the level by 1); zoom in on the selected node with an eased
  camera, LT/RT to zoom; A buys, X warps back in; a holo/vaporwave UI in
  keeping with the game.
- v2: arrows replaced by `required_level` per node (columns at LV 0, 1,
  4, 6, 15, shown as `// LV n` headers); the player level is the total
  buys. The tree is a camera view: a critically damped glide
  (`camera_smooth_time` 0.25) to the focused node, zoom 1.25 by default
  (LT/RT or Q/E or the wheel, 0.45–2.2). A buys, X (or the X key) warps
  in. Holo restyle: mono font, cyan panels, magenta focus glow, gold
  slots, Pixelify title, scanlines, scrolling magenta horizon grid on a
  purple sky. User: LT/RT don't zoom and X doesn't warp in; the `// LV`
  text is in a weird place and disappears when moving around.
- v3: the runtime input events used device 0 rather than -1 (all
  devices), so the pad never matched; fixed. Column headers replaced by
  an `LV n` tab on each node's top-right edge (cyan when met, magenta
  when locked, gold when maxed), and the canvas is sized to cover the
  whole tree. User: replace the shop background with the space skybox.
- v4: the gradient and horizon grid are replaced by the game's sky
  (`space.tres`) in a SubViewport with its own world, its camera turning
  slowly (`sky_spin_speed` 1.5°/s) and panning with the tree camera
  (`sky_parallax` 6° per 1000 px). User: title in the normal font (keep
  the shadow); add keyboard controls, mouse wheel to zoom.
- v5: title in the HUD's mono font with the cyan shadow kept. Keyboard:
  WASD or arrows move between nodes, Space or Enter buys, X warps in,
  wheel or Q/E zooms; the hints list both. User: warp on X everywhere;
  bank as mass only (no tanks); costs in Mkg (1 mass = 1 Mkg), green when
  affordable and red when not; default zoom about 75% of 1.25.
- v6: in-game `warp_out` rebound at runtime to pad X and the X key
  (was A / Space). Bank reads `BANK n Mkg`; each node's footer is a
  separate label, `COST n Mkg` in green (affordable) or red; the detail
  line matches. `default_zoom` 0.95. User: drop the details pane, only
  show the controls; no space before Mkg and no "COST".
- v7: the bottom panel holds only the control hints. Node footers read
  `10Mkg` (green or red), the bank `BANK 100Mkg`. User: remove the
  second Mass Tank in the third column.
- v8: `tank_2b` removed; `tank_2a` (LV 4, 2 slots) is centred in its
  column. Tanks now max out at 1 + 1 + 2 + 1 = 5 in all. User: drop the
  title's shadow and rename it "SHOP".
- v9: the title reads `SHOP` in plain magenta mono, no shadow. User:
  (awaiting feedback)

## Accepted behaviour
Filled in before acceptance. This is the spec for the rewrite: the behaviours
to keep, the tuned values the user liked, and what was tried and dropped.
From `prototypes/skill_tree/` (`main.gd`, `main.tscn`,
`skill_tree_overlay.gd`, `booster_ability.gd`, `tree_node.gd`), v9.

### Keep
- **The shop is a skill tree.** It replaces the list of upgrade buttons
  and opens after each warp, as before. Each node has an id, a title, an
  effect, a step per buy, a cost per buy (flat, in mass), a maximum number
  of buys, a required level and a position on the grid (column, row).
- **Level gates, no prerequisites.** The player's level is the total
  number of buys across the tree. A node unlocks once the level reaches
  its required level. A node can be bought while it's unlocked, not
  maxed and its cost is no more than the bank.
- **Buys stack additively.** An effect's amount is the sum of `step ×
  buys` over every node with that effect (the Mass Tank nodes share one).
  - Cargo tanks: `+round(amount)` tanks.
  - Fuel tank size, booster strength, pickup radius, manoeuvring (all
    three torques) and mining efficiency (pickup `mass_conversion`):
    `× (1 + amount)`.
  - Fuel refill rate: `refill_time ÷ (1 + amount)`.
  - Mass efficiency: `cargo_weight × max(0, 1 − amount)`.
- **The ability:** "10% booster strength per 10% missing fuel". Thrust is
  scaled by `1 + amount × missing`, where `missing = 1 − fuel ÷
  tank_size`, snapped down to whole tenths (`snap_to_tenths`, on), and
  recalculated every physics frame. Amount 1 is +10% per 10%.
- **Starting size** is no longer sold. Turn speed is now "Manoeuvring".
- **Warp is pad X and Space:** in game they warp out (pad A no longer
  does), and in the shop they warp back in. Decided at the rewrite: the
  prototype's X key is dropped, and Space keeps warping.
- **Shop controls:** move between nodes with WASD, the arrows, the d-pad
  or the left stick; Enter or pad A buys the selected node (Space doesn't:
  the agreed menu input stays); LT/RT, Q/E or the mouse wheel zoom; pad X
  or Space warps in. Pause and restart are swallowed
  while the shop is open. Mouse click also buys, and the hint for warping
  in is clickable.
- **Camera:** the tree is a zoomable view centred on the selected node.
  It glides there with a critically damped spring (eases out and in).
  Held triggers or keys change the zoom by `2 ^ (zoom_speed × dt)`; each
  wheel notch by ×1.15; the shown zoom eases to the target (rate 12/s).
  On opening, the first buyable node (or the first node) is selected and
  the camera snaps to it at the default zoom.
- **Look (holo, in keeping with the HUD):** the HUD's mono font
  throughout.
  - Background: the game's space sky (`space.tres`) in its own world,
    its camera turning slowly and panning with the tree camera. Holo
    scanlines over everything.
  - Top-left panel: `SHOP` (magenta, no shadow), `PILOT LV n` (cyan),
    `BANK nMkg` (gold). 1 mass = 1 Mkg.
  - Bottom panel: only the control hints, with `[X] WARP IN >>`.
  - Node: a translucent dark panel with the upper-cased title, and a
    footer: the cost as `nMkg` (green when buyable, red when not),
    `LOCKED | LV n` (magenta) or `MAXED` (gold). A tab on its top-right
    edge reads `LV n`: cyan when met, magenta when locked, gold when
    maxed. Under it, one square slot per possible buy (gold when bought,
    dark with an amber outline when not) and `n/N`.
  - Border: bright cyan when buyable, dim cyan when not, faint when
    locked, gold when maxed. The selected node has a magenta border and
    glow, hover a dimmer magenta.

### Tuned values
The tree (`main.tscn`). Costs were written as full tanks × 5 mass.

| id | title | effect, step | cost (Mkg) | max | LV | grid |
|---|---|---|---|---|---|---|
| `tank_1` | Mass Tank +1 | tanks, 1 | 5 | 1 | 0 | (0, 0) |
| `fuel_tank` | Fuel tank size +25% | fuel tank, 0.25 | 10 | 5 | 1 | (1, −1) |
| `refill_rate` | Fuel refill rate +10% | refill, 0.1 | 10 | 5 | 1 | (1, 0) |
| `booster` | Booster strength +20% | booster, 0.2 | 10 | 5 | 1 | (1, 1) |
| `tank_2` | Mass Tank +1 | tanks, 1 | 25 | 2 | 4 | (2, 0) |
| `pickup_radius` | Pickup radius +20% | pickup, 0.2 | 10 | 5 | 6 | (3, −2) |
| `mining` | Mining efficiency +20% | mining, 0.2 | 10 | 5 | 6 | (3, −1) |
| `boost_missing_fuel` | 10% booster strength per 10% missing fuel | ability, 1.0 | 15 | 1 | 6 | (3, 0) |
| `manoeuvring` | Manoeuvring +20% | torques, 0.2 | 10 | 5 | 6 | (3, 1) |
| `mass_efficiency` | Mass efficiency +15% | cargo weight, 0.15 | 10 | 5 | 6 | (3, 2) |
| `tank_3` | Mass Tank +1 | tanks, 1 | 25 | 1 | 15 | (4, 0) |

| value | setting |
|---|---|
| camera smooth time | 0.25 s |
| zoom default / min / max | 0.95 / 0.45 / 2.2 |
| zoom speed | 1.5 (doubles per 1/1.5 s held) |
| wheel step | ×1.15 |
| sky spin / parallax | 1.5°/s / 6° per 1000 px |
| node size, column, row | 240 × 140, 340, 190 px |
| slot size, gap | 20, 5 px |
| colours | cyan (0.3, 0.9, 1), magenta (1, 0.3, 0.8), gold (1, 0.88, 0.3), amber (0.95, 0.7, 0.15), green (0.3, 1, 0.5), red (1, 0.25, 0.2), panel (0, 0.04, 0.07, 0.75) |

### Edge cases noticed
- Input events made in code default to device 0. They must use −1 (all
  devices) or the pad never matches.
- Column headers placed above each column's top node were staggered and
  scrolled out of view; the level belongs on each node.
- The tree's drawing control needs a size covering the whole tree.
- Space as a buy key clashes with the agreed menu input (Space only warps
  out). Space stays off `ui_accept`.

### Tried and dropped, or test-only
- Prerequisite arrows (a DAG, every parent needing a buy): hard to read.
- A details pane (effect, totals, next cost, messages): the user wanted
  only the controls shown.
- Costs in full tanks, and the bank in tanks: costs and bank are in Mkg.
- The X key for warping, and Space for buying.
- The Pixelify title with a cyan shadow; a purple gradient with a
  scrolling magenta horizon grid; a second Mass Tank node in column 3.
- Test-only: `starting_bank` (100), `open_tree_on_start`.

## Decision
- 2026-11-24: done. The prototype was deleted.
- 2026-11-24: accepted, moving to the rewrite.

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written. The user agreed the split on
2026-11-24 and asked to go ahead, being told of every new or changed
contract.

### SkillEffect (`scripts/progression/skill_effect.gd`)
- An abstract Resource: what buying a skill node does to the player.
- `apply(player, amount)` requires a player and `amount ≥ 0`, then calls
  the subclass's `_apply(player, amount)`. A broken pre-condition is
  reported and changes nothing.
- `amount` is the sum of `step × buys` over every node sharing this effect
  resource (the tree's job), so buys stack additively. The effect is
  applied once to a fresh player before its `_ready` (the run starter's
  job).
- Each subclass in `scripts/progression/effects/` changes only its own
  stat, and amount 0 changes nothing. Its resource is in
  `resources/progression/effects/`.

### CargoTanksEffect (`scripts/progression/effects/cargo_tanks_effect.gd`)
A `SkillEffect` (see above), resource `cargo_tanks_effect.tres`.
`_apply(player, a)`: `cargo.tanks + round(a)`. Requires `player.cargo`: a
broken pre-condition is reported and changes nothing.

### FuelTankEffect (`scripts/progression/effects/fuel_tank_effect.gd`)
A `SkillEffect` (see above), resource `fuel_tank_effect.tres`.
`_apply(player, a)`: `fuel_component.tank_size × (1 + a)`.

### RefillRateEffect (`scripts/progression/effects/refill_rate_effect.gd`)
A `SkillEffect` (see above), resource `refill_rate_effect.tres`.
`_apply(player, a)`: `fuel_component.refill_time ÷ (1 + a)`, so the tank
refills `1 + a` times as fast.

### BoosterEffect (`scripts/progression/effects/booster_effect.gd`)
A `SkillEffect` (see above), resource `booster_effect.tres`.
`_apply(player, a)`: `thruster.back_thrust_force × (1 + a)`.

### PickupRadiusEffect (`scripts/progression/effects/pickup_radius_effect.gd`)
A `SkillEffect` (see above), resource `pickup_radius_effect.tres`.
`_apply(player, a)`: `pickup_component.pickup_radius × (1 + a)`. Requires
`player.pickup_component`: a broken pre-condition is reported and changes
nothing.

### ManoeuvringEffect (`scripts/progression/effects/manoeuvring_effect.gd`)
A `SkillEffect` (see above), resource `manoeuvring_effect.tres`.
`_apply(player, a)`: `rotator.pitch_torque`, `turn_torque` and
`roll_torque` each × `(1 + a)`.

### MiningEffect (`scripts/progression/effects/mining_effect.gd`)
A `SkillEffect` (see above), resource `mining_effect.tres`.
`_apply(player, a)`: `pickup_component.mass_conversion × (1 + a)`.
Requires `player.pickup_component`: a broken pre-condition is reported and
changes nothing.

### MassEfficiencyEffect (`scripts/progression/effects/mass_efficiency_effect.gd`)
A `SkillEffect` (see above), resource `mass_efficiency_effect.tres`.
`_apply(player, a)`: `cargo_weight.cargo_weight × max(0, 1 − a)`. Requires
`player.cargo_weight`: a broken pre-condition is reported and changes
nothing.

### Player (changed, see [mass tanks](14_mass_tanks.md))
- New optional exports `cargo_weight: CargoWeightComponent` and
  `missing_fuel_boost: MissingFuelBoostComponent`, set in `player.tscn`.

### ThrusterComponent (changed, see [flight](03_flight.md))
- New runtime `thrust_multiplier` (1, not exported), which must not be
  negative: a negative value is reported and ignored. The force is
  `intent.z × back_thrust_force × thrust_multiplier × fuel fraction`.
  `back_thrust_force` stays the upgraded base.

### MissingFuelBoostComponent (`scripts/components/missing_fuel_boost_component.gd`)
The ability "10% booster strength per 10% missing fuel".
- Exports: `thruster` and `fuel` (Components); `bonus_per_missing ≥ 0`
  (0, so off until bought) and `snap_to_tenths` (on) (Missing fuel
  boost). A negative bonus is reported and ignored.
- `missing()` is `1 − fuel.fuel ÷ fuel.tank_size`, clamped to [0, 1], and
  with `snap_to_tenths` rounded down to a whole tenth.
- `boost()` is `1 + bonus_per_missing × missing()`: 1 when the bonus is 0
  or the tank is full, never below 1.
- `_ready` requires `thruster` and `fuel`; a broken pre-condition is
  reported and the component stays inactive. It runs each physics frame
  before the thruster (`process_physics_priority = -1`).
- Post-condition each physics frame: `thruster.thrust_multiplier ==
  boost()`.

### MissingFuelBoostEffect (`scripts/progression/effects/missing_fuel_boost_effect.gd`)
A `SkillEffect`: `_apply(player, a)` adds `a` to
`missing_fuel_boost.bonus_per_missing`, so amount 1 is +10% per 10%
missing. Requires `player.missing_fuel_boost`: a broken pre-condition is
reported and changes nothing.

### SkillNode (`scripts/progression/skill_node.gd`)
- A Resource. Exports: `id: StringName` (the key progression stores buys
  under), `title`, `effect: SkillEffect`, `step ≥ 0` (added to the
  effect's amount per buy), `cost > 0` (Mkg per buy, flat), `max_buys ≥
  1`, `required_level ≥ 0` and `grid: Vector2` (column, row). A bad number
  is reported and ignored.
- `is_valid()` is a non-empty id and an effect.

### SkillTree (`scripts/progression/skill_tree.gd`)
- A Resource. Export `nodes: Array[SkillNode]`.
- `is_valid()`: every node is set and valid, and the ids are unique.
- `find(id)` returns the node with that id, or null.
- `effects()` returns each distinct effect once, in node order.
- `amount(effect, levels)` takes the buys by id (`Dictionary`, a missing
  id is 0) and returns `Σ step × buys` over the nodes with that effect.
  Requires every buy count to be ≥ 0: a broken pre-condition is reported
  and returns 0. Post-condition: the amount is ≥ 0.
- `resources/progression/skill_tree.tres` holds the tuned tree (the
  table in **Accepted behaviour**).

### Progression (changed, see [game loop](12_game_loop.md))
Skill node buys are keyed by `node.id`. They were kept apart from the old
upgrade levels until 5.22 removed those.
- `buys(node)` requires a node and returns its buys, 0 if never bought.
  `buys_by_id()` returns a copy of every node's buys, for
  `SkillTree.amount`.
- `player_level()` is the total of every node's buys.
- `is_unlocked(node)` is `player_level() ≥ node.required_level`, and
  `is_maxed(node)` is `buys(node) ≥ node.max_buys`.
- `can_buy(node)` is a valid node that's unlocked, not maxed and costs no
  more than the bank. A null or invalid node can't be bought (not an
  error).
- `buy(node) -> bool` (`buy_node` until 5.22 removed the upgrade `buy`):
  if it can't be bought, returns false and changes
  nothing (not an error). Otherwise the bank drops by exactly
  `node.cost`, the node's buys and the player level rise by 1, `changed`
  is emitted and it returns true.
- Invariant, after every change: `bank ≥ 0` and every buy count `≥ 0`.

### RunStarter (changed, see [game loop](12_game_loop.md))
- New optional export `tree: SkillTree` (Skill tree). When set it must be
  valid: a broken pre-condition is reported and nothing is applied (the
  run doesn't start).
- `upgrades` is gone (5.22). Post-condition, added: every effect in
  `tree.effects()` has been applied exactly once, with `tree.amount(effect,
  progression.buys_by_id())`. Unbought effects get amount 0, which changes
  nothing.

### Input map (changed, see [game loop](12_game_loop.md))
Checked by `tests/test_project_input.gd`.
- `warp_out` is exactly Space and joypad X (any device). Pad A no longer
  warps.
- `ui_accept` stays exactly Enter and joypad A.
- `ui_up`, `ui_down`, `ui_left` and `ui_right` keep Godot's defaults (the
  arrows, the d-pad and the left stick) and add W, S, A and D.
- New `shop_zoom_in` (RT, E, mouse wheel up) and `shop_zoom_out` (LT, Q,
  mouse wheel down).

### SkillNodeView (`scripts/ui/skill_node_view.gd`, `scenes/ui/skill_node_view.tscn`)
One node of the shop's tree: a focusable Button, 240 × 140.
- Exports: `footer: Label`, `tab: Label`, `tab_panel: Control` and
  `slots: Control` (Components); `slot_size > 0` (20) and `slot_gap ≥ 0` (5) (Layout);
  the shop palette (Colours). The scene holds the layout and fonts.
- `show_node(node, progression)` requires both (and a valid node). A
  broken pre-condition is reported and changes nothing. Afterwards `node`
  is the node shown and `state` is `state_of(node, progression)`, in
  order: `MAXED` if maxed, `LOCKED` if not unlocked,
  `BUYABLE` if `progression.can_buy(node)`, else `UNAFFORDABLE`.
- Post-conditions, by state:

| state | footer (colour) | tab colour | border |
|---|---|---|---|
| `BUYABLE` | `nMkg` (green) | cyan | bright cyan |
| `UNAFFORDABLE` | `nMkg` (red) | cyan | dim cyan |
| `LOCKED` | `LOCKED \| LV n` (magenta) | magenta | faint cyan |
| `MAXED` | `MAXED` (gold) | gold | gold |

  - the text is the title in upper case; the tab reads `LV n` (the
    required level)
  - `slot_count == node.max_buys`, `filled == buys(node)`, and the count
    reads `filled/slot_count`
  - costs show whole numbers without decimals, else one decimal
- Focus draws a magenta border with a glow, hover a dimmer magenta.
- Added at the perf review (option A): showing the same node with the
  same state and buys as last shown restyles nothing, since its
  post-conditions already hold.
- `MassText.mkg(mass)` (`scripts/ui/mass_text.gd`) writes mass as
  `nMkg`: whole numbers without decimals, else one decimal (1 mass = 1
  Mkg). The shop's bank uses it too.

### ShopCamera (`scripts/ui/shop_camera.gd`)
The shop's view onto the tree: a Node the shop drives each frame, so tests
advance it by hand.
- Exports (Camera): `smooth_time > 0` (0.25 s), `default_zoom` (0.95),
  `min_zoom > 0` (0.45), `max_zoom ≥ min_zoom` (2.2), `zoom_speed > 0`
  (1.5), `wheel_step > 1` (1.15) and `zoom_rate > 0` (12). A bad value is
  reported and ignored.
- Read-only state: `position` (tree space), `zoom` and `target_zoom`.
- `snap(target)`: `position = target`, no velocity, and `zoom =
  target_zoom = default_zoom` (clamped).
- `advance(delta, target, push)` requires `delta ≥ 0` and `push` in
  [−1, 1] (zoom out to in); a broken pre-condition is reported and
  changes nothing.
  - `position` moves towards `target` with a critically damped spring of
    `smooth_time`: it eases out and in, gets closer every frame and never
    passes the target.
  - `target_zoom × 2 ^ (push × zoom_speed × delta)`, clamped.
  - `zoom` eases towards `target_zoom` by `1 − e ^ (−zoom_rate × delta)`.
- `step_zoom(notches)`: `target_zoom × wheel_step ^ notches`, clamped.
- `offset(view_size)` is `view_size ÷ 2 − position × zoom`: where the
  tree's origin goes so `position` sits in the view's centre.
- Invariant: `min_zoom ≤ zoom, target_zoom ≤ max_zoom`.

### ShopOverlay (rebuilt, see [game loop](12_game_loop.md))
Replaces the list of upgrade buttons with the skill tree.
- A CanvasLayer (`process_mode = ALWAYS`, layer 30). Exports:
  `warp_controller` and `run_starter` (the tree is `run_starter.tree`),
  and the scene's parts (Components); `reload_on_launch` (on; tests turn
  it off) and `node_scene` (Shop); `column` (340) and `row` (190) px
  (Layout); `sky_spin_speed` (1.5°/s) and `sky_parallax` (6° per 1000 px)
  (Sky). `progression` defaults to the autoload. The layout, sky, panels,
  hints and scanlines are in the scene.
- `_ready` requires a warp controller and a run starter with a valid tree.
  It adds one `SkillNodeView` per tree node, in order, at `grid ×
  (column, row)`, shifted so every view (and its tab) sits inside the
  tree control, which is sized to hold them all. Each view holds its
  node but isn't styled until `open()` (perf review, option B). It starts
  hidden.
- `open()`, on `warp_finished`, requires the shop to be closed.
  Afterwards it is visible, the tree is paused, the mouse is visible,
  every view shows its node, the first buyable node (else the first node)
  has focus and the camera is snapped to it.
- While open, each frame the camera advances towards the focused view's
  centre, with push `shop_zoom_in − shop_zoom_out` strength; a wheel
  notch on either steps the zoom. The tree control is placed at
  `camera.offset(view size)` and scaled by the zoom. The sky camera turns
  by `sky_spin_speed` and pans with the camera by `sky_parallax`.
- While open, `pause` and `restart` are marked handled, and `warp_out`
  (Space, pad X) or the warp hint launches.
- Pressing a view calls `progression.buy_node(node)`. On
  `progression.changed` every view and both labels refresh: `PILOT LV n`
  and `BANK nMkg`.
- Invariant while open: one view per node, in order, each showing its
  node's current state.
- `launch()` requires the shop to be open. It unpauses, emits `launched`
  and, with `reload_on_launch`, reloads the current scene.

## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done.

### 5.13 Skill effects ✅
- `SkillEffect` (abstract resource, `apply(player, amount)`) and one small
  subclass per stat in `scripts/progression/effects/`: cargo tanks, fuel
  tank, refill rate, booster, pickup radius, manoeuvring, mining and mass
  efficiency, each with its resource in `resources/progression/effects/`.
- **Done:** `tests/progression/test_skill_effect.gd` and
  `tests/progression/effects/` pass (amount 0 changes nothing, each changes
  only its own stat, negative amounts are rejected).

### 5.14 Missing fuel boost ✅
- `ThrusterComponent.thrust_multiplier`, `MissingFuelBoostComponent` on
  the player (off until bought) and `MissingFuelBoostEffect`.
- **Done:** `tests/components/test_missing_fuel_boost_component.gd`,
  `test_thruster_component.gd` and the effect's test pass (+10% per whole
  10% missing at amount 1, nothing at 0).

### 5.15 Skill nodes and the tree ✅
- `SkillNode` and `SkillTree` resources, and the tuned
  `resources/progression/skill_tree.tres`.
- **Done:** `tests/progression/test_skill_node.gd` and
  `test_skill_tree.gd` pass (unique ids, amounts summed per effect), and a
  test checks the tuned tree's values.

### 5.16 Progression buys skill nodes ✅
- `Progression.player_level()`, `is_unlocked`, `is_maxed`, `can_buy` and
  `buy` for nodes, alongside the old upgrade API.
- **Done:** `tests/progression/test_progression.gd` passes, with tests
  for the level gates, the cap and the flat cost.

### 5.17 The run starts from the tree ✅
- `RunStarter.tree`: each effect applied once with its summed amount; the
  level gets the tuned tree (its upgrades stay until 5.22, so the old shop
  keeps working until 5.21).
- **Done:** `tests/levels/test_run_starter.gd` passes, rewritten for the
  tree.

### 5.18 Warp on pad X, WASD and zoom input ✅
- `project.godot`: `warp_out` is Space and pad X, WASD join the `ui_`
  directions, and new `shop_zoom_in` / `shop_zoom_out` actions.
- **Done:** `tests/test_project_input.gd` passes with the new bindings,
  and `ui_accept` is still only Enter and pad A.

### 5.19 Skill node view ✅
- `SkillNodeView` scene and script: panel, title, cost footer, `LV` tab,
  slots and `n/N`, styled from a node and the progression.
- **Done:** `tests/ui/test_skill_node_view.gd` passes (footer text and
  colour, tab colour, one slot per buy, filled slots match the level).

### 5.20 Shop camera ✅
- `ShopCamera`: the damped glide to a target and the clamped zoom,
  advanced by hand in tests.
- **Done:** `tests/ui/test_shop_camera.gd` passes (reaches the target
  without overshoot, zoom stays in range, wheel steps).

### 5.21 Skill tree shop ✅
- `ShopOverlay` rebuilt: the tree of node views, the sky, the top and hint
  panels, scanlines, buying, zoom, warping in.
- **Done:** `tests/ui/test_shop_overlay.gd` passes, rewritten for the
  tree, and the level opens the new shop after a warp.

### 5.22 Remove the upgrade system ✅
- Delete `Upgrade`, its subclasses, resources and tests, and the old
  progression API. Update their contracts in
  [game loop](12_game_loop.md) and [mass tanks](14_mass_tanks.md).
- **Done:** nothing references `Upgrade`; the full suite and smoke run
  pass.

## Performance evaluation
The load measured, the budget, and each option weighed:

**Load** (agreed 2026-11-24): the generated level, seed 12345, with the
tuned 11-node tree, and a generated 60-node tree to show how it scales.
`benchmarks/skill_tree/bench.gd` (keys `contracts=0|1`, `nodes=11|60`):
20 shop builds, 20 run starts with every node bought, 2000 boost steps,
then 300 frames with the shop open (focus moving every 20 frames, zoom
held in and out) and 60 buys, one a frame. Headless has no GPU, so the
sky's render isn't measured. It only renders while the shop is visible.

**Budget** (agreed): shop open ≤ 2 ms a frame (mean); a buy ≤ 4 ms (a
one-frame spike); building the shop at level load ≤ 10 ms, once a run;
the boost ≤ 0.05 ms a physics frame.

**Baseline**, mean / p95 / worst in ms, contracts off (on is within
noise of off for every figure):

| Measure | 11 nodes | 60 nodes | Budget |
| ------- | -------- | -------- | ------ |
| shop `_process` | 0.008 / 0.009 / 0.034 | 0.013 / 0.014 / 0.031 | 2 ✅ |
| whole process frame, shop open | 0.010 / 0.012 / 0.036 | 0.016 / 0.018 / 0.041 | 2 ✅ |
| a buy | 1.51 / 2.63 / 2.79 | 14.3 / 15.0 / 15.8 | 4: ✅ / ❌ |
| shop build | 8.2 / 11.7 / 11.7 | 42.0 / 46.0 / 46.0 | 10: worst ❌ / ❌ |
| run start | 0.08 / 0.10 / 0.10 | 0.26 / 0.29 / 0.29 | ✅ |
| boost step | 0.0017 / 0.002 / 0.007 | same | 0.05 ✅ |

A buy and the build both scale with the node count: every buy restyles
every view (about 0.24 ms each), and a view costs about 0.7 ms to build
and style.

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |
| A. A view skips `show_node` when its node, state and buys are unchanged | buy 1.51 (11), 14.3 (60) | buy 0.25 (11), 1.31 (60) | Small: a view caches what it last showed, so editing a node's title or cost while the shop is open wouldn't show until its state changes (nodes are edited in the editor, not at run time). Tests pass unchanged. | Taken |
| B. Don't style the views while building (the shop is hidden; `open()` styles them all) | build 8.2, worst 11.7 (11); 42.0 (60) | build 4.8, worst 6.7 (11); 23.2 (60) | Moves the styling to `open()` (with A, 0.55 → 4.65 ms for 11 nodes), behind the warp fade while the game is paused, so only runs that crash and restart save it. A small contract change: views hold their node before they first show it. | Taken |
| C. A lighter view: draw the tab and footer in `_draw`, share the style boxes | not measured | | High: the layout and fonts leave the scene, so they can't be edited in the editor. Only the 60-node build needs it. | Skipped: the tuned tree is within budget |
| D. The sky's SubViewport | can't be measured headless | | It already renders only while the shop is visible. | Nothing to do |

**Final**, with A and B, mean / p95 / worst in ms, contracts off (on is
within noise):

| Measure | 11 nodes | 60 nodes | Budget |
| ------- | -------- | -------- | ------ |
| shop `_process` | 0.007 / 0.009 / 0.021 | 0.013 / 0.015 / 0.041 | 2 ✅ |
| whole process frame, shop open | 0.010 / 0.012 / 0.030 | 0.016 / 0.018 / 0.052 | 2 ✅ |
| a buy | 0.25 / 0.57 / 1.58 | 1.31 / 2.73 / 2.81 | 4 ✅ |
| shop build | 4.8 / 6.7 / 6.7 | 23.2 / 25.1 / 25.1 | 10: ✅ / ❌ |
| `open()`, once a run | 4.65 | not measured | |
| run start | 0.09 / 0.18 / 0.18 | 0.26 / 0.29 / 0.29 | ✅ |
| boost step | 0.002 / 0.005 / 0.009 | same | 0.05 ✅ |

The tuned tree is within every budget. A 60-node tree would still build
in about 23 ms at level load; option C is the next step if the tree grows
that far.
