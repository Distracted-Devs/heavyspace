# Architecture and Design
- Data-oriented design 
    - prioritise the efficient processing of objects over their structure
- Entity-component and component-effect structures
    - Where possible effects, abilities, etc must be modular, prioritising many smaller scripts over single larger ones
- Test-driven development
    - Each feature must be modular and testable and expose parameters to be changed by humans for game feel
    - The focus on testing is not in making sure each function has a unit test but that APIs have contracts with pre- and post-conditions and invariants
    - Always ask the user for help in defining the contracts.

# Dev tips
- Always check the file structure first using `ls`.
- Always check there are no outstanding changes on git before editing with `git status`. If there are, stop and prompt the user.
- This is a British English project so no Americanisms in the code (e.g. initialise over initialize).
- Always parameterise where possible and surface using `@export` and `@export_group`
- Ignore all other branches and treat this as the core branch with a single developer.
- UNDER NO CIRCUMSTANCES make changes to the other branches.
- Run Godot headless to check changes run.
- Avoid using comments and comment headers, making sure code is readable, unless the logic is hard to understand.
- After every change to GDScript, run `.githooks/format <changed files>` (no arguments formats `scripts/` and `tests/`). It runs gdscript-formatter with the project's 80-character line limit and lists any lines still too long. It exits 1 until they're fixed.
    - The formatter can't wrap every long line. For those, wrap the expression in brackets or split it with a local variable, then run the formatter again.
    - Don't run gdscript-formatter directly with its default settings. Its default line limit is 100, not 80.
- After every change to GDScript, also run `.githooks/warnings <changed files>` (no arguments checks every tracked script outside `addons/`). It starts the Godot editor's language server headless and prints the same warnings the editor shows (e.g. a local variable shadowing a `Node3D` property). It exits 1 until they're fixed. Name locals so they don't shadow, e.g. `body_basis` rather than `basis`.

# Testing
- Tests use GUT (`addons/gut/`, v9.7.1, made for Godot 4.7). Configuration is in `.gutconfig.json`.
- Tests live in `tests/`, mirroring `scripts/` (e.g. `scripts/core/contract.gd` → `tests/core/test_contract.gd`).
- Contracts are stated in code with `Contract.require` (pre-condition), `Contract.ensure` (post-condition) and `Contract.invariant` (`scripts/core/contract.gd`).
    - A broken contract calls `push_error`, and GUT fails any test with an unexpected `push_error`. Scenario tests only need to drive the API; any broken contract fails them.
    - To test that a contract guards its API, break it on purpose and mark it as expected with `assert_push_error("...")`.
    - Each API's contract is agreed in the Contracts section of `docs/rewrite_plan.md`, and test names state the rule they check.
    - Checks only run in debug builds, and can be switched off with the `heavy_space/contracts/enabled` project setting.
- Commands (run from the project root):
    - After adding new `class_name` scripts or addons: `godot --headless --import`
    - Smoke (the project starts with no errors): `godot --headless --quit`
    - Full test suite: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`
    - Exit code 0 means pass and 1 means fail.


# Git hooks
- Hooks live in `.githooks/` and are checked in. Enable them once per clone with `git config core.hooksPath .githooks`.
- `pre-commit` checks the *staged* GDScript (outside `addons/`): it must be formatted and have no lines over 80 characters. If it fails, run `.githooks/format`, stage again, and retry.
- `.githooks/gdscript.sh` holds the shared settings: the line limit, and where to find gdscript-formatter (`$GDSCRIPT_FORMATTER`, then `PATH`).
- The Git LFS hooks (`post-checkout`, `post-merge`, `pre-push` and the post-commit one) are copied into `.githooks/`, because setting `core.hooksPath` stops git reading `.git/hooks/`.
