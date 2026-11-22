---
name: perf-review
description: Final performance evaluation of a rewritten Heavy Space feature. Measures it against the 60fps budget and weighs each possible optimisation against the implementation flexibility it would cost. Use when a feature is in the perf phase, or the user asks for a performance evaluation.
---

# Performance evaluation

The feature works and its tests pass. Now find out whether it's fast enough,
and for each possible speed-up, whether it's worth what it costs in
flexibility. Flexibility means how easily the feature can be tuned, extended
with new components and effects, tested, and read. A fast, rigid feature
isn't automatically better than a slower, flexible one that's within budget.

## Measure
1. Agree a realistic load with the user, e.g. how many live bodies or
   effects, and which level. The budget is 60fps: 16.6ms a frame for
   everything, so agree what share this feature gets.
2. Write a headless benchmark in `benchmarks/<name>/` that extends
   `SceneTree`: a fixed seed, a warm-up, then N frames. Report the mean,
   p95 and worst frame for the process and physics time
   (`Performance.TIME_PROCESS`, `Performance.TIME_PHYSICS_PROCESS`) and the
   feature's own timings (`Time.get_ticks_usec`). Run it with
   `godot --headless -s benchmarks/<name>/<bench>.gd`.
3. Measure with contracts on and off (`Contract.enabled = false`). Release
   builds don't run them, so the "off" figures are what players get.
4. Record the baseline in the **Performance evaluation** section of
   `docs/features/<name>.md`.

## Weigh
For each hot spot, list the options in the feature notes' table:
- the measured before and after, from a quick experiment, not a guess
- the flexibility cost: what becomes harder (adding a component, tuning a
  value from the inspector, testing in isolation, reading the code)
- a recommendation

Rules of thumb:
- Within budget with headroom: prefer flexibility, and only take an
  optimisation that's nearly free.
- Over budget: take the options with the best gain for the least flexibility
  cost first, and stop once it's within budget.
- Data-oriented changes (packed arrays, batching, fewer nodes) usually help
  the most. Keep the parameters exported and the component boundaries intact
  where you can.
- Existing tests can't change: they're the contract, so an optimisation must
  pass them as they are. If one would need a contract change, stop and agree
  it with the user first.

Present the table to the user and let them choose. Apply one option at a
time and re-measure. Undo any that don't deliver what was measured.

Formatting, spelling, warnings, the full suite and the smoke run all happen
automatically after edits and when you finish a turn, so don't run them
yourself. Fix whatever they report.

## Finishing
Once the user has decided on each option, record the final figures and the
decisions under **Performance evaluation** in `docs/features/<name>.md`.
Then ask the user to run
`! .claude/bin/feature done`. It re-runs the full checks and deletes the
prototype.
