---
name: prototype
description: Quickly prototype a new Heavy Space feature idea and iterate on it with the user until it plays the way they imagine, or is thrown away. Use when the user wants to try out, sketch, prototype or experiment with a new mechanic, feature or feel, or when the harness says a feature is in the prototype phase.
---

# Prototype a feature

The aim is to make the user's idea playable as fast as possible, then loop
on their feedback until it matches what they imagined, or it's clear the
idea doesn't work. Speed beats quality here. The prototype is disposable:
if it's accepted, it gets rewritten properly by the `rewrite` skill.

## Start
1. Read `docs/game_design.md` so the idea fits the game's pillars.
2. Agree a short snake_case name with the user, then run
   `.claude/bin/feature start <name>`. It refuses if git has outstanding
   changes. If so, show the user what's outstanding and ask what to do.
3. Write the user's idea, in their words, under **Idea** in
   `docs/features/<name>.md`. Ask a question only if you can't build a first
   version without the answer. Otherwise build it and let them react.

## Rules while prototyping
- Everything lives in `prototypes/<name>/`. The entry point is
  `prototypes/<name>/main.tscn`, which the user runs to try it.
- Production code (`scripts/`, `scenes/`, `resources/`, `tests/`,
  `project.godot`) is read-only. Instance or preload production scenes and
  scripts, and extend them inside the prototype folder.
- Don't use `class_name` in prototype scripts. Use `preload` instead, so
  nothing clashes with the rewrite.
- Add any new input actions at runtime with `InputMap.add_action` and
  `InputMap.action_add_event`, not in the project's input map.
- No tests, formatting, architecture or performance work. One big script and
  hard-coded values are fine.
- Do put the values the user will want to tune in `@export` variables, so
  they can tweak the feel in the inspector. Tuning is part of the feedback.

## The loop
1. Build the smallest version that shows the idea.
2. Tell the user how to try it: `godot res://prototypes/<name>/main.tscn`
   (or open the scene in the editor and press F6). Say what changed and what
   to look for.
3. Ask for their feedback, then add one line to the **Prototype log** in
   `docs/features/<name>.md`: what changed and what they said.
4. Change it based on the feedback and repeat. If an approach isn't working,
   say so and suggest a different one rather than patching it.

## Ending the prototype
When the feedback settles, ask the user whether to accept or discard it.
- **Accept:** first fill in **Accepted behaviour** in the feature notes. This
  is the spec for the rewrite: the behaviours to keep, the tuned `@export`
  values, the edge cases they noticed, and what was tried and dropped. Then
  ask the user to run `! .claude/bin/feature accept`, and continue with the
  `rewrite` skill.
- **Discard:** write down why under **Prototype log**, then ask the user to
  run `! .claude/bin/feature discard`. It deletes the prototype and keeps
  the notes.

Only the user can run accept or discard.
