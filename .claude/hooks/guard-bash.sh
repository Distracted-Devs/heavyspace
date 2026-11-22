#!/bin/bash
# PreToolUse(Bash): git and harness rules that must never be broken.
# Deliberately broad: matches "git commit", "git -C dir push", "x && git ...".

. "$(dirname "$0")/lib.sh"
COMMAND=$(jq -r '.tool_input.command // empty')

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

matches 'feature[[:space:]]+(accept|discard|done)\b' &&
	deny "Only the user moves a feature to its next phase. Ask them to run it with '! .claude/bin/feature <accept|discard|done>' in the prompt."

exit 0
