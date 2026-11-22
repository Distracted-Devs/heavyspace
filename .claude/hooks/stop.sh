#!/bin/bash
# Stop: Claude can't finish a turn until the phase's checks pass. After three
# blocked attempts in a row it's let through, and the user sees the failures.

. "$(dirname "$0")/lib.sh"
cat > /dev/null

blocks="$STATE_DIR/stop-blocks"
if report=$("$HOOKS/checks.sh" 2>&1); then
	rm -f "$blocks"
	exit 0
fi

count=$(($(cat "$blocks" 2>/dev/null || echo 0) + 1))
if [ "$count" -gt 3 ]; then
	rm -f "$blocks"
	jq -n --arg report "$report" \
		'{systemMessage: ("Harness checks are still failing after 3 tries:\n" + $report)}'
	exit 0
fi
echo "$count" > "$blocks"
jq -n --arg report "$report" '{decision: "block", reason: $report}'
