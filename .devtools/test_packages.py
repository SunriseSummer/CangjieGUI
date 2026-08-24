#!/usr/bin/env python3
"""Run each CUI package in an isolated cjpm test process with a hard timeout.

The Cangjie aggregate test runner can retain process-wide native/runtime state between packages.
Package isolation makes teardown failures attributable, prevents one package from stalling every
result, and still writes a single machine-readable report for CI and local diagnosis.
"""

import argparse
import json
import os
import re
import shutil
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from process_runner import run_command

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "src"
REPORT = ROOT / "target" / "test-package-results" / "report.json"
SUMMARY_PATTERN = re.compile(
    r"Summary:\s+TOTAL:\s*(\d+).*?PASSED:\s*(\d+),\s*SKIPPED:\s*(\d+),\s*"
    r"ERROR:\s*(\d+).*?FAILED:\s*(\d+)",
    re.DOTALL,
)


@dataclass
class PackageResult:
    name: str
    ok: bool
    seconds: float
    returncode: int
    total: int
    passed: int
    skipped: int
    errors: int
    failed: int
    prepare_command: list
    command: list
    log: str
    coverage_path: str = ""
    coverage_report: str = ""


def discover_packages():
    return sorted(
        path.name for path in SOURCE.iterdir()
        if path.is_dir() and any(path.glob("*.cj"))
    )


def parse_summary(log):
    matches = list(SUMMARY_PATTERN.finditer(log))
    if not matches:
        raise ValueError("cjpm output contains no test summary")
    return tuple(int(value) for value in matches[-1].groups())


def package_build_command(name, coverage=False):
    command = ["cjpm", "test", str(Path("src") / name), "--no-run", "--no-progress", "--no-color"]
    if coverage:
        command.append("--coverage")
    return command


def package_command(name, coverage=False):
    # Immediate case output makes an external timeout identify the last completed test instead of
    # returning an empty, fully buffered log. A single test worker also keeps process-global SDL
    # and the framework's documented single UI-build thread contract deterministic within a package.
    command = ["cjpm", "test", str(Path("src") / name), "--skip-build", "--no-progress", "--no-color",
               "--no-capture-output", "--parallel", "1"]
    if coverage:
        command.append("--coverage")
    return command


def coverage_environment(directory):
    """Redirect gcov counters so incompatible package binaries never merge the same file."""
    environment = os.environ.copy()
    environment["GCOV_PREFIX"] = str(directory)
    environment["GCOV_PREFIX_STRIP"] = "100"
    return environment


def stage_coverage_inputs(name, counter_directory, staging_directory):
    """Pair this package's build graph with its isolated counters for cjcov 1.0.5."""
    metadata_directory = ROOT / "cov_output" / f"cui.{name}"
    if not metadata_directory.is_dir():
        raise FileNotFoundError(f"coverage metadata directory does not exist: {metadata_directory}")

    staging_directory.mkdir(parents=True, exist_ok=True)
    graph_count = 0
    counter_count = 0
    for source in metadata_directory.glob("*.gcno"):
        if "$test" not in source.name:
            shutil.copy2(source, staging_directory / source.name)
            graph_count += 1
    for source in counter_directory.glob("*.gcda"):
        if "$test" not in source.name:
            shutil.copy2(source, staging_directory / source.name)
            counter_count += 1
    if graph_count == 0 or counter_count == 0:
        raise FileNotFoundError(
            f"coverage staging requires gcno and gcda inputs; found {graph_count} graph(s) "
            f"and {counter_count} counter(s)")
    return graph_count, counter_count


