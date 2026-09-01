#!/usr/bin/env python3
"""Build/test CUI examples as end-to-end guards, with optional real-window snapshots.

Examples are executable applications rather than snippets, so this runner treats every directory
containing cjpm.toml as an independent public-API/E2E case. It runs without third-party packages,
keeps subprocess output per case, writes a machine-readable JSON report, and can compare selected
real-render snapshots with BMP baselines through snapshot_tool.py.

Typical use:
    python .devtools/test_examples.py                         # test every example
    python .devtools/test_examples.py --action build --jobs 4
    python .devtools/test_examples.py contacts planner --snapshot
    python .devtools/test_examples.py --smoke-snapshots
    python .devtools/test_examples.py --smoke-snapshots --retained-diff
    python .devtools/test_examples.py --changed origin/main
    python .devtools/test_examples.py contacts --snapshot --baseline .snapbase
"""

import argparse
import json
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from snapshot_tool import diff_images
from process_runner import run_command

ROOT = Path(__file__).resolve().parent.parent
EXAMPLES = ROOT / "examples"
RESULTS = EXAMPLES / ".e2e-results"

# Small but deliberately cross-cutting real-render fleet. The full build/test fleet remains every
# example; these are the costly open-window snapshots used for a quick feature smoke.
SMOKE_SNAPSHOTS = {
    "cangcui": "custom canvas/geometry",
    "contacts": "modal + nested combo/context overlays",
    "data_table": "virtualized table/sort/keyboard",
    "fonts": "font metrics + segmented-control overflow",
    "notepad": "text editing + desktop integration",
    "planner": "dense layout/animation/form controls",
    "process_manager": "background mailbox + platform APIs",
    "stats": "transparent retained command-buffer replay",
}


@dataclass
class CaseResult:
    name: str
    action: str
    ok: bool
    seconds: float
    returncode: int
    command: list
    log: str
    snapshot: str = ""
    snapshot_diff_pixels: int = 0
    snapshot_max_delta: int = 0
    snapshot_note: str = ""


def example_dirs(names):
    available = {p.name: p for p in EXAMPLES.iterdir() if p.is_dir() and (p / "cjpm.toml").exists()}
    if names is None:
        return [available[name] for name in sorted(available)]
    missing = sorted(set(names) - set(available))
    if missing:
        raise ValueError("unknown examples: " + ", ".join(missing))
    return [available[name] for name in names]


def select_changed_paths(paths):
    """Return None for shared changes (full fleet), or the exact changed example names."""
    shared = any(not (len(path.parts) >= 2 and path.parts[0] == "examples") for path in paths)
    if shared:
        return None
    return sorted({path.parts[1] for path in paths if len(path.parts) >= 2})


def changed_names(base):
    proc = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...HEAD"], cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if proc.returncode:
        raise RuntimeError(proc.stderr.strip() or f"git diff failed ({proc.returncode})")
    paths = [Path(line.strip()) for line in proc.stdout.splitlines() if line.strip()]
    # Framework-facing changes can affect every executable; example-only changes narrow to those
    # apps. None means full fleet, while [] correctly means there were no changed examples.
    return select_changed_paths(paths)


def run_process(example, action, timeout):
    command = ["cjpm", action]
    if action == "test":
        command += ["--no-progress"]
    started = time.perf_counter()
    returncode, stdout, stderr, timed_out = run_command(command, example, timeout)
    log = stdout + stderr
    if timed_out:
        log += f"\nTimed out after {timeout}s; process tree terminated"
    return CaseResult(example.name, action, returncode == 0, time.perf_counter() - started,
                      returncode, command, log)


def snapshot_command(shot, force_full=False):
    """Build the platform-neutral cjpm command used by snapshot and differential runs."""
    run_args = f'--snapshot "{shot}"'
    if force_full:
        run_args += " --cui-force-full-retained"
    # `cjpm test` does not refresh the runnable application artifact. The first snapshot must build
    # it, otherwise a source change can be compared through a stale executable. The immediately
    # following full-retained run safely reuses that exact binary.
    command = ["cjpm", "run"]
    if force_full:
        command.append("--skip-build")
    command += ["--run-args", run_args]
    return command


