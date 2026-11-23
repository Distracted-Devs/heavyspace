---
name: rewrite
description: Rebuild an accepted Heavy Space prototype as production code, with contracts agreed with the user, contract-driven GUT tests and the project's architecture. Use when a feature is in the rewrite phase, or for any production change to scripts/, scenes/ or tests/ outside a prototype.
---

# Rewrite an accepted feature

The prototype proved what the feature should do. Now build it properly in
`scripts/` and `scenes/`. Treat `prototypes/<name>/` and the **Accepted
behaviour** in `docs/features/NN_<name>.md` as the spec. Don't copy prototype
code across, and don't edit the prototype: rebuild it to the principles
below.

## Plan the steps
1. Read `docs/features/NN_<name>.md`, the prototype, and the existing code it
   touches (`ls` the file structure first).
2. Split the feature into components and effects, and propose the split to
   the user. Add the agreed steps under **Steps** in
   `docs/features/NN_<name>.md`, in the format the other feature files use: a
   `### <phase>.<n> Title` heading, bullets, and a **Done:** line. Ask the
   user which phase the feature belongs to, number the steps to follow on in
   that phase, and list the feature under it in `docs/roadmap.md`.
   Each step is a single unit of work that leaves the project opening and
   running.
3. Contracts come first. When a step builds several APIs, split it so each
   API is its own step, with its contract agreed at the start of that step.

## Each API
1. **Propose the contract.** Write out the pre-conditions, post-conditions
   and invariants, and ask the user for help defining them. Discuss them and
   get the user's agreement before writing anything.
2. **Record it** under `## Contracts` in `docs/features/NN_<name>.md` as
   `### Name (`scripts/<path>.gd`)`, written like the entries in the other
   feature files. If the change alters an
   existing API, update its contract in the feature file that owns it.
3. **Write the tests** in `tests/`, mirroring `scripts/`
   (`scripts/core/contract.gd` → `tests/core/test_contract.gd`). Test names
   state the rule they check.
4. **Implement** until the checks pass.

## Architecture and Development
- Data-oriented design: prioritise processing objects efficiently over how
  they're structured.
- Entity-component and component-effect structures. Effects, abilities and
  the like are modular: many small scripts over one large one.
- Every feature is modular and testable, and exposes its parameters so
  humans can tune the game feel. Use `@export` and `@export_group` wherever
  a value could be tuned. Start from the values the user tuned in the
  prototype.
- Avoid comments and comment headers. Make the code readable instead, and
  comment only logic that's hard to follow.
- British English in code and docs (initialise, colour, centre).

## Contracts and tests
- Tests use GUT (`addons/gut/`, v9.7.1, made for Godot 4.7), configured in
  `.gutconfig.json`.
- The point isn't a unit test per function. It's that APIs have contracts
  with pre-conditions, post-conditions and invariants.
- State contracts in code with `Contract.require` (pre-condition),
  `Contract.ensure` (post-condition) and `Contract.invariant`
  (`scripts/core/contract.gd`).
- A broken contract calls `push_error`, and GUT fails any test with an
  unexpected `push_error`. So scenario tests only need to drive the API:
  any broken contract fails them.
- To test that a contract guards its API, break it on purpose and mark it as
  expected with `assert_push_error("...")`.
- Checks only run in debug builds, and can be switched off with the
  `heavy_space/contracts/enabled` project setting.

Formatting, spelling, warnings, the full suite and the smoke run all happen
automatically after edits and when you finish a turn, so don't run them
yourself. Fix whatever they report.

## Finishing
When every step's **Done** contract is met, tick the steps (✅) in the
feature file and in `docs/roadmap.md`, and run `.claude/bin/feature perf`. It runs the full checks and moves the
feature into the performance evaluation (the `perf-review` skill).
