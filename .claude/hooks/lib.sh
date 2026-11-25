#!/bin/bash
# Shared helpers for the harness hooks and .claude/bin/feature. Sourced.

ROOT="${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)}"
HOOKS="$ROOT/.claude/hooks"
STATE_DIR="$ROOT/.claude/state"
STATE="$STATE_DIR/feature.json"
FEATURES="$ROOT/docs/features"
# Every godot run (tests, smoke, imports) is stopped after this many seconds.
GODOT_TIMEOUT=60
CODE_SPEC=('*.gd' '*.tscn' '*.tres' '*.gdshader' 'project.godot')

mkdir -p "$STATE_DIR"

state_get() { if [ -f "$STATE" ]; then jq -r ".$1 // empty" "$STATE"; fi; }
phase() { local p; p=$(state_get phase); echo "${p:-none}"; }
feature() { state_get name; }
base_ref() { local b; b=$(state_get base); echo "${b:-HEAD}"; }

# Repo-relative path, or empty if the path is outside the project.
relative() {
	case "$1" in
		"$ROOT"/*) echo "${1#"$ROOT"/}" ;;
		/*) echo "" ;;
		*) echo "$1" ;;
	esac
}

changed_since_base() {
	{
		git -C "$ROOT" diff --name-only --diff-filter=ACMR "$(base_ref)" -- "$@"
		git -C "$ROOT" ls-files --others --exclude-standard -- "$@"
	} | sort -u
}

added_since_base() {
	{
		git -C "$ROOT" diff --name-only --diff-filter=A "$(base_ref)" -- "$@"
		git -C "$ROOT" ls-files --others --exclude-standard -- "$@"
	} | sort -u
}

# A feature's notes, repo-relative: docs/features/NN_<name>.md, numbered in
# the order they were started. A feature without a file yet gets the next number.
feature_doc() {
	local name="$1" file last
	for file in "$FEATURES"/[0-9][0-9]_"$name".md; do
		if [ -f "$file" ]; then
			echo "docs/features/${file##*/}"
			return
		fi
	done
	last=$(find "$FEATURES" -maxdepth 1 -name '[0-9][0-9]_*.md' -printf '%f\n' 2>/dev/null |
		cut -c1-2 | sort -n | tail -1)
	printf 'docs/features/%02d_%s.md\n' "$((10#${last:-0} + 1))" "$name"
}

# The Contracts sections of every feature file, where agreed contracts live.
contracts_section() {
	local file
	for file in "$FEATURES"/*.md; do
		[ -f "$file" ] || continue
		awk '/^## Contracts/ { inside = 1; next }
			inside && /^#{1,2} / { inside = 0 }
			inside' "$file"
	done
}

has_contract() { contracts_section | grep -qF "\`$1\`"; }

# Where a new contract should be recorded, for the hook messages.
contract_home() {
	local name
	name=$(feature)
	if [ -n "$name" ]; then
		feature_doc "$name"
	else
		echo "the feature's file in docs/features/"
	fi
}

test_path_for() {
	local script="${1#scripts/}"
	local dir
	dir=$(dirname "$script")
	if [ "$dir" = "." ]; then
		echo "tests/test_$(basename "$script")"
	else
		echo "tests/$dir/test_$(basename "$script")"
	fi
}

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }
