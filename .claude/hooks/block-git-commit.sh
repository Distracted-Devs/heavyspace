#!/bin/bash
# Reads the hook's JSON input from stdin and pulls out the Bash command
COMMAND=$(jq -r '.tool_input.command // empty')

# Deliberately broad: matches "git commit", "git -C dir commit", "x && git commit -m ..."
if echo "$COMMAND" | grep -Eq '(^|[^[:alnum:]_-])git\b.*\bcommit\b'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "git commit is blocked in this project. Stage the changes and leave committing to the user."
    }
  }'
  exit 0
fi

exit 0
