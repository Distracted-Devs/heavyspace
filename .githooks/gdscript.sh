# Shared settings for the GDScript hooks. Sourced, not run.

MAX_LINE_LENGTH=80

formatter="${GDSCRIPT_FORMATTER:-$(command -v gdscript-formatter)}"
if [ -z "$formatter" ] || [ ! -x "$formatter" ]; then
	echo "gdscript-formatter not found. Install it or set GDSCRIPT_FORMATTER." >&2
	exit 1
fi
