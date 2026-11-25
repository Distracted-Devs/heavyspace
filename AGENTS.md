- Read through `docs/game_design.md` for all game design requirements.
- Each feature has its own file in `docs/features/`, holding its agreed
  contracts and its steps. The files are numbered in the order the features
  were started (`NN_<name>.md`), and a new feature takes the next number.
- `docs/roadmap.md` is closed: it records phases 0–5 (features 01–16)
  and isn't updated. Don't add features or phases to it.
- Ignore `README.md`.

# Feature workflow
New features go through three phases, each with its own skill:
1. **Prototype** (`prototype` skill): build the idea quickly in
   `prototypes/<name>/` and iterate on the user's feedback. No tests or
   quality control. The user accepts or discards it.
2. **Rewrite** (`rewrite` skill): rebuild an accepted feature in `scripts/`,
   with contracts agreed with the user, tests and the project's
   architecture. Any production change outside a prototype follows these
   rules too.
3. **Performance** (`perf-review` skill): once the tests pass, weigh each
   optimisation against the flexibility it costs.

`.claude/bin/feature` tracks the current feature and phase (`status`, `start`,
`perf`). Only the user moves a feature on with `accept`, `discard` or `done`.

Hooks in `.claude/hooks/` enforce each phase's rules: what may be edited,
formatting, spelling, tests, warnings and the smoke run. When a hook blocks
something, fix the cause. Don't work around it, for example by editing
through the shell instead.

Tests check rules, not presentation. Never assert on UI text (titles,
labels, captions, formatted readouts), tuned values or node paths: they
change for reasons that aren't bugs. See the `rewrite` skill.

# Always
- Check the file structure first using `ls`.
- Check there are no outstanding changes with `git status` before editing.
  If there are, stop and prompt the user.
- This is a British English project, so no Americanisms in code or docs
  (initialise, not initialize).
- Treat this as the core branch with a single developer, and ignore all
  other branches. UNDER NO CIRCUMSTANCES change other branches. Don't
  commit: leave that to the user.
- Run Godot headless to check that changes run.
- Never let a Godot run (tests, smoke or import) take longer than a minute.
  Prefix every run with `timeout 60`, run one at a time (no loops), and
  don't raise the Bash tool's timeout for it. If a run hits the limit,
  find the test that hangs or runs long and fix it, rather than running
  it again. A hook blocks uncapped runs, and the harness checks stop the
  suite after 60 seconds.

# Commands
Run these from the project root. An exit code of 0 means pass, and 1 means
fail.
- After adding new `class_name` scripts or addons:
  `timeout 60 godot --headless --import`
- Smoke (the project starts with no errors):
  `timeout 60 godot --headless --quit`
- Full test suite:
  `timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gexit`
- Format GDScript: `.githooks/format [files]`
- Editor warnings: `.githooks/warnings [files]`

# Git hooks
- Hooks live in `.githooks/` and are checked in. Enable them once per clone
  with `git config core.hooksPath .githooks`.
- `pre-commit` checks the staged GDScript (outside `addons/` and
  `prototypes/`): it must be formatted, with no lines over 80 characters.
  `.githooks/gdscript.sh` holds the line limit and where to find
  gdscript-formatter (`$GDSCRIPT_FORMATTER`, then `PATH`).
- The Git LFS hooks (`post-checkout`, `post-merge`, `pre-push` and
  `post-commit`) are copied into `.githooks/`, because setting
  `core.hooksPath` stops git reading `.git/hooks/`. Assets are in LFS, so
  `git-lfs` must be installed or the game won't build.
