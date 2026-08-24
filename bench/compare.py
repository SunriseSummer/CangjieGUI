#!/usr/bin/env python3
"""Compare two groups of CUI ``@@RESULT`` benchmark captures.

The default aggregation is the median of independent captures.  ``--aggregate min`` keeps the
historical best-of-N behaviour for one-sided scheduler noise, but median is the safer general
default because a single unusually fast sample cannot dominate an A/B result.
"""

import argparse
import statistics
import sys
from pathlib import Path


def parse_capture(path):
    """Return one capture as ``{kind|group|name: ns}``, rejecting duplicate/invalid records."""
    records = {}
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        if not line.startswith("@@RESULT"):
            continue
        parts = line.strip().split("|")
        if len(parts) != 6:
            raise ValueError(f"malformed benchmark result in {path}: {line}")
        key = "|".join(parts[1:4])
        if key in records:
            raise ValueError(f"duplicate benchmark result in {path}: {key}")
        try:
            ns = int(parts[4])
            iterations = int(parts[5])
        except ValueError as exc:
            raise ValueError(f"non-numeric benchmark result in {path}: {line}") from exc
        if ns < 0 or iterations <= 0:
            raise ValueError(f"invalid benchmark result range in {path}: {line}")
        records[key] = ns
    return records


def load_side(paths, aggregate="median"):
    """Aggregate captures after requiring every file on one side to contain the same cases."""
    captures = [parse_capture(path) for path in paths]
    if not captures:
        raise ValueError("at least one capture is required on each side")
    keys = list(captures[0])
    expected = set(keys)
    for capture in captures[1:]:
        if set(capture) != expected:
            raise ValueError("benchmark result keys differ between captures on the same side")
    reducer = min if aggregate == "min" else statistics.median
    return {key: int(reducer(capture[key] for capture in captures)) for key in keys}


def compare_sides(side_a, side_b):
    """Return ratio rows plus keys found on only one side."""
    rows = []
    for key in set(side_a) & set(side_b):
        a, b = side_a[key], side_b[key]
        rows.append((key, a, b, b / a if a > 0 else float("inf")))
    rows.sort(key=lambda row: (-row[3], row[0]))
    return rows, sorted(set(side_a) - set(side_b)), sorted(set(side_b) - set(side_a))


def fmt(ns):
    if ns < 10_000:
        return f"{ns:.0f} ns"
    if ns < 10_000_000:
        return f"{ns / 1000:.2f} us"
    return f"{ns / 1_000_000:.3f} ms"


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="对比两组 @@RESULT 性能采集")
    parser.add_argument("--a", nargs="+", required=True, help="A 侧采集文件（基准侧）")
    parser.add_argument("--b", nargs="+", required=True, help="B 侧采集文件（对比侧）")
    parser.add_argument("--threshold", type=float, default=1.25, help="标记阈值（默认 1.25）")
    parser.add_argument("--aggregate", choices=("median", "min"), default="median",
                        help="同侧多文件聚合方式（默认 median）")
    args = parser.parse_args()
    if args.threshold <= 1.0:
        parser.error("--threshold must be greater than 1")

    side_a = load_side(args.a, args.aggregate)
    side_b = load_side(args.b, args.aggregate)
    rows, only_a, only_b = compare_sides(side_a, side_b)
    if not rows:
        print("两侧没有共同用例。")
        return 2

    median_ratio = statistics.median(row[3] for row in rows)
    print(f"共同用例 {len(rows)} 个 ｜ B/A 中位比值 {median_ratio:.2f}x ｜ 同侧聚合 {args.aggregate}")
    print(f"标记阈值：慢于 {args.threshold:.2f}x 记 [SLOWER]，快于 {1 / args.threshold:.2f}x 记 [FASTER]\n")
    width = max(len(row[0]) for row in rows)
    slower = 0
    for key, a, b, ratio in rows:
        mark = ""
        if ratio > args.threshold:
            mark = "  [SLOWER]"
            slower += 1
        elif ratio < 1 / args.threshold:
            mark = "  [FASTER]"
        print(f"  {key.ljust(width)}  {fmt(a):>11} -> {fmt(b):>11}   {ratio:5.2f}x{mark}")

    for label, keys, side in (("仅 A 侧", only_a, side_a), ("仅 B 侧", only_b, side_b)):
        if keys:
            print(f"\n{label}有的用例（{len(keys)} 个）：")
            for key in keys:
                print(f"  {key}  {fmt(side[key])}")
    return 1 if slower else 0


if __name__ == "__main__":
    try:
        exit_code = main()
    except (OSError, ValueError) as exc:
        print(f"Benchmark comparison failed: {exc}", file=sys.stderr)
        exit_code = 2
    sys.exit(exit_code)
