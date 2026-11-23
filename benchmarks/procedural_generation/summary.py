"""Prints a Markdown table of sweep.sh results.

Usage: python3 summary.py results.jsonl
Times are in ms. "own" is the streamer, pool and tint together, and "frame"
the whole headless frame.
"""

import json
import sys


def scenario(row):
    args = row["args"]
    name = args.get("scenario", "orbit")
    return f"fly {args.get('speed', '300')}" if name == "fly" else name


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    print(
        "| setting | scenario | contracts | systems | ring | own mean | "
        "own p95 | own worst | frame mean | frame p95 | frame worst | "
        "live max | load |"
    )
    print("|" + "---|" * 13)
    for row in rows:
        own, frame = row["own"], row["frame"]
        contracts = "on" if row["args"].get("contracts", "1") == "1" else "off"
        print(
            f"| {row['label']} | {scenario(row)} | {contracts} | "
            f"{row['systems']} | {row['home_ring']} | "
            f"{own['mean']:.2f} | {own['p95']:.2f} | {own['worst']:.2f} | "
            f"{frame['mean']:.2f} | {frame['p95']:.2f} | "
            f"{frame['worst']:.2f} | {row['live']['max']} | "
            f"{row['load_ms']:.0f} |"
        )


if __name__ == "__main__":
    main(sys.argv[1])
