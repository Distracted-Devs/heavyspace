#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit): what each phase may change.

. "$(dirname "$0")/lib.sh"
INPUT=$(cat)
path=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
content=$(echo "$INPUT" | jq -r '[.tool_input.content, .tool_input.new_string,
	(.tool_input.edits // [] | .[].new_string)] | map(select(.)) | join("\n")')
rel=$(relative "$path")
[ -n "$rel" ] || exit 0

deny() {
	jq -n --arg reason "$1" '{
		hookSpecificOutput: {
			hookEventName: "PreToolUse",
			permissionDecision: "deny",
			permissionDecisionReason: $reason
		}
	}'
	exit 0
}

case "$rel" in
	.claude/state/*) deny "The harness state is only changed by .claude/bin/feature." ;;
esac

name=$(feature)

case "$(phase)" in
	prototype)
		case "$rel" in
			"prototypes/$name/"* | "docs/features/$name.md") ;;
			*) deny "Prototyping '$name' only changes prototypes/$name/ and docs/features/$name.md, so it can be thrown away cleanly. Use production scenes and scripts read-only (instance, preload or extend them inside the prototype folder) and add input actions at runtime with InputMap.add_action. No tests while prototyping." ;;
		esac
		if [[ "$rel" == *.gd ]] && echo "$content" | grep -Eq '^[[:space:]]*class_name'; then
			deny "Prototype scripts can't use class_name: it would clash with the names the rewrite uses. Preload the script instead."
		fi
		exit 0
		;;
	rewrite | perf)
		case "$rel" in
			prototypes/*) deny "The prototype is reference only now. Rebuild the feature in scripts/ instead." ;;
		esac
		;;
esac

if [ "$(phase)" = perf ] && [[ "$rel" == tests/* ]] && [ -e "$path" ]; then
	deny "The tests are the contract, so performance work doesn't change them. If an optimisation needs a contract change, stop and agree it with the user first."
fi

if [[ "$rel" == scripts/*.gd ]] && [ ! -e "$path" ] && ! has_contract "$rel"; then
	deny "Contracts come first. Before writing $rel, propose its pre-conditions, post-conditions and invariants to the user, agree them, and record them under ## Contracts in $(contract_home) as '### Name (\`$rel\`)'."
fi

exit 0