def normalize_coverage_sources(report, staging_directory):
    """Convert cjcov staging-relative source paths to stable project-relative paths."""
    payload = json.loads(report.read_text(encoding="utf-8"))
    for entry in payload.get("fileLists", []):
        source = entry.get("filepath", "")
        if not source:
            continue
        candidate = Path(source)
        if not candidate.is_absolute():
            source_candidate = SOURCE / candidate
            candidate = (source_candidate if source_candidate.exists()
                         else staging_directory / candidate)
        resolved = candidate.resolve()
        try:
            entry["filepath"] = resolved.relative_to(ROOT).as_posix()
        except ValueError:
            entry["filepath"] = resolved.as_posix()
    report.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def generate_coverage_report(name, counter_directory, coverage_root, timeout):
    """Stage matching gcov inputs, then report while this package build is current."""
    staging_directory = coverage_root / "staging" / name
    report_directory = coverage_root / "reports" / name
    report_directory.parent.mkdir(parents=True, exist_ok=True)
    try:
        graph_count, counter_count = stage_coverage_inputs(
            name, counter_directory, staging_directory)
    except (FileNotFoundError, OSError) as exc:
        return "", f"\nCoverage staging failed: {exc}"
    command = [
        "cjcov", "-r", str(staging_directory), "-s", str(SOURCE),
        "-o", str(report_directory), "-j",
    ]
    code, stdout, stderr, timed_out = run_command(command, ROOT, timeout)
    log = (f"\nCoverage staging: {graph_count} graph(s), {counter_count} counter(s)\n"
           + stdout + stderr)
    if timed_out:
        log += f"\nCoverage report timed out after {timeout}s; process tree terminated"
    report = report_directory / "coverage.json"
    if code != 0 or not report.is_file():
        return "", log or "cjcov did not create coverage.json"
    try:
        normalize_coverage_sources(report, staging_directory)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return "", log + f"\nCoverage source normalization failed: {exc}"
    return str(report.relative_to(ROOT)), log


def aggregate_coverage(results):
    """Merge per-package hit lines; excludes tests and adjacent dependency sources."""
    totals = {}
    hits = {}
    for result in results:
        if not result.coverage_report:
            continue
        payload = json.loads((ROOT / result.coverage_report).read_text(encoding="utf-8"))
        for entry in payload.get("fileLists", []):
            source = entry.get("filepath", "").replace("\\", "/")
            if not source.startswith("src/") or source.endswith("_test.cj"):
                continue
            totals[source] = max(totals.get(source, 0), int(entry.get("totalLines", 0)))
            hits.setdefault(source, set()).update(int(line) for line in entry.get("hitLines", []))

    def summarize(paths):
        total = sum(totals[path] for path in paths)
        hit = sum(len(hits.get(path, set())) for path in paths)
        return {
            "files": len(paths),
            "hit_lines": hit,
            "total_lines": total,
            "percent": round(hit * 100.0 / total, 2) if total > 0 else 0.0,
        }

    paths = sorted(totals)
    packages = {}
    for name in discover_packages():
        prefix = f"src/{name}/"
        package_paths = [path for path in paths if path.startswith(prefix)]
        packages[name] = summarize(package_paths)
    root_paths = [path for path in paths if path.count("/") == 1]
    if root_paths:
        packages["root"] = summarize(root_paths)
    return {
        "method": "union of per-package cjcov production-source hit lines",
        "limitations": [
            "Cangjie 1.0.5 can attribute inlined production code to $test graphs, so the "
            "reported percentage is a conservative tool observation rather than proof that "
            "zero-hit production APIs were not exercised.",
        ],
        "overall": summarize(paths),
        "packages": packages,
    }


def run_package(name, timeout, coverage=False, coverage_root=None):
    prepare_command = package_build_command(name, coverage)
    command = package_command(name, coverage)
    environment = None
    coverage_path = ""
    coverage_report = ""
    if coverage:
        if coverage_root is None:
            coverage_root = REPORT.parent / "coverage" / str(time.time_ns())
        coverage_directory = coverage_root / name
        coverage_directory.mkdir(parents=True, exist_ok=True)
        environment = coverage_environment(coverage_directory)
        coverage_path = str(coverage_directory.relative_to(ROOT))
    started = time.perf_counter()
    prepare_code, prepare_stdout, prepare_stderr, prepare_timed_out = run_command(
        prepare_command, ROOT, timeout, env=environment)
    prepare_log = prepare_stdout + prepare_stderr
    if prepare_timed_out:
        prepare_log += f"\nBuild timed out after {timeout}s; process tree terminated"
    if prepare_code != 0:
        prepare_log += "\nPackage tests were not launched because their build failed"
        return PackageResult(name, False, time.perf_counter() - started, prepare_code, 0, 0, 0,
                             1, 0, prepare_command, command, prepare_log, coverage_path, coverage_report)
    returncode, stdout, stderr, timed_out = run_command(command, ROOT, timeout, env=environment)
    log = prepare_log + stdout + stderr
    if timed_out:
        log += f"\nTimed out after {timeout}s; process tree terminated"
    try:
        total, passed, skipped, errors, failed = parse_summary(log)
    except ValueError as exc:
        total, passed, skipped, errors, failed = 0, 0, 0, 1, 0
        log += f"\n{exc}"
    ok = returncode == 0 and errors == 0 and failed == 0 and passed + skipped == total
    if coverage and ok:
        coverage_report, coverage_log = generate_coverage_report(
            name, coverage_root / name, coverage_root, timeout)
        log += coverage_log
        if not coverage_report:
            errors += 1
            ok = False
    return PackageResult(name, ok, time.perf_counter() - started, returncode, total, passed,
                         skipped, errors, failed, prepare_command, command, log, coverage_path, coverage_report)


