#!/usr/bin/env python3
"""Run the real-window DesktopApp lifecycle contract on the executable's main thread."""

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from process_runner import run_command
from snapshot_tool import diff_images

ROOT = Path(__file__).resolve().parent.parent
FIXTURE = ROOT / ".devtools" / "fixtures" / "desktop_lifecycle"
REPORT = ROOT / "target" / "test-package-results" / "desktop-lifecycle.json"
PASS_MARKER = "@@DESKTOP_LIFECYCLE|passed"
DAMAGE_INCREMENTAL = FIXTURE / "retained-damage.bmp"
DAMAGE_FULL = FIXTURE / "retained-full.bmp"
SCENARIOS = ("retained-damage", "automatic-partial", "automatic-fallback", "lifecycle")


def run_stage(command, timeout):
    started = time.perf_counter()
    code, stdout, stderr, timed_out = run_command(command, FIXTURE, timeout)
    log = stdout + stderr
    if timed_out:
        log += f"\nTimed out after {timeout}s; process tree terminated"
    return code, time.perf_counter() - started, log


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repeat", type=int, default=1,
                        help="run the already-built real-window fixture N times (default 1)")
    parser.add_argument("--timeout", type=int, default=120,
                        help="timeout for build and each fixture run in seconds (default 120)")
    args = parser.parse_args(argv)
    if args.repeat < 1:
        parser.error("--repeat must be at least 1")
    if args.timeout < 1:
        parser.error("--timeout must be at least 1")
    return args


def compare_damage(run_log):
    damage_diff = {"pixels": -1, "max_delta": -1, "bbox": None}
    damage_ok = False
    if DAMAGE_INCREMENTAL.exists() and DAMAGE_FULL.exists():
        try:
            differing, max_delta, bbox = diff_images(DAMAGE_INCREMENTAL, DAMAGE_FULL, tolerance=0)
            damage_diff = {"pixels": differing, "max_delta": max_delta, "bbox": bbox}
            damage_ok = differing == 0
        except (OSError, ValueError) as exc:
            run_log += f"\nRetained damage comparison failed: {exc}"
    else:
        run_log += "\nRetained damage fixture did not produce both BMP files"
    return damage_ok, damage_diff, run_log


def main():
    args = parse_args()
    build_command = ["cjpm", "build"]
    build_code, build_seconds, build_log = run_stage(build_command, args.timeout)
    runs = []
    if build_code == 0:
        for index in range(args.repeat):
            DAMAGE_INCREMENTAL.unlink(missing_ok=True)
            DAMAGE_FULL.unlink(missing_ok=True)
            scenario_runs = []
            run_log = ""
            run_seconds = 0.0
            for scenario in SCENARIOS:
                command = ["cjpm", "run", "--skip-build", "--run-args", scenario]
                scenario_code, scenario_seconds, scenario_log = run_stage(command, args.timeout)
                scenario_ok = scenario_code == 0 and PASS_MARKER in scenario_log
                scenario_runs.append({
                    "scenario": scenario,
                    "command": command,
                    "returncode": scenario_code,
                    "seconds": scenario_seconds,
                    "log": scenario_log,
                    "ok": scenario_ok,
                })
                run_seconds += scenario_seconds
                run_log += f"\n@@DESKTOP_SCENARIO|{scenario}\n{scenario_log}"
                if not scenario_ok:
                    break
            all_scenarios_ok = len(scenario_runs) == len(SCENARIOS) and all(
                scenario["ok"] for scenario in scenario_runs)
            run_code = 0 if all_scenarios_ok else (scenario_runs[-1]["returncode"] or 1)
            damage_ok, damage_diff, run_log = compare_damage(run_log)
            run_ok = run_code == 0 and damage_ok
            runs.append({
                "index": index + 1,
                "command": ["isolated desktop scenarios"],
                "returncode": run_code,
                "seconds": run_seconds,
                "log": run_log,
                "scenarios": scenario_runs,
                "retained_damage": {"ok": damage_ok, **damage_diff},
                "ok": run_ok,
            })
            if args.repeat > 1:
                print(f"[{'OK' if run_ok else 'FAIL'}] desktop-lifecycle run {index + 1}/{args.repeat} "
                      f"{run_seconds:7.2f}s")
            if not run_ok:
                break
    if not runs:
        runs.append({
            "index": 0,
            "command": ["isolated desktop scenarios"],
            "returncode": 127,
            "seconds": 0.0,
            "log": "not run because build failed",
            "retained_damage": {"ok": False, "pixels": -1, "max_delta": -1, "bbox": None},
            "ok": False,
        })
    last_run = runs[-1]
    ok = build_code == 0 and len(runs) == args.repeat and all(run["ok"] for run in runs)
    total_seconds = build_seconds + sum(run["seconds"] for run in runs)

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "ok": ok,
        "repeat": args.repeat,
        "build": {"command": build_command, "returncode": build_code,
                  "seconds": build_seconds, "log": build_log},
        "run": {key: last_run[key] for key in ("command", "returncode", "seconds", "log")},
        "runs": runs,
        "retained_damage": last_run["retained_damage"],
    }, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"[{'OK' if ok else 'FAIL'}] desktop-lifecycle {total_seconds:7.2f}s; "
          f"report: {REPORT.relative_to(ROOT)}")
    if last_run["retained_damage"]["ok"]:
        print("[OK] retained-damage incremental/full pixel diff: 0")
    if not ok:
        print("\n".join((build_log + last_run["log"]).strip().splitlines()[-16:]))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
