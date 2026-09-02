#!/usr/bin/env python3
"""Run isolated phase-three architecture decision probes."""

import argparse
import json
import os
import sys
import time
from datetime import datetime

from bench.tooling.phase3_analysis import (
    aggregate_captures,
    evaluate_evidence,
    machine_lines,
    parse_capture,
    render_markdown,
)
from cui_dev.common.paths import (
    BENCH_RESULTS_ROOT,
    REPOSITORY_ROOT,
    benchmark_build_root,
    workload,
)
from cui_dev.common.process import run_command

PROJECT = workload("diagnostics", "phase3")
RESULTS = BENCH_RESULTS_ROOT
RAW = RESULTS / "phase3.out.txt"
JSON_REPORT = RESULTS / "phase3.json"
MARKDOWN_REPORT = RESULTS / "phase3.md"
WINDOWS_PROJECT_BUILT = False
LAST_WINDOWS_PROBE_END = None
WINDOWS_PROBE_COOLDOWN_SECONDS = 1.0

def run_probe(timeout):
    global LAST_WINDOWS_PROBE_END, WINDOWS_PROJECT_BUILT
    if os.name == "nt":
        if not WINDOWS_PROJECT_BUILT:
            build_code, build_stdout, build_stderr, build_timed_out = run_command(["cjpm", "build"], PROJECT, timeout)
            if build_code != 0:
                suffix = f"; timed out after {timeout}s" if build_timed_out else ""
                raise RuntimeError(
                    f"phase-three build failed (exit {build_code}{suffix})\n{build_stdout}{build_stderr}")
            WINDOWS_PROJECT_BUILT = True
        executable = benchmark_build_root(PROJECT) / "release" / "bin" / "main.exe"
        if not executable.is_file():
            raise RuntimeError(f"phase-three executable is missing: {executable}")
        environment = os.environ.copy()
        sdl_runtime = REPOSITORY_ROOT.parent / "CangjieSDL" / ".sdl3"
        environment["PATH"] = str(sdl_runtime) + os.pathsep + environment.get("PATH", "")
        if LAST_WINDOWS_PROBE_END is None:
            time.sleep(WINDOWS_PROBE_COOLDOWN_SECONDS)
        else:
            remaining = WINDOWS_PROBE_COOLDOWN_SECONDS - (time.monotonic() - LAST_WINDOWS_PROBE_END)
            if remaining > 0.0:
                time.sleep(remaining)
        code, stdout, stderr, timed_out = run_command(
            [str(executable)], PROJECT, timeout, env=environment, new_process_group=False)
        LAST_WINDOWS_PROBE_END = time.monotonic()
    else:
        code, stdout, stderr, timed_out = run_command(["cjpm", "run"], PROJECT, timeout)
    if code != 0:
        suffix = f"; timed out after {timeout}s" if timed_out else ""
        raise RuntimeError(f"phase-three probe failed (exit {code}{suffix})\n{stdout}{stderr}")
    return stdout.splitlines()


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run CUI phase-three architecture decision probes.")
    parser.add_argument("--samples", type=int, default=3, help="independent samples (default 3)")
    parser.add_argument("--timeout", type=int, default=300, help="timeout for each sample (default 300s)")
    parser.add_argument("--no-run", action="store_true", help="reuse the last aggregated capture")
    args = parser.parse_args(argv)
    if args.samples <= 0:
        parser.error("--samples must be greater than zero")
    if args.timeout <= 0:
        parser.error("--timeout must be greater than zero")

    RESULTS.mkdir(parents=True, exist_ok=True)
    if args.no_run:
        if not RAW.exists():
            raise ValueError(f"no cached phase-three capture at {RAW}")
        cached_lines = RAW.read_text(encoding="utf-8").splitlines()
        captures = [cached_lines]
        sample_count = cached_sample_count(cached_lines)
    else:
        captures = []
        for sample in range(1, args.samples + 1):
            print(f"phase-three sample {sample}/{args.samples}")
            captures.append(run_probe(args.timeout))
        sample_count = args.samples

    records, observations = aggregate_captures(captures)
    evidence = evaluate_evidence(records, observations)
    RAW.write_text("\n".join(machine_lines(records, observations, sample_count)) + "\n", encoding="utf-8")
    JSON_REPORT.write_text(json.dumps({
        "samples": sample_count,
        "records": list(records.values()),
        "observations": {key: list(value) for key, value in observations.items()},
        "evidence": evidence,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    MARKDOWN_REPORT.write_text(render_markdown(records, observations, evidence, sample_count), encoding="utf-8")

    print(f"report: {MARKDOWN_REPORT}")
    print(f"manual retained speedup: {evidence['manual_retained_speedup']:.2f}x")
    print(f"retained-state hit cost growth: {evidence['retained_state_cost_growth']:.2f}x")
    print(f"retained-effect hit cost growth: {evidence['retained_effect_cost_growth']:.2f}x")
    print(("command buffer: total={:.2f}x draw={:.2f}x rerecord-localized={} "
           "memory-bounded={} damage-candidate={}").format(
        evidence["command_buffer_total_speedup"],
        evidence["command_buffer_draw_speedup"],
        evidence["paint_rerecord_localized"],
        evidence["paint_memory_bounded"],
        evidence["damage_after_command_buffer_candidate"],
    ))
    print(("dynamic paint bypass: verified={} cache-penalty={:.2f}x/{:.2f}x "
           "uncached-penalty={:.2f}x/{:.2f}x target={} probe-rate={:.1f}%").format(
        evidence["dynamic_paint_bypass_verified"], evidence["dynamic_paint_total_penalty"],
        evidence["dynamic_paint_draw_penalty"],
        evidence["dynamic_paint_uncached_total_penalty"], evidence["dynamic_paint_uncached_draw_penalty"],
        evidence["dynamic_paint_backoff_target_met"],
        evidence["dynamic_paint_probe_rate"] * 100.0,
    ))
    print("damage prototype: total={:.2f}x draw={:.2f}x memory-stable={} verified={}".format(
        evidence["damage_total_speedup"], evidence["damage_draw_speedup"],
        evidence["damage_memory_stable"], evidence["damage_prototype_verified"],
    ))
    print(("evidence: dependency-tracking={} frame-subscriptions={} "
           "retained-scene-damage-needed={} state-bottleneck={} "
           "state-ownership-bounded={}").format(
        evidence["supports_dependency_tracking"],
        evidence["event_subscription_registry_verified"],
        evidence["retained_scene_damage_needed"],
        evidence["retained_state_bottleneck_observed"],
        evidence["hierarchical_state_ownership_verified"],
    ))
    return 0


def cached_sample_count(lines):
    for line in lines:
        if line.startswith("@@PHASE3_META|samples|"):
            parts = line.strip().split("|")
            if len(parts) != 3:
                raise ValueError(f"malformed phase-three metadata: {line}")
            try:
                count = int(parts[2])
            except ValueError as exc:
                raise ValueError(f"non-numeric phase-three metadata: {line}") from exc
            if count <= 0:
                raise ValueError(f"invalid phase-three metadata range: {line}")
            return count
    return 1


if __name__ == "__main__":
    try:
        exit_code = main()
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"Phase-three probe failed: {exc}", file=sys.stderr)
        exit_code = 2
    sys.exit(exit_code)
