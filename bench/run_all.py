#!/usr/bin/env python3
"""Run every benchmark-tool self-test and every CUI performance suite.

This is the release/decision command.  ``run.py`` remains the fast daily benchmark, while the
architecture probe stays isolated because its scale curves are evidence rather than historical
per-case baseline gates.
"""

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPOSITORY = ROOT.parent
RESULTS = ROOT / "results"


def run_step(label, arguments, cwd=REPOSITORY, use_python=True):
    print(f"\n== {label} ==", flush=True)
    started = time.perf_counter()
    command = [sys.executable, *arguments] if use_python else arguments
    completed = subprocess.run(command, cwd=cwd)
    return {
        "label": label,
        "command": command,
        "exitCode": completed.returncode,
        "seconds": round(time.perf_counter() - started, 3),
    }


def main():
    parser = argparse.ArgumentParser(description="Run the complete CUI performance verification matrix.")
    parser.add_argument("--samples", type=int, default=5, help="independent samples per suite (default 5)")
    parser.add_argument("--timeout", type=int, default=600, help="timeout passed to each benchmark process")
    parser.add_argument("--display", action="store_true", help="include real-window GPU/text benchmarks")
    parser.add_argument("--check", action="store_true", help="apply bench/baseline.json regression gate")
    parser.add_argument("--save-baseline", action="store_true",
                        help="save the daily/display suite as the reviewed regression baseline")
    parser.add_argument("--skip-self-tests", action="store_true", help="skip Python benchmark-tool self-tests")
    args = parser.parse_args()
    if args.samples <= 0:
        parser.error("--samples must be greater than zero")
    if args.timeout <= 0:
        parser.error("--timeout must be greater than zero")
    if args.check and args.save_baseline:
        parser.error("--check cannot be combined with --save-baseline")

    steps = []
    tooling_ready = True
    if not args.skip_self_tests:
        for script in ("run_test.py", "compare_test.py", "phase3_probe_test.py"):
            result = run_step(f"tool self-test: {script}", [str(ROOT / script)])
            steps.append(result)
            if result["exitCode"] != 0:
                tooling_ready = False
                break
        if tooling_ready:
            scene_test = run_step("scene driver contract test", ["cjpm", "test"],
                                  cwd=ROOT / "scenes", use_python=False)
            steps.append(scene_test)
            tooling_ready = scene_test["exitCode"] == 0

    if tooling_ready:
        daily = [str(ROOT / "run.py"), "--samples", str(args.samples), "--timeout", str(args.timeout)]
        if args.display:
            daily.append("--display")
        if args.check:
            daily.append("--check")
        if args.save_baseline:
            daily.append("--save-baseline")
        steps.append(run_step("daily/headless and display suite", daily))

    # The architecture suite is independent evidence. A daily regression or an honest inconclusive
    # verdict must not hide it; only a broken self-test/tool contract stops the matrix early.
    if tooling_ready:
        architecture = [str(ROOT / "phase3_probe.py"), "--samples", str(args.samples),
                        "--timeout", str(args.timeout)]
        steps.append(run_step("incremental architecture pressure suite", architecture))

    RESULTS.mkdir(parents=True, exist_ok=True)
    exit_code = next((step["exitCode"] for step in steps if step["exitCode"] != 0), 0)
    summary = {
        "generatedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
        "samples": args.samples,
        "display": args.display,
        "baselineCheck": args.check,
        "baselineSaved": args.save_baseline,
        "exitCode": exit_code,
        "steps": steps,
        "reports": {
            "html": str(RESULTS / "report.html"),
            "json": str(RESULTS / "report.json"),
            "checkJson": str(RESULTS / "check.json"),
            "architectureMarkdown": str(RESULTS / "phase3.md"),
            "architectureJson": str(RESULTS / "phase3.json"),
        },
    }
    summary_path = RESULTS / "suite.json"
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nSuite summary written to {summary_path}")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
