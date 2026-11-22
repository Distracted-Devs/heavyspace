#!/bin/bash
# SessionStart: tells Claude which phase it's in, which skill to load, and
# anything that needs the user's attention before editing.

. "$(dirname "$0")/lib.sh"
cd "$ROOT" || exit 0

case "$(phase)" in
	none) context="No feature is in progress. A new feature starts with the prototype skill. Any direct change to scripts/ follows the rewrite skill's rules." ;;
	prototype) context="Feature '$(feature)' is being prototyped. Load the prototype skill before working on it." ;;
	rewrite) context="Feature '$(feature)' was accepted and is being rewritten. Load the rewrite skill before working on it." ;;
	perf) context="Feature '$(feature)' is in its performance evaluation. Load the perf-review skill before working on it." ;;
esac

dirty=$(git status --porcelain -- . ':!*.import')
if [ -n "$dirty" ] && [ "$(phase)" = none ]; then
	context="$context
git has outstanding changes. Stop and ask the user about them before editing:
$dirty"
fi

command -v git-lfs > /dev/null ||
	context="$context
git-lfs isn't installed, so textures and audio are LFS pointer files and the game won't build. Tell the user to run: brew install git-lfs && git lfs install && git lfs pull"
[ -n "${GDSCRIPT_FORMATTER:-}" ] || command -v gdscript-formatter > /dev/null ||
	context="$context
gdscript-formatter isn't installed, so the formatting checks will fail. Tell the user to install it or set GDSCRIPT_FORMATTER."

jq -n --arg context "$context" '{
	hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}
}'