def snapshot_case(example, timeout, baseline, tolerance, force_full=False):
    RESULTS.mkdir(parents=True, exist_ok=True)
    suffix = ".full-retained" if force_full else ""
    shot = RESULTS / f"{example.name}{suffix}.bmp"
    shot.unlink(missing_ok=True)
    command = snapshot_command(shot, force_full)
    started = time.perf_counter()
    returncode, stdout, stderr, timed_out = run_command(command, example, timeout)
    log = stdout + stderr
    if timed_out:
        log += f"\nTimed out after {timeout}s; process tree terminated"
    ok = returncode == 0 and shot.exists()
    action = "retained-diff" if force_full else "snapshot"
    result = CaseResult(example.name, action, ok, time.perf_counter() - started,
                        returncode, command, log, snapshot=str(shot.relative_to(ROOT)))
    if ok and baseline:
        reference = baseline / shot.name
        if not reference.exists():
            result.ok = False
            result.snapshot_note = f"missing baseline {reference}"
        else:
            try:
                differing, max_delta, bbox = diff_images(reference, shot, tolerance=tolerance)
                result.snapshot_diff_pixels = differing
                result.snapshot_max_delta = max_delta
                result.snapshot_note = "identical" if differing == 0 else f"diff bbox {bbox}"
                result.ok = differing == 0
            except (OSError, ValueError) as exc:
                result.ok = False
                result.snapshot_note = f"snapshot comparison failed: {exc}"
    return result


def tail(text, lines=8):
    return "\n".join(text.strip().splitlines()[-lines:])


