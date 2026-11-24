#!/bin/bash
# PreToolUse(Bash): git and harness rules that must never be broken.
# Deliberately broad: matches "git commit", "git -C dir push", "x && git ...".

. "$(dirname "$0")/lib.sh"
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

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

matches() { echo "$COMMAND" | grep -Eq "$1"; }

GIT='(^|[^[:alnum:]_-])git\b.*'

matches "${GIT}\bcommit\b" &&
	deny "git commit is blocked in this project. Stage the changes and leave committing to the user."

matches "${GIT}\b(push|switch|rebase|cherry-pick|update-ref|worktree)\b" ||
	matches "${GIT}\bmerge([[:space:]]|$)" ||
	matches "${GIT}\bbranch\b.*[[:space:]](-[dDmMcCf]\b|--delete|--move|--copy|--force)" &&
	deny "This is the only branch. Never push, switch, merge, rebase or change other branches."

if matches "${GIT}\bcheckout\b" && ! matches '[[:space:]]--([[:space:]]|$)'; then
	deny "git checkout can switch branches. To restore files, use 'git checkout -- <paths>' or 'git restore <paths>'."
fi

matches '\.claude/state' &&
	deny "The harness state is only changed by .claude/bin/feature."

# Godot runs (tests, smoke, imports) are capped at 60 seconds each. A hung
# run once blocked the session for 20 minutes.
GODOT_RUN="(^|[^[:alnum:]_./-])godot[[:space:]]+(-|res:)"
GODOT_CAPPED="timeout[[:space:]]+(-[^[:space:]]+[[:space:]]+)*([1-5]?[0-9]|60)s?[[:space:]]+godot[[:space:]]+(-|res:)"
if matches "$GODOT_RUN"; then
	runs=$(echo "$COMMAND" | grep -Eo "$GODOT_RUN" | wc -l)
	capped=$(echo "$COMMAND" | grep -Eo "$GODOT_CAPPED" | wc -l)
	[ "$capped" -ge "$runs" ] ||
		deny "Every godot run must be capped at 60 seconds: prefix it with 'timeout 60 godot ...'. Never let a test run longer than a minute."
	matches '(^|[;&|(`[:space:]])(for|while|until)[[:space:]]' &&
		deny "Don't run godot in a loop: one capped run (timeout 60) per command, so nothing runs longer than a minute."
	tool_timeout=$(echo "$INPUT" | jq -r '.tool_input.timeout // 0')
	[ "$tool_timeout" -le 90000 ] ||
		deny "A godot command must not set a Bash timeout over 90000 ms. Runs are capped at 60 seconds."
fi

matches 'feature[[:space:]]+(accept|discard|done)\b' &&
	deny "Only the user moves a feature to its next phase. Ask them to run it with '! .claude/bin/feature <accept|discard|done>' in the prompt."

exit 0
