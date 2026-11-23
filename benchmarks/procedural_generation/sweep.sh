#!/bin/bash
# Runs the benchmark over a range of settings, one change at a time from the
# tuned values, for each scenario with contracts on and off.
# Usage: benchmarks/procedural_generation/sweep.sh [out.jsonl]
# Then: python3 benchmarks/procedural_generation/summary.py out.jsonl

set -uo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:-benchmarks/procedural_generation/results.jsonl}"
: > "$OUT"

# label|key=value ...
CONFIGS=(
	"tuned|"
	"systems x0.25|systems.spawn_density=1.9e-10"
	"systems x0.5|systems.spawn_density=3.8e-10"
	"systems x1.8|systems.cell_size=600 systems.spawn_density=1.38e-9"
	"rings x0.25|rings.spawn_density=1.9e-4"
	"rings x0.5|rings.spawn_density=3.8e-4"
	"rings x1.8 dense|rings.cell_size=6 rings.spawn_density=1.38e-3"
	"rings x3 wide|rings.orbit_outer=4"
	"rings x6.5 wide|rings.orbit_outer=5.5"
	"ring expand 1000|rings.expand_distance=1000 rings.collapse_distance=1500"
	"ring expand 4000|rings.expand_distance=4000 rings.collapse_distance=6000"
	"ring expand 8000|rings.expand_distance=8000 rings.collapse_distance=12000"
	"ring live 30|rings.live_distance=30 rings.release_distance=45"
	"ring live 120|rings.live_distance=120 rings.release_distance=180"
	"ring live 240|rings.live_distance=240 rings.release_distance=360"
	"system live 1500|systems.live_distance=1500 systems.release_distance=1750"
	"system live 6000|systems.live_distance=6000 systems.release_distance=7000"
)
SCENARIOS=("scenario=orbit" "scenario=ring" "scenario=fly speed=300")
SPEEDS=(100 1000 3000)

run() {
	local label="$1" contracts="$2"
	shift 2
	local line
	line=$(godot --headless --fixed-fps 60 \
		-s benchmarks/procedural_generation/bench.gd -- \
		contracts="$contracts" "$@" 2>&1 | grep '^RESULT ' | cut -c8-)
	if [ -z "$line" ]; then
		echo "failed: $label $*" >&2
		return
	fi
	echo "$line" | jq -c --arg label "$label" '. + {label: $label}' >> "$OUT"
	echo "$label | contracts=$contracts $*"
}

for contracts in 1 0; do
	for config in "${CONFIGS[@]}"; do
		label="${config%%|*}"
		read -ra settings <<< "${config#*|}"
		for scenario in "${SCENARIOS[@]}"; do
			read -ra words <<< "$scenario"
			run "$label" "$contracts" "${words[@]}" "${settings[@]}"
		done
	done
	for speed in "${SPEEDS[@]}"; do
		run "fly $speed u/s" "$contracts" scenario=fly speed="$speed"
	done
done