def write_report(results, selected, args):
    RESULTS.mkdir(parents=True, exist_ok=True)
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "root": str(ROOT),
        "selected": [p.name for p in selected],
        "feature_smoke": SMOKE_SNAPSHOTS,
        "arguments": vars(args),
        "summary": {
            "total": len(results),
            "passed": sum(result.ok for result in results),
            "failed": sum(not result.ok for result in results),
            "seconds": round(sum(result.seconds for result in results), 3),
        },
        "cases": [asdict(result) for result in results],
    }
    # Path arguments are not JSON serializable in vars(args).
    report["arguments"] = {key: str(value) if isinstance(value, Path) else value
                           for key, value in report["arguments"].items()}
    path = RESULTS / report_filename(args)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def report_filename(args):
    """Keep expensive full-consumer and real-window evidence from overwriting each other."""
    if args.smoke_snapshots:
        return "smoke-report.json"
    if args.snapshot:
        return "snapshot-report.json"
    return "report.json"


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Run examples as CUI end-to-end tests")
    parser.add_argument("names", nargs="*", help="example names; default is every example")
    parser.add_argument("--action", choices=("build", "test"), default="test")
    parser.add_argument("--jobs", type=int, default=2, help="parallel cjpm processes (default 2)")
    parser.add_argument("--timeout", type=int, default=300, help="per-case timeout seconds")
    parser.add_argument("--changed", metavar="BASE", help="only examples changed since BASE; shared changes run all")
    parser.add_argument("--snapshot", action="store_true", help="snapshot every selected example after its gate")
    parser.add_argument("--smoke-snapshots", action="store_true", help="run the cross-feature snapshot fleet")
    parser.add_argument("--retained-diff", action="store_true",
                        help="compare incremental snapshots with forced-full retained execution")
    parser.add_argument("--baseline", type=Path, help="optional BMP baseline directory")
    parser.add_argument("--tolerance", type=int, default=2, help="snapshot per-channel tolerance")
    args = parser.parse_args()

    if args.jobs <= 0:
        parser.error("--jobs must be greater than zero")
    if args.timeout <= 0:
        parser.error("--timeout must be greater than zero")
    if not 0 <= args.tolerance <= 255:
        parser.error("--tolerance must be between 0 and 255")
    if args.changed and args.names:
        parser.error("example names cannot be combined with --changed")
    if args.smoke_snapshots and args.names:
        parser.error("example names cannot be combined with --smoke-snapshots")
    if args.baseline and not (args.snapshot or args.smoke_snapshots):
        parser.error("--baseline requires --snapshot or --smoke-snapshots")
    if args.retained_diff:
        args.snapshot = True

    names = args.names or None
    if args.changed:
        names = changed_names(args.changed)
    if args.smoke_snapshots:
        names = sorted(SMOKE_SNAPSHOTS)
        args.snapshot = True
    try:
        selected = example_dirs(names)
    except ValueError as exc:
        parser.error(str(exc))

    results = []
    if not selected:
        print("No changed examples selected; writing an empty successful report.", flush=True)
    workers = max(1, min(args.jobs, len(selected)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(run_process, example, args.action, args.timeout): example
                   for example in selected}
        for future in as_completed(futures):
            example = futures[future]
            try:
                result = future.result()
            except Exception as exc:  # top-level runner boundary: preserve the report on tool defects
                result = CaseResult(example.name, args.action, False, 0.0, 127,
                                    ["cjpm", args.action], f"Unexpected runner failure: {exc}")
            results.append(result)
            print(f"[{'OK' if result.ok else 'FAIL'}] {result.name:<20} {result.action:<8} {result.seconds:7.2f}s",
                  flush=True)
            if not result.ok:
                print(tail(result.log))

    if args.snapshot:
        for example in selected:
            # A failed build/test is already actionable; do not obscure it with a launch failure.
            gate = next(result for result in results if result.name == example.name and result.action == args.action)
            if not gate.ok:
                continue
            try:
                result = snapshot_case(example, args.timeout, args.baseline, args.tolerance)
            except Exception as exc:  # top-level runner boundary: preserve the report on tool defects
                result = CaseResult(example.name, "snapshot", False, 0.0, 127,
                                    ["cjpm", "run"], f"Unexpected snapshot runner failure: {exc}")
            results.append(result)
            note = f" ({result.snapshot_note})" if result.snapshot_note else ""
            print(f"[{'OK' if result.ok else 'FAIL'}] {result.name:<20} snapshot {result.seconds:7.2f}s{note}",
                  flush=True)
            if not result.ok:
                print(tail(result.log))

            if result.ok and args.retained_diff:
                try:
                    differential = snapshot_case(example, args.timeout, None, args.tolerance, force_full=True)
                    if differential.ok:
                        incremental_path = ROOT / result.snapshot
                        full_path = ROOT / differential.snapshot
                        differing, max_delta, bbox = diff_images(
                            incremental_path, full_path, tolerance=args.tolerance)
                        differential.snapshot_diff_pixels = differing
                        differential.snapshot_max_delta = max_delta
                        differential.snapshot_note = (
                            "incremental/full within tolerance" if differing == 0 else
                            f"incremental/full diff bbox {bbox}")
                        differential.ok = differing == 0
                except Exception as exc:  # preserve all other example results on differential defects
                    differential = CaseResult(example.name, "retained-diff", False, 0.0, 127,
                                              ["cjpm", "run"], f"Unexpected retained diff failure: {exc}")
                results.append(differential)
                diff_note = f" ({differential.snapshot_note})" if differential.snapshot_note else ""
                print(f"[{'OK' if differential.ok else 'FAIL'}] {differential.name:<20} retained-diff "
                      f"{differential.seconds:7.2f}s{diff_note}", flush=True)
                if not differential.ok:
                    print(tail(differential.log))

    results.sort(key=lambda item: (item.name, item.action))
    report = write_report(results, selected, args)
    failed = [result for result in results if not result.ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} gates passed; report: {report.relative_to(ROOT)}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
