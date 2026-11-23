#!/bin/bash
# Quick A/B check: runs each scenario REPEATS times (default 3) with
# contracts off and prints the mean of each run's mean, p95 and worst for
# "own" (streamer and pool) and "frame".
# Usage: benchmarks/procedural_generation/ab.sh [key=value ...]
set -uo pipefail
cd "$(dirname "$0")/../.."
REPEATS="${REPEATS:-3}"
for scenario in "scenario=orbit" "scenario=ring" "scenario=fly speed=300"; do
	read -ra words <<< "$scenario"
	for _ in $(seq "$REPEATS"); do
		godot --headless --fixed-fps 60 \
			-s benchmarks/procedural_generation/bench.gd -- \
			contracts=0 "${words[@]}" "$@" 2>&1 | grep '^RESULT ' | cut -c8-
	done | jq -s -r --arg s "$scenario" '
		def avg(f): (map(f) | add / length * 100 | round / 100);
		"\($s): own \(avg(.own.mean)) / \(avg(.own.p95)) / \(avg(.own.worst))"
		+ ", frame \(avg(.frame.mean)) / \(avg(.frame.p95))"
		+ " / \(avg(.frame.worst)) (mean / p95 / worst ms)"'
done
