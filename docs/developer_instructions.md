# Architecture and Design
- Data-oriented design 
    - prioritise the effiecient processing of objects over their structure
- Entity-component and component-effect structures
    - Where possible effects, abilities, etc must be modular, prioritising many smaller scripts over single larger ones
- Test-driven development
    - Each feature must be modular and testable and expose parameters to be changed be humans for game feel
    - The focus on testing is not in making sure each function has a unit test but that APIs have contracts with pre- and post-conditions and invariants
    - Always ask the user for help in defining the contracts.

# Dev tips
- Always check the file structure first using `ls`.
- Always check there are no outstanding changes on git before editing with `git status`. If there are, stop and prompt the user.
- This is a British English project so no Americanisms in the code (eg. initialize over initialise).
- Always parameterise where possible and surface using `@export` and `@export_group`
- Ignore all other branches and treat this as the core branch with a single developer.
- UNDER NO CIRCUMSTANCES make changes to the other branches.
- Run Godot headless to check changes run.
- Avoid using comments and comment headers, making sure code is readable, unless the logic is hard to understand.
- Always format code using gdscript-formatter after writing.

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

