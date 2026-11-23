#!/bin/bash
# The harness checks for the current phase. Prints what failed and exits 1.
# Used by the Stop hook and by .claude/bin/feature (with --force).
#
# prototype:          the prototype stays in its folder and its scene runs.
# rewrite, perf, none: production rules. New scripts have an agreed contract
#                     and a mirrored test, the code is British English,
#                     formatted and warning-free, the full suite passes and
#                     the project starts cleanly.
#
# The Godot runs are slow, so they're skipped when the code hasn't changed
# since the last pass. --force always runs them.

. "$(dirname "$0")/lib.sh"
cd "$ROOT" || exit 1

force=0
[ "${1:-}" = --force ] && force=1
failures=()
fail() { failures+=("$1"); }

fingerprint() {
	{
		phase
		feature
		git diff "$(base_ref)" -- "${CODE_SPEC[@]}"
		git ls-files --others --exclude-standard -- "${CODE_SPEC[@]}" |
			while read -r file; do echo "$file"; cat "$file"; done
	} | shasum | cut -d' ' -f1
}

cached() {
	[ "$force" -eq 0 ] &&
		[ "$(cat "$STATE_DIR/last-pass" 2>/dev/null)" = "$(fingerprint)" ]
}

godot_errors() {
	strip_ansi | grep -E -A2 'SCRIPT ERROR|^ERROR:|Parse Error' | head -40
}

report() {
	if [ "${#failures[@]}" -eq 0 ]; then
		fingerprint > "$STATE_DIR/last-pass"
		exit 0
	fi
	echo "Harness checks failed ($(phase) phase):"
	for failure in "${failures[@]}"; do
		echo
		echo "- $failure"
	done
	exit 1
}

prototype_checks() {
	local name folder outside doc
	name=$(feature)
	folder="prototypes/$name"
	doc=$(feature_doc "$name")

	touch "$STATE_DIR/baseline"
	outside=$(git status --porcelain -uall | cut -c4- |
		grep -v -e "^$folder/" -e "^$doc$" -e '\.import$' |
		grep -vxF -f "$STATE_DIR/baseline")
	[ -z "$outside" ] || fail "Prototyping only touches $folder/ and \
$doc. Undo these changes, or ask the user if they made them:
$outside"

	local named
	named=$(grep -rlE '^[[:space:]]*class_name' "$folder" --include='*.gd' 2>/dev/null)
	[ -z "$named" ] || fail "Prototype scripts can't use class_name (it would \
clash with the rewrite). Preload them instead:
$named"

	[ -n "$(find "$folder" -name '*.gd' -o -name '*.tscn' 2>/dev/null)" ] || report
	if [ ! -f "$folder/main.tscn" ]; then
		fail "Add $folder/main.tscn, the scene the user runs to try the prototype."
		report
	fi
	[ "${#failures[@]}" -eq 0 ] || report
	cached && report

	godot --headless --import > /dev/null 2>&1
	local errors
	errors=$(godot --headless --quit-after 120 "res://$folder/main.tscn" 2>&1 |
		godot_errors)
	[ -z "$errors" ] || fail "$folder/main.tscn reports errors when run headless \
for 120 frames:
$errors"
	report
}

production_checks() {
	local changed added script test_file
	changed=$(changed_since_base '*.gd' ':!addons/' ':!prototypes/')
	added=$(added_since_base 'scripts/*.gd')

	for script in $added; do
		has_contract "$script" || fail "$script is new but has no agreed \
contract. Propose its pre-conditions, post-conditions and invariants to the \
user, then record the agreed version under ## Contracts in \
$(contract_home) as \`### Name (\`$script\`)\`."
		test_file=$(test_path_for "$script")
		[ -f "$test_file" ] || fail "$script is new but has no test. Tests \
mirror scripts/, so add $test_file."
	done

	if [ -n "$changed" ]; then
		local words
		# shellcheck disable=SC2086
		words=$(python3 -I "$HOOKS/americanisms.py" $changed)
		[ -z "$words" ] || fail "This is a British English project:
$words"

		local formatting
		# shellcheck disable=SC2086
		formatting=$(format_problems $changed)
		[ -z "$formatting" ] || fail "$formatting"
	fi

	if [ "${#failures[@]}" -ne 0 ]; then
		fail "Tests, warnings and the smoke run wait until the above is fixed."
		report
	fi
	if [ "$force" -eq 0 ] &&
		[ -z "$(changed_since_base "${CODE_SPEC[@]}" ':!prototypes/')" ]; then
		report
	fi
	cached && report

	[ -z "$(added_since_base '*.gd' ':!prototypes/')" ] ||
		godot --headless --import > /dev/null 2>&1

	if [ -n "$changed" ]; then
		local warnings
		# shellcheck disable=SC2086
		warnings=$("$ROOT/.githooks/warnings" $changed 2>&1) || fail "Godot \
warnings (name locals so they don't shadow, e.g. body_basis not basis):
$warnings"
	fi

	local output
	if ! output=$(godot --headless -s addons/gut/gut_cmdln.gd -gexit 2>&1); then
		fail "The test suite failed:
$(echo "$output" | strip_ansi |
			grep -E -i -B1 -A3 'fail|error' | grep -v '^--$' | head -60)"
	fi

	local errors
	errors=$(godot --headless --quit 2>&1 | godot_errors)
	[ -z "$errors" ] || fail "The smoke run (godot --headless --quit) reports \
errors:
$errors"
	report
}

format_problems() {
	(
		# gdscript.sh exits this subshell, with its message, if the formatter
		# isn't installed. Formatting is required, so that counts as a failure.
		. "$ROOT/.githooks/gdscript.sh" 2>&1
		unformatted=$("$formatter" --check --max-line-length "$MAX_LINE_LENGTH" \
			"$@" 2>&1 | grep -Fx -f <(printf '%s\n' "$@"))
		[ -z "$unformatted" ] || echo "Not formatted (run .githooks/format):
$unformatted"
		too_long=$("$formatter" lint --max-line-length "$MAX_LINE_LENGTH" \
			"$@" 2>&1 | grep ':max-line-length:')
		[ -z "$too_long" ] || echo "Lines over $MAX_LINE_LENGTH characters. \
Wrap the expression in brackets or split it with a local variable:
$too_long"
	)
}

case "$(phase)" in
	prototype) prototype_checks ;;
	*) production_checks ;;
esac