def tail(text, lines=12):
    return "\n".join(text.strip().splitlines()[-lines:])


def write_report(results, coverage, minimum_line_coverage=None):
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "coverage": coverage,
        "summary": {
            "packages": len(results),
            "passed_packages": sum(result.ok for result in results),
            "tests": sum(result.total for result in results),
            "passed_tests": sum(result.passed for result in results),
            "failed_tests": sum(result.failed + result.errors for result in results),
            "seconds": round(sum(result.seconds for result in results), 3),
        },
        "packages": [asdict(result) for result in results],
    }
    if coverage:
        line_coverage = aggregate_coverage(results)
        payload["line_coverage"] = line_coverage
        if minimum_line_coverage is not None:
            observed = line_coverage["overall"]["percent"]
            payload["coverage_gate"] = {
                "minimum_percent": minimum_line_coverage,
                "observed_percent": observed,
                "passed": observed >= minimum_line_coverage,
            }
    REPORT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return payload


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    available = discover_packages()
    parser = argparse.ArgumentParser(description="Run CUI packages in isolated test processes")
    parser.add_argument("packages", nargs="*", help="package directory names; default is every package")
    parser.add_argument("--coverage", action="store_true", help="enable Cangjie source coverage")
    parser.add_argument("--min-line-coverage", type=float,
                        help="fail when observable production line coverage is below this percentage")
    parser.add_argument("--timeout", type=int, default=300, help="per-package timeout seconds")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be greater than zero")
    if args.min_line_coverage is not None:
        if not args.coverage:
            parser.error("--min-line-coverage requires --coverage")
        if args.min_line_coverage < 0.0 or args.min_line_coverage > 100.0:
            parser.error("--min-line-coverage must be between 0 and 100")
    unknown = sorted(set(args.packages) - set(available))
    if unknown:
        parser.error("unknown packages: " + ", ".join(unknown))

    selected = args.packages or available
    coverage_root = REPORT.parent / "coverage" / str(time.time_ns()) if args.coverage else None
    results = []
    for name in selected:
        result = run_package(name, args.timeout, args.coverage, coverage_root)
        results.append(result)
        print(f"[{'OK' if result.ok else 'FAIL'}] {name:<10} {result.passed:>3}/{result.total:<3} "
              f"{result.seconds:7.2f}s", flush=True)
        if not result.ok:
            print(tail(result.log), flush=True)

    payload = write_report(results, args.coverage, args.min_line_coverage)
    passed = sum(result.ok for result in results)
    tests = sum(result.total for result in results)
    print(f"\n{passed}/{len(results)} packages, {tests} tests; report: {REPORT.relative_to(ROOT)}")
    if args.coverage and passed == len(results):
        coverage = payload["line_coverage"]["overall"]
        print(f"Production line coverage: {coverage['hit_lines']}/{coverage['total_lines']} "
              f"({coverage['percent']:.2f}%) across {coverage['files']} files")
    coverage_gate = payload.get("coverage_gate", {"passed": True})
    if not coverage_gate["passed"]:
        print(f"Coverage gate failed: {coverage_gate['observed_percent']:.2f}% < "
              f"{coverage_gate['minimum_percent']:.2f}%")
    return 0 if passed == len(results) and coverage_gate["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
