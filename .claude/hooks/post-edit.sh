#!/bin/bash
# PostToolUse(Edit|Write|MultiEdit): formats production GDScript as soon as
# it changes and flags American spellings. Prototypes are skipped.

. "$(dirname "$0")/lib.sh"
path=$(jq -r '.tool_input.file_path // empty')
rel=$(relative "$path")

[[ "$rel" == *.gd ]] || exit 0
case "$rel" in addons/* | prototypes/*) exit 0 ;; esac

cd "$ROOT" || exit 0
problems=""
if ! out=$("$ROOT/.githooks/format" "$rel" 2>&1); then
	problems="$out"
	echo "$out" | grep -q 'not found' || problems="$rel still has formatting problems after .githooks/format ran.
Wrap long expressions in brackets or split them with a local variable:
$out"
fi
words=$(python3 -I "$HOOKS/americanisms.py" "$rel")
[ -z "$words" ] || problems="$problems
This is a British English project:
$words"

if [ -n "$problems" ]; then
	echo "$problems" >&2
	exit 2
fi
exit 0
