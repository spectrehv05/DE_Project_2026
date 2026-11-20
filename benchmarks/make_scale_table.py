#!/usr/bin/env python3
"""Build the Phase 5 results table for docs/05_scalability_report.md.

Reads ONLY the committed benchmark files, so every number in the report matches
the raw plans in benchmarks/results/ (the integrity rule of the project):
    benchmarks/results/optimized/summary.csv   (seed data, CP3)
    benchmarks/results/large/summary.csv       (large data, CP4)

Usage:
    python3 benchmarks/make_scale_table.py            # prints markdown to the screen
    python3 benchmarks/make_scale_table.py > /tmp/table.md

Targets are the ones in README section 5.2 (average of 3 runs).
"""
import csv
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SEED = os.path.join(ROOT, "benchmarks", "results", "optimized", "summary.csv")
LARGE = os.path.join(ROOT, "benchmarks", "results", "large", "summary.csv")

TARGETS = {}
for q in "R01 R02 R03 R05 R06 R07 R15 R16 R25 W01 W02 W03 W05".split():
    TARGETS[q] = (5, "real-time")
for q in "R04 R08 R11 R13 R22 R23".split():
    TARGETS[q] = (250, "interactive")
for q in "R09 R10 R12 R14 R17 R18 R19 R20 R21 R24".split():
    TARGETS[q] = (5000, "reports")
TARGETS["W04"] = (2000, "batch")


def load(path):
    if not os.path.exists(path):
        sys.exit(f"missing {path}: run the benchmark first (see docs/05_scalability_report.md, section 8)")
    with open(path, newline="") as f:
        return {r["query_id"]: r for r in csv.DictReader(f)}


def key(q):
    return (q[0], int(q[1:]))


def main():
    seed, large = load(SEED), load(LARGE)
    rows, groups = [], {"same": [], "linear": [], "super": []}
    met = 0
    for q in sorted(TARGETS, key=key):
        if q not in large:
            sys.exit(f"{q} is missing from {LARGE}")
        s, l = float(seed[q]["avg_ms"]), float(large[q]["avg_ms"])
        growth = l / s if s > 0 else float("inf")
        target, group = TARGETS[q]
        ok = l < target
        met += ok
        if growth < 5:
            groups["same"].append(q)
        elif growth <= 30:
            groups["linear"].append(q)
        else:
            groups["super"].append(q)
        rows.append((q, s, l, growth, target, ok))

    print("| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Target (ms) | Meets target? | If not, what you changed |")
    print("|-------|-----------------------:|------------------------:|----------------------:|------------:|:-------------:|--------------------------|")
    for q, s, l, g, t, ok in rows:
        print(f"| {q} | {s:.3f} | {l:.3f} | {g:.1f}× | < {t:,} | {'Yes' if ok else '**No**'} | {'' if ok else 'TODO: explain / fix, see section 3'} |")
    print()
    print(f"Targets met: **{met} of {len(rows)}**.")
    print()
    print("Growth groups (rule of thumb: under 5x = about the same, 5x to 30x = about 20x, over 30x = more than 20x):")
    print(f"- stayed about the same: {', '.join(groups['same']) or 'none'}")
    print(f"- grew about 20x: {', '.join(groups['linear']) or 'none'}")
    print(f"- grew more than 20x: {', '.join(groups['super']) or 'none'}")
    print()
    print(f"Sum of averages: seed {sum(r[1] for r in rows):.3f} ms, large {sum(r[2] for r in rows):.3f} ms.")


if __name__ == "__main__":
    main()
