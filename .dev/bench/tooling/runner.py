#!/usr/bin/env python3
"""Orchestrate CUI benchmark capture, gating, and report generation.

Use the public .dev/cli.py bench run command. Implementation details are split
into focused modules so capture, environment, baseline, and verdict policies
can be tested and maintained independently.
"""

import argparse
import json
import os
import sys
import webbrowser
from datetime import datetime

from bench.tooling.baseline import (
    active_baseline_paths,
    baseline_capture_digest,
    baseline_documents,
    baseline_profile,
    baseline_verdict_mode,
    load_baseline,
    load_baseline_metadata,
    save_baseline,
)
from bench.tooling.config import (
    BASELINE,
    BASELINE_CAPTURE_JSON_REPORT,
    BASELINE_CANDIDATE,
    BASELINE_CANDIDATE_META,
    BASELINE_META,
    BENCHMARK_AFFINITY,
    CAPTURE_META,
    CHECK_JSON_REPORT,
    CLEANED_BENCHMARK_PACKAGES,
    DISPLAY_CASE_REPETITIONS,
    DISPLAY_CASES,
    DISPLAY_WARMUP_ROUNDS,
    FRAME_120,
    FRAME_60,
    HEADLESS_GROUPS,
    JSON_REPORT,
    MACHINE_NOTE,
    PAIRED_COMPARISONS,
    PLATFORM_BASELINES,
    RAW,
    REPORT,
    RESULTS,
    ROOT,
    TEMPLATE,
)
from bench.tooling.environment import (
    git_commit,
    host_environment,
    linux_power_environment,
    parse_macos_power_source,
    source_context,
    toolchain,
)
from bench.tooling.execution import (
    apply_benchmark_affinity,
    baseline_capture_destination,
    cjpm_command,
    ensure_fresh_benchmark_package,
    run_cjpm,
    select_performance_affinity,
)
from bench.tooling.gate import baseline_capture_issues, check_regressions, machine_factor
from bench.tooling.io import write_text_lf
from bench.tooling.json_report import write_json_report
from bench.tooling.parsing import (
    capture_sample_count,
    comparison_environment_mismatches,
    diagnostic_contract_issues,
    parse_benchmark_environments,
    parse_counts,
    parse_frame_distributions,
    parse_results,
)
from bench.tooling.promotion import candidate_promotion_issues, promote_baseline_candidate
from bench.tooling.reporting import (
    build_count_section,
    build_display_section,
    esc,
    fmt_dur,
    fps_of,
    frame_row,
    micro_row,
)
from bench.tooling.sampling import (
    capture_stability,
    counterbalanced_run_args,
    median_capture,
    paired_comparison_stability,
    rotated_display_cases,
    run_display_sample_case,
    run_headless_sample,
)
from cui_dev.common.paths import workload
from cui_dev.common.process import run_command


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="CUI benchmark runner + HTML report.")
    ap.add_argument("--no-run", action="store_true", help="reuse the last capture instead of rebuilding")
    ap.add_argument("--open", action="store_true", help="open the report when finished")
    ap.add_argument("--display", action="store_true", help="also run the display benchmarks")
    ap.add_argument("--save-baseline", action="store_true",
                    help="deprecated alias for --capture-baseline-candidate; never overwrites the active gate")
    ap.add_argument("--capture-baseline-candidate", action="store_true",
                    help="stage a complete reviewable baseline without replacing the active gate")
    ap.add_argument("--promote-baseline-candidate", action="store_true",
                    help="promote a reviewed stable AC candidate without running benchmarks")
    ap.add_argument("--check", action="store_true",
                    help="gate regressions; environment mismatch/noise also exit non-zero")
    ap.add_argument("--timeout", type=int, default=600, help="timeout for each benchmark process (default 600s)")
    ap.add_argument("--samples", type=int,
                    help="independent runs aggregated by median/MAD (default 5 for gate/candidate actions, else 1)")
    args = ap.parse_args(argv)

    if args.timeout <= 0:
        ap.error("--timeout must be greater than zero")
    if args.samples is not None and args.samples <= 0:
        ap.error("--samples must be greater than zero")
    if args.promote_baseline_candidate:
        incompatible = (args.display or args.no_run or args.open or args.check or args.save_baseline
                        or args.capture_baseline_candidate or args.samples is not None)
        if incompatible:
            ap.error("--promote-baseline-candidate must be used on its own")
        return promote_baseline_candidate()
    if args.display and args.no_run:
        ap.error("--display cannot be combined with --no-run")
    if args.no_run and args.samples is not None:
        ap.error("--samples cannot be combined with --no-run")
    if args.no_run and (args.check or args.save_baseline or args.capture_baseline_candidate):
        ap.error("--no-run cannot be used for a baseline verdict or baseline capture")
    baseline_actions = sum((args.check, args.save_baseline, args.capture_baseline_candidate))
    if baseline_actions > 1:
        ap.error("--check, --save-baseline and --capture-baseline-candidate are mutually exclusive")
    if (args.save_baseline or args.capture_baseline_candidate) and not args.display:
        ap.error("baseline capture requires --display so it covers the complete suite")

    if args.save_baseline:
        print("--save-baseline is a deprecated candidate-capture alias; explicit promotion is required.",
              file=sys.stderr)

    sample_count = args.samples or (
        5 if args.check or args.save_baseline or args.capture_baseline_candidate else 1)

    RESULTS.mkdir(parents=True, exist_ok=True)
    if not args.no_run:
        try:
            BENCHMARK_AFFINITY.clear()
            BENCHMARK_AFFINITY.update(apply_benchmark_affinity())
        except RuntimeError as error:
            print(f"Cannot establish a stable benchmark CPU domain: {error}", file=sys.stderr)
            return 2
        print(f"Benchmark CPU domain: {BENCHMARK_AFFINITY}")
    start_context = {"source": source_context(), "hostEnvironment": host_environment()}
    stability = []

    if args.no_run:
        if not RAW.exists() or not CAPTURE_META.exists():
            print(f"No provenance-enabled cached capture; run without --no-run first.", file=sys.stderr)
            return 2
        lines = RAW.read_text(encoding="utf-8").splitlines()
        sample_count = capture_sample_count(lines)
        capture_metadata = json.loads(CAPTURE_META.read_text(encoding="utf-8"))
        start_context = capture_metadata["context"]
        stability = capture_metadata.get("sampleStability", [])
    else:
        print(f"Building and running headless benchmarks (micro, {sample_count} sample(s))...")
        if sample_count > 1 and (args.check or args.save_baseline or args.capture_baseline_candidate):
            print("  steady-state warm-up (not recorded)")
            run_headless_sample(args.timeout, 0, sample_count)
        captures = []
        for sample in range(1, sample_count + 1):
            if sample_count > 1:
                print(f"  sample {sample}/{sample_count}")
            captures.append(run_headless_sample(args.timeout, sample - 1, sample_count))
        stability.extend(capture_stability(captures))
        lines = [f"@@BENCH_META|samples|{sample_count}"] + median_capture(captures)
        RAW.write_text("\n".join(lines), encoding="utf-8")

    frame, micro, display = parse_results(lines)
    counts = parse_counts(lines)
    distributions = parse_frame_distributions(lines)
    display_environments = parse_benchmark_environments(lines)

    if args.display and not args.no_run:
        available_cases = [
            case for case in DISPLAY_CASES
            if (workload("display", case[0]) / "cjpm.toml").exists()
        ]
        captures_by_case = {case: [] for case in available_cases}
        if sample_count > 1 and (args.check or args.save_baseline or args.capture_baseline_candidate):
            print(f"  display steady-state warm-up ({DISPLAY_WARMUP_ROUNDS} unrecorded round(s))")
            for warmup in range(DISPLAY_WARMUP_ROUNDS):
                for app, run_args in rotated_display_cases(
                        available_cases, warmup, DISPLAY_WARMUP_ROUNDS):
                    run_cjpm(workload("display", app), "run", args.timeout,
                             counterbalanced_run_args(run_args, warmup))
        print(f"Running {len(available_cases)} display cases in {sample_count} counterbalanced round(s) "
              f"(opens brief windows)...")
        for sample in range(sample_count):
            print(f"  display round {sample + 1}/{sample_count}")
            for app, run_args in rotated_display_cases(available_cases, sample, sample_count):
                effective_run_args = counterbalanced_run_args(run_args, sample)
                shown_run_args = f"{effective_run_args} + opposite order" if run_args == "pair" \
                    else effective_run_args
                variant = f" [{shown_run_args}]" if shown_run_args else ""
                print(f"    {app}{variant}")
                captures_by_case[(app, run_args)].append(
                    run_display_sample_case(app, run_args, args.timeout, sample))
        for case in available_cases:
            captures = captures_by_case[case]
            stability.extend(capture_stability(captures))
            aggregated = median_capture(captures)
            lines.extend(aggregated)
            _f, _m, d = parse_results(aggregated)
            display.extend(d)
            counts.extend(parse_counts(aggregated))
            distributions.extend(parse_frame_distributions(aggregated))
            display_environments.extend(parse_benchmark_environments(aggregated))

    if not frame and not micro and not display:
        print("No @@RESULT lines parsed. Did the build or run fail?", file=sys.stderr)
        return 2

    if not args.no_run:
        RAW.write_text("\n".join(lines), encoding="utf-8")
        end_context = {"source": source_context(), "hostEnvironment": host_environment()}
        context_issues = comparison_environment_mismatches(
            start_context["hostEnvironment"], end_context["hostEnvironment"])
        if start_context["source"] != end_context["source"]:
            context_issues.append("performance-relevant source files changed while the suite was running")
        if context_issues:
            print("Benchmark context changed during capture; refusing to save or judge:", file=sys.stderr)
            for issue in context_issues:
                print(f"  {issue}", file=sys.stderr)
            return 2
        write_text_lf(CAPTURE_META, json.dumps({
            "schemaVersion": 1,
            "samples": sample_count,
            "context": start_context,
            "sampleStability": stability,
        }, ensure_ascii=False, indent=2) + "\n")

    diagnostic_issues = diagnostic_contract_issues(counts)
    if diagnostic_issues and not (args.save_baseline or args.check):
        print("Performance feature contract warnings:", file=sys.stderr)
        for issue in diagnostic_issues:
            print(f"  {issue}", file=sys.stderr)

    capture_destination = baseline_capture_destination(
        args.save_baseline, args.capture_baseline_candidate)
    if capture_destination is not None:
        action, capture_data_path, capture_metadata_path = capture_destination

        def write_baseline_capture_report(status, issues):
            write_json_report(
                BASELINE_CAPTURE_JSON_REPORT,
                frame, micro, display, distributions, display_environments,
                counts, sample_count, None, start_context, stability,
                baseline_capture={"action": action, "status": status, "issues": list(issues)},
            )
            print(f"Structured baseline-capture report written to {BASELINE_CAPTURE_JSON_REPORT}")

        observational = baseline_verdict_mode(start_context) == "observational"
        strict_issues = baseline_capture_issues(
            frame, display, stability, sample_count, diagnostic_issues)
        issues = baseline_capture_issues(
            frame, display, stability, sample_count, diagnostic_issues, allow_timing_noise=True,
        ) if observational else strict_issues
        if issues:
            write_baseline_capture_report("rejected", issues)
            print("Baseline capture is not complete and stable enough to save:", file=sys.stderr)
            for issue in issues:
                print(f"  {issue}", file=sys.stderr)
            return 3
        if observational and strict_issues:
            print("Saving an observational battery candidate with timing-noise warnings:")
            for issue in strict_issues:
                print(f"  {issue}")
            print("  This candidate is report/reference data only and cannot be promoted.")
        save_baseline(
            frame, display, display_environments, stability, start_context, sample_count,
            data_path=capture_data_path, metadata_path=capture_metadata_path,
            label="baseline candidate")
        write_baseline_capture_report("saved", [])
    check_code = None
    if args.check:
        check_code = check_regressions(
            frame, display, display_environments, stability,
            baseline_metadata=load_baseline_metadata(), current_context=start_context,
            diagnostic_issues=diagnostic_issues)
        write_json_report(
            CHECK_JSON_REPORT, frame, micro, display, distributions, display_environments,
            counts, sample_count, check_code, start_context, stability)
        print(f"Structured check report written to {CHECK_JSON_REPORT}")
        return check_code
    write_json_report(
        JSON_REPORT, frame, micro, display, distributions, display_environments,
        counts, sample_count, check_code, start_context, stability)

    # --- render ---
    frame_sorted = sorted(frame, key=lambda r: r["ns"], reverse=True)
    over = [r for r in frame_sorted if r["ns"] > FRAME_60]
    comfy = [r for r in frame_sorted if r["ns"] <= FRAME_120]

    worst = "n/a"
    if frame_sorted:
        w = frame_sorted[0]
        worst = f"{esc(w['group'])} / {esc(w['name'])} - {fmt_dur(w['ns'])} (~{fps_of(w['ns'])} fps)"

    frame_rows = "".join(frame_row(r) for r in frame_sorted)

    micro_rows = ""
    groups = {}
    for r in micro:
        groups.setdefault(r["group"], []).append(r)
    for name, recs in groups.items():
        mx = max(r["ns"] for r in recs)
        for r in sorted(recs, key=lambda r: r["ns"], reverse=True):
            micro_rows += micro_row(r, mx)

    weak = ""
    for r in over:
        weak += (f"        <li><b>{esc(r['group'])} / {esc(r['name'])}</b> - "
                 f"{fmt_dur(r['ns'])} (~{fps_of(r['ns'])} fps)</li>\n")
    if not weak:
        weak = '        <li class="muted">没有超出 60fps 预算的用例。</li>\n'

    strong = ""
    for r in sorted(comfy, key=lambda r: r["ns"]):
        strong += f"        <li><b>{esc(r['group'])} / {esc(r['name'])}</b> - {fmt_dur(r['ns'])}</li>\n"
    if not strong:
        strong = '        <li class="muted">暂无进入 120fps 区间的帧用例。</li>\n'

    host = start_context["hostEnvironment"]
    sources = start_context["source"]
    overlay = str(host.get("effectivePowerOverlay", "unknown"))[:8]
    gui_digest = str(sources.get("cangjieGui", {}).get("sourceDigest", "unknown"))[:12]
    sdl_digest = str(sources.get("cangjieSdl", {}).get("sourceDigest", "unknown"))[:12]
    meta = (f"生成于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ｜ 提交 {git_commit()} ｜ "
            f"样本 {sample_count} ｜ {host.get('powerSource', 'unknown')} / overlay {overlay} ｜ "
            f"GUI {gui_digest} / SDL {sdl_digest} ｜ {esc(toolchain())}")

    html = TEMPLATE.read_text(encoding="utf-8")
    replacements = {
        "{{META}}": meta,
        "{{FRAME_COUNT}}": str(len(frame)),
        "{{OVER_COUNT}}": str(len(over)),
        "{{COMFORT_COUNT}}": str(len(comfy)),
        "{{WORST}}": worst,
        "{{FRAME_ROWS}}": frame_rows,
        "{{DISPLAY_SECTION}}": build_display_section(display, distributions),
        "{{COUNT_SECTION}}": build_count_section(counts),
        "{{WEAK_ITEMS}}": weak,
        "{{STRONG_ITEMS}}": strong,
        "{{MICRO_ROWS}}": micro_rows,
    }
    for token, value in replacements.items():
        html = html.replace(token, value)

    REPORT.write_text(html, encoding="utf-8")
    print(f"\nReport written to {REPORT}")
    print(f"Headless frame cases: {len(frame)}  |  over 60fps budget: {len(over)}"
          f"  |  at 120fps: {len(comfy)}")
    if display:
        distribution_by_key = {(item["group"], item["name"]): item for item in distributions}
        display_p95 = [distribution_by_key.get((item["group"], item["name"]), {}).get("p95Ns", item["ns"])
                       for item in display]
        print(f"Display cases: {len(display)}  |  P95 over 60fps budget: "
              f"{sum(1 for value in display_p95 if value > FRAME_60)}  |  P95 at 120fps: "
              f"{sum(1 for value in display_p95 if value <= FRAME_120)}")
    # The budget counts above are raw measurements, so say so when this box is not running at the speed
    # the baseline was taken on: on a 3x-slow machine the heaviest cases cross 16.67ms on their own and
    # the counts read like a regression that is not there. --check is normalised; these counts are not.
    factor, gated, _ = machine_factor(frame, load_baseline())
    if factor is not None and factor >= MACHINE_NOTE:
        would = sum(1 for r in frame if r["ns"] / factor > FRAME_60)
        print(f"  note: this box is running ~{factor:.1f}x slower than the baseline machine"
              f" ({len(gated)} cases compared); at baseline speed ~{would} would be over the 60fps budget."
              f" Use --check (normalised) to judge regressions.")

    if args.open:
        webbrowser.open(REPORT.as_uri())
    return check_code or 0


if __name__ == "__main__":
    try:
        exit_code = main()
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"Benchmark failed: {exc}", file=sys.stderr)
        exit_code = 2
    sys.exit(exit_code)
