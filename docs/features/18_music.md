# music
Started 2026-11-26. The live phase is in `.claude/bin/feature status`.

## Idea
"I've added music in resources/audio/music. I want the intro to play first and
then the loop to loop indefinitely when starting the game. It should only
restart when reaching the title screen."

## Prototype log
One line per iteration: what changed and what the user said about it.
- v1: persistent player on the root; intro auto-advances (gapless, via
  `AudioStreamInteractive`) into a forward-looping loop track; restarts from
  the intro on each title screen load, carries on through runs, restarts and
  pause. Accepted as built, with no changes asked for.

## Accepted behaviour
Filled in before acceptance. This is the spec for the rewrite: the behaviours
to keep, the tuned values the user liked, and what was tried and dropped.

- One music player lives for the whole session, above every scene.
- It plays `heavyspace_intro.wav` once, then `heavyspace_loop.wav` straight
  after with no gap, looping the loop forever.
- It starts again from the intro whenever the title screen loads, including
  at boot. Nothing else restarts it: starting a run, dying, restarting the
  level, the shop and the endgame all carry on mid-track.
- It keeps playing while the game is paused.
- Tuned values: volume −6 dB, `play_while_paused` on.
- The prototype loaded the `.wav` files from disk and set the loop points in
  code. The rewrite imports them, with the loop set in the import instead.

## Decision
Accepted on 2026-11-26. During the rewrite the user asked for every test
that pins a tuned value to go: tests that only checked shipped or default
values were deleted, and "bad value is ignored" tests now compare with the
value from before the bad assignment instead of a literal default.
- 2026-11-26: accepted, moving to the rewrite.

## Contracts
Agreed with the user during the rewrite, one `### Name (`scripts/<path>.gd`)`
entry per API, before that API is written. The user agreed the split and
these contracts on 2026-11-26: the music goes through its own `Music` bus,
and it restarts on a decoupled session event, not on the title screen.

### GameEvents (`scripts/core/game_events.gd`)
- The `Events` autoload: game-wide events that decouple who causes them
  from who reacts.
- `signal session_started`: a new play session begins, and anything that
  resets per session starts over.
- `start_session()` emits `session_started` exactly once per call. Nothing
  else emits it.

### TitleScreen (changed, see [game feel](17_game_feel.md))
- Exports `events: GameEvents`, defaulting to the `/root/Events` autoload.
- On ready it calls `events.start_session()` once. With no events, it skips
  this quietly.
- It knows nothing about music.

### MusicPlayer (`scripts/audio/music_player.gd`)
- The `Music` autoload. Exports `stream` (the music resource), `bus`
  (`&"Music"`), `volume_db` (−6) and `play_while_paused` (on), and
  `events: GameEvents`, defaulting to `/root/Events`.
- On ready it connects to `events.session_started`, which calls
  `restart()`. Nothing else restarts it.
- `restart()` requires a `stream`; without one it reports and does
  nothing. Afterwards it is playing from the start of the stream.
- `bus` requires a bus that exists in the layout, and `volume_db` a finite
  value. A bad value is reported and ignored.
- Invariants: with `play_while_paused` on, it processes while the tree is
  paused (off, it pauses with the tree). Scene changes, reloads and pauses
  never restart it.
- The stream (`resources/audio/music/heavyspace_music.tres`) is an
  `AudioStreamInteractive`: the intro auto-advances into the loop, whose
  import loops forward over the whole file, so the hand-over is gapless.

## Steps
The rewrite's steps, each with a **Done:** line. Ticked (✅) when done.

### 18.1 Music assets and bus ✅
- The loop's import loops forward over the whole file.
- `heavyspace_music.tres`: an `AudioStreamInteractive` whose intro
  auto-advances into the loop.
- `default_bus_layout.tres`: Master and a `Music` bus sending to Master.
- **Done:** the project imports and the smoke run passes.

### 18.2 GameEvents ✅
- `scripts/core/game_events.gd`, autoloaded as `Events`.
- **Done:** `tests/core/test_game_events.gd` checks `start_session` emits
  `session_started` once per call.

### 18.3 TitleScreen starts the session ✅
- `TitleScreen.events`; on ready it calls `start_session()`.
- **Done:** `tests/title/test_title_screen.gd` checks loading the title
  screen emits `session_started` once.

### 18.4 MusicPlayer ✅
- `scripts/audio/music_player.gd`, autoloaded as `Music`, on the `Music`
  bus.
- **Done:** `tests/audio/test_music_player.gd` checks a session start plays
  from the start, playing on doesn't jump back, a second session start
  restarts it, and a missing stream and an unknown bus are reported.

## Performance evaluation
The load measured, the budget, and each option weighed:

| Option | Before (ms) | After (ms) | Flexibility cost | Decision |
| ------ | ----------- | ---------- | ---------------- | -------- |
