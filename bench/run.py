#!/usr/bin/env python3
"""One-click CUI benchmark runner (cross-platform).

Builds and runs the headless benchmarks, parses their machine-readable @@RESULT lines, and renders
a self-contained HTML report (bench/results/report.html) that lays each per-frame cost against the
interactive frame budgets (120 / 60 / 30 fps) and auto-derives a strengths / weaknesses summary.

Headless numbers measure CPU-side build / layout / draw only (text is estimated, not rasterised).
With --display it also runs the self-terminating display benchmarks for long content, dense
controls, a large table, and retained partial damage. These measure real per-frame cost including
SDL text rasterisation and GPU present. See bench/README.md.

Usage:
    python bench/run.py                 # build + run headless, write the report
    python bench/run.py --open          # ...and open it in a browser
    python bench/run.py --no-run        # reuse the last capture, just re-render the report
    python bench/run.py --display       # also run the display benchmarks (opens brief windows)
    python bench/run.py --display --save-baseline # record a complete, stable regression baseline
    python bench/run.py --check         # 0 pass; 1 regression; 2 incomparable; 3 inconclusive
    python bench/run.py --samples 5     # take the per-case median of five independent runs
    python bench/run_test.py            # self-test the --check gate logic

--check judges each case against how the *other* cases moved rather than against raw baseline times,
so a machine that is uniformly slower than the one that recorded the baseline does not read as 39
regressions; and it reports its own noise, answering "inconclusive" when a run cannot tell a
regression from scheduling jitter. Only --check is normalised — the report and the budget counts are
raw measurements of this box.
"""

import argparse
import ctypes
import hashlib
import json
import os
import platform
import statistics
import subprocess
import sys
import time
import webbrowser
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results"
TEMPLATE = ROOT / "report.template.html"
RAW = RESULTS / "micro.out.txt"
CAPTURE_META = RESULTS / "capture.meta.json"
REPORT = RESULTS / "report.html"
JSON_REPORT = RESULTS / "report.json"
CHECK_JSON_REPORT = RESULTS / "check.json"
BASELINE = ROOT / "baseline.json"
BASELINE_META = ROOT / "baseline.meta.json"
BUILT_WINDOWS_PACKAGES = set()
LAST_WINDOWS_BENCHMARK_END = None
WINDOWS_BENCHMARK_COOLDOWN_SECONDS = 1.0

sys.path.insert(0, str(ROOT.parent / ".devtools"))
from process_runner import run_command

FRAME_60 = 16_666_667   # ns budget for 60 fps
FRAME_120 = 8_333_333   # ns budget for 120 fps
FRAME_30 = 33_333_333   # ns budget for 30 fps

# --check flags a case that slowed this much MORE than its peers did. It is a *relative* threshold:
# see check_regressions for why comparing raw times to the baseline does not survive a slow machine.
REGRESSION = 1.25
# Cases cheaper than this cannot move a frame, and carry nearly all the measurement jitter (a 10 us
# case can double on scheduler noise alone), so they are never gated; ones that still moved a lot are
# listed after the verdict as FYI only.
MATERIAL_NS = 500_000
# Display execution domains deliberately separate backend / supersampling / vsync. Six independent
# material workloads still give the robust median and MAD enough peers, while eight made the real ss1
# domain permanently inconclusive after sub-material cases were (correctly) removed from gating.
MIN_FLEET = 6
# A fleet median past this reads as "this box is slower than the one that recorded the baseline",
# which is worth saying out loud because it makes absolute times incomparable.
MACHINE_NOTE = 1.15
# How many robust deviations past the fleet a case must sit before it is called a regression. This only
# bites on a noisy run: on a quiet one the REGRESSION floor is the wider of the two and stays in charge.
NOISE_K = 4
# Residual spread (median absolute deviation about the fleet) past which a run simply cannot gate. A
# machine that schedules some cases on performance cores and others on efficiency cores does not slow
# down uniformly, and no threshold separates signal from that. Say so instead of guessing.
NOISE_LIMIT = 0.10
# Independent-sample median absolute deviation past this is not stable enough to gate. MAD deliberately
# ignores a lone scheduler spike that the median already rejects, while still refusing bimodal or
# generally dispersed captures. The full range remains in reports as a tail diagnostic.
SAMPLE_MAD_LIMIT = 0.10

RATING_LABEL = {
    "ok": "120fps 就绪",
    "good": "60fps 就绪",
    "warn": "30fps 及格",
    "bad": "低于 30fps",
}

DISPLAY_CASES = [
    ("primitive_batch", None),
    ("text_layout", "pair"),
    ("planner_scroll", "pair"),
    ("controls_form", "12 ss2"),
    ("controls_form", "24 ss2"),
    ("controls_form", None),
    ("controls_form", "12 lazy ss2"),
    ("controls_form", "24 lazy ss2"),
    ("controls_form", "40 lazy ss2"),
    ("large_table", "pair"),
    ("incremental_dashboard", None),
]

# Ratios whose numerator is the optimized path. Both sides are emitted by one benchmark process, so
# they cancel most CPU/GPU power and presentation drift that absolute cross-process times cannot.
PAIRED_COMPARISONS = [
    ("primitive-batch/single",
     "display|原语提交（上机实测）|2048 rect 相邻批处理",
     "display|原语提交（上机实测）|2048 rect 单条提交"),
    ("text-stable/churn",
     "display|段落布局（上机实测）|20000 字 热缓存",
     "display|段落布局（上机实测）|20000 字 LRU 冷抖动"),
    ("planner-ss1/ss2",
     "display|内容页滚动（上机实测）|16 区块 ss1x",
     "display|内容页滚动（上机实测）|16 区块 ss2x"),
    ("large-table-5000/500",
     "display|大表绘制（上机实测）|5000 行窗口化",
     "display|大表绘制（上机实测）|500 行窗口化"),
    ("dashboard-command/full",
     "display|增量仪表盘（真实渲染）|96 区域命令全场重放",
     "display|增量仪表盘（真实渲染）|96 区域强制全量"),
    ("dashboard-damage/command",
     "display|增量仪表盘（真实渲染）|单区域 damage",
     "display|增量仪表盘（真实渲染）|96 区域命令全场重放"),
]


def cjpm_command(action, run_args=None):
    command = ["cjpm", action]
    if run_args:
        command.extend(["--run-args", run_args])
    return command


def run_cjpm(pkg_dir: Path, action: str = "run", timeout: int = 600, run_args=None) -> list:
    """Run `cjpm <action>` in pkg_dir and return its stdout as a list of lines."""
    global LAST_WINDOWS_BENCHMARK_END
    if action == "run" and os.name == "nt":
        # On Windows an optimized benchmark can emit its complete machine log in under two seconds.
        # `cjpm run` intermittently stalls while forwarding that fast child output into another
        # captured process, even though the same executable is stable when launched directly. Build
        # first, then bypass only cjpm's forwarding layer; the benchmark process itself keeps the
        # shared timeout/process-tree capture and the SDL runtime directory is explicit.
        package_key = str(pkg_dir.resolve())
        if package_key not in BUILT_WINDOWS_PACKAGES:
            build_code, build_stdout, build_stderr, build_timed_out = run_command(
                cjpm_command("build"), pkg_dir, timeout)
            if build_code != 0:
                suffix = f"; timed out after {timeout}s" if build_timed_out else ""
                raise RuntimeError(
                    f"cjpm build failed in {pkg_dir} (exit {build_code}{suffix})\n{build_stdout}{build_stderr}")
            BUILT_WINDOWS_PACKAGES.add(package_key)
        executable = pkg_dir / "target" / "release" / "bin" / "main.exe"
        if not executable.is_file():
            raise RuntimeError(f"built benchmark executable is missing: {executable}")
        environment = os.environ.copy()
        sdl_runtime = ROOT.parent.parent / "CangjieSDL" / ".sdl3"
        environment["PATH"] = str(sdl_runtime) + os.pathsep + environment.get("PATH", "")
        command = [str(executable)]
        if run_args:
            command.extend(run_args.split())
        if LAST_WINDOWS_BENCHMARK_END is None:
            time.sleep(WINDOWS_BENCHMARK_COOLDOWN_SECONDS)
        else:
            remaining = WINDOWS_BENCHMARK_COOLDOWN_SECONDS - (time.monotonic() - LAST_WINDOWS_BENCHMARK_END)
            if remaining > 0.0:
                time.sleep(remaining)
        # CREATE_NEW_PROCESS_GROUP intermittently stalls optimized Cangjie executables on Windows.
        # taskkill /PID /T still provides exact timeout tree cleanup without that creation flag.
        returncode, stdout, stderr, timed_out = run_command(
            command, pkg_dir, timeout, env=environment, new_process_group=False)
        LAST_WINDOWS_BENCHMARK_END = time.monotonic()
    else:
        returncode, stdout, stderr, timed_out = run_command(cjpm_command(action, run_args), pkg_dir, timeout)
    if returncode != 0:
        sys.stderr.write(stdout)
        sys.stderr.write(stderr)
        suffix = f"; timed out after {timeout}s" if timed_out else ""
        raise RuntimeError(f"cjpm {action} failed in {pkg_dir} (exit {returncode}{suffix})")
    return stdout.splitlines()


def parse_results(lines):
    frame, micro, display = [], [], []
    for ln in lines:
        if not ln.startswith("@@RESULT"):
            continue
        parts = ln.strip().split("|")
        if len(parts) != 6:
            raise ValueError(f"malformed benchmark result: {ln}")
        try:
            rec = {
                "kind": parts[1],
                "group": parts[2],
                "name": parts[3],
                "ns": int(parts[4]),
                "iters": int(parts[5]),
            }
        except ValueError as exc:
            raise ValueError(f"non-numeric benchmark result: {ln}") from exc
        if rec["ns"] < 0 or rec["iters"] <= 0:
            raise ValueError(f"invalid benchmark result range: {ln}")
        if rec["kind"] == "frame":
            frame.append(rec)
        elif rec["kind"] == "display":
            display.append(rec)
        else:
            micro.append(rec)
    return frame, micro, display


def parse_counts(lines):
    counts = []
    for ln in lines:
        if not ln.startswith("@@COUNT"):
            continue
        parts = ln.strip().split("|")
        if len(parts) != 4:
            raise ValueError(f"malformed benchmark count: {ln}")
        try:
            count = int(parts[3])
        except ValueError as exc:
            raise ValueError(f"non-numeric benchmark count: {ln}") from exc
        if count < 0:
            raise ValueError(f"invalid benchmark count range: {ln}")
        counts.append({"group": parts[1], "name": parts[2], "count": count})
    return counts


def diagnostic_contract_issues(counts):
    """Validate deterministic cache/virtualisation properties independently of wall-clock noise."""
    values = {(item["group"], item["name"]): int(item["count"]) for item in counts}
    issues = []

    text_group = "段落布局（上机实测）"
    text_keys = [key for key in values if key[0] == text_group]
    if text_keys:
        hot_misses = values.get((text_group, "20000 字 热缓存 paragraph misses"))
        hot_evictions = values.get((text_group, "20000 字 热缓存 paragraph evictions"))
        churn_evictions = values.get((text_group, "20000 字 LRU 冷抖动 paragraph evictions"))
        if hot_misses is None or hot_evictions is None or churn_evictions is None:
            issues.append("paragraph-cache diagnostics are incomplete")
        else:
            if hot_misses > 4 or hot_evictions != 0:
                issues.append(f"hot paragraph cache lost reuse: misses={hot_misses}, evictions={hot_evictions}")
            if churn_evictions <= 0:
                issues.append("LRU churn did not exceed the paragraph-cache budget (no eviction observed)")

    planner_group = "内容页滚动（上机实测）"
    measure_name = "16 区块 ss1x text measures"
    compute_name = "16 区块 ss1x text computes"
    if any(key[0] == planner_group and key[1].startswith("16 区块 ss1x text ") for key in values):
        measures = values.get((planner_group, measure_name))
        computes = values.get((planner_group, compute_name))
        if measures is None or computes is None or measures <= 0:
            issues.append("ss1 text-cache diagnostics are incomplete")
        elif computes * 2 >= measures:
            issues.append(f"ss1 logical text cache is ineffective: {computes} computes / {measures} measures")

    automatic_groups = {"自动组合", "自动显示列表", "自动渲染边界"}
    if any(key[0] in automatic_groups for key in values):
        expected = {
            ("自动组合", "单 State 变更执行分支体"): 1,
            ("自动组合", "强制全量执行分支体"): 240,
            ("自动显示列表", "自动缓存 widget 绘制访问"): 0,
            ("自动显示列表", "强制直绘 widget 绘制访问"): 96,
            ("自动渲染边界", "兄弟变化稳定子树 layout 访问"): 0,
            ("自动渲染边界", "强制全量稳定子树 layout 访问"): 24,
        }
        missing = [f"{group}/{name}" for (group, name) in expected if (group, name) not in values]
        if missing:
            issues.append("automatic incremental diagnostics are incomplete: " + ", ".join(missing))
        else:
            mismatches = [
                f"{group}/{name}={values[(group, name)]} (expected {wanted})"
                for (group, name), wanted in expected.items() if values[(group, name)] != wanted
            ]
            commands = values.get(("自动显示列表", "缓存命令数"))
            if commands is None or commands < 24:
                mismatches.append(f"自动显示列表/缓存命令数={commands} (expected >= 24)")
            if mismatches:
                issues.append("automatic incremental feature contract failed: " + "; ".join(mismatches))
    return issues


def parse_frame_distributions(lines):
    """Parse within-run display latency distributions emitted by ``BenchAccumulator``."""
    distributions = []
    for ln in lines:
        if not ln.startswith("@@FRAME_DIST"):
            continue
        parts = ln.strip().split("|")
        if len(parts) != 12:
            raise ValueError(f"malformed frame distribution: {ln}")
        try:
            rec = {
                "group": parts[1],
                "name": parts[2],
                "p50Ns": int(parts[3]),
                "p90Ns": int(parts[4]),
                "p95Ns": int(parts[5]),
                "p99Ns": int(parts[6]),
                "maxNs": int(parts[7]),
                "over120FpsBudget": int(parts[8]),
                "over60FpsBudget": int(parts[9]),
                "over30FpsBudget": int(parts[10]),
                "samples": int(parts[11]),
            }
        except ValueError as exc:
            raise ValueError(f"non-numeric frame distribution: {ln}") from exc
        values = [rec[key] for key in (
            "p50Ns", "p90Ns", "p95Ns", "p99Ns", "maxNs",
            "over120FpsBudget", "over60FpsBudget", "over30FpsBudget",
        )]
        if rec["samples"] <= 0 or any(value < 0 for value in values):
            raise ValueError(f"invalid frame distribution range: {ln}")
        if not (rec["p50Ns"] <= rec["p90Ns"] <= rec["p95Ns"]
                <= rec["p99Ns"] <= rec["maxNs"]):
            raise ValueError(f"non-monotonic frame distribution: {ln}")
        if not (rec["samples"] >= rec["over120FpsBudget"]
                >= rec["over60FpsBudget"] >= rec["over30FpsBudget"]):
            raise ValueError(f"invalid frame budget counts: {ln}")
        distributions.append(rec)
    return distributions


def parse_benchmark_environments(lines):
    environments = []
    for ln in lines:
        if not ln.startswith("@@BENCH_ENV"):
            continue
        parts = ln.strip().split("|")
        if len(parts) != 6:
            raise ValueError(f"malformed benchmark environment: {ln}")
        try:
            supersample = int(parts[4])
            vsync = int(parts[5])
        except ValueError as exc:
            raise ValueError(f"non-numeric benchmark environment: {ln}") from exc
        if not parts[3] or supersample < 1 or vsync not in (-1, 0, 1):
            raise ValueError(f"invalid benchmark environment: {ln}")
        environments.append({
            "group": parts[1],
            "name": parts[2],
            "driver": parts[3],
            "supersample": supersample,
            "vsync": vsync,
        })
    return environments


def median_capture(captures):
    """Return machine-record lines whose values are per-case medians across independent runs.

    Every sample must expose exactly the same result and diagnostic keys. Silently accepting a
    partial run would make its missing slow cases disappear from the report and regression gate.
    Iteration counts are part of the benchmark definition and must also stay fixed across samples.
    """
    if not captures:
        raise ValueError("at least one benchmark capture is required")

    result_samples = []
    count_samples = []
    distribution_samples = []
    environment_samples = []
    for lines in captures:
        frame, micro, display = parse_results(lines)
        result_samples.append(index_records(frame + micro + display, "benchmark result"))
        count_samples.append(index_counts(parse_counts(lines)))
        distribution_samples.append(index_distributions(parse_frame_distributions(lines)))
        environment_samples.append(index_environments(parse_benchmark_environments(lines)))

    result_keys = list(result_samples[0].keys())
    count_keys = list(count_samples[0].keys())
    expected_results = set(result_keys)
    expected_counts = set(count_keys)
    distribution_keys = list(distribution_samples[0].keys())
    expected_distributions = set(distribution_keys)
    environment_keys = list(environment_samples[0].keys())
    expected_environments = set(environment_keys)
    for sample in result_samples[1:]:
        if set(sample.keys()) != expected_results:
            raise ValueError("benchmark result keys differ between samples")
    for sample in count_samples[1:]:
        if set(sample.keys()) != expected_counts:
            raise ValueError("benchmark count keys differ between samples")
    for sample in distribution_samples[1:]:
        if set(sample.keys()) != expected_distributions:
            raise ValueError("frame distribution keys differ between samples")
    for sample in environment_samples[1:]:
        if set(sample.keys()) != expected_environments:
            raise ValueError("benchmark environment keys differ between samples")

    lines = []
    for key in result_keys:
        records = [sample[key] for sample in result_samples]
        iterations = {record["iters"] for record in records}
        if len(iterations) != 1:
            raise ValueError(f"benchmark iterations differ between samples: {'|'.join(key)}")
        first = records[0]
        ns = median_int([record["ns"] for record in records])
        lines.append(
            f"@@RESULT|{first['kind']}|{first['group']}|{first['name']}|{ns}|{first['iters']}"
        )
    for key in count_keys:
        records = [sample[key] for sample in count_samples]
        first = records[0]
        count = median_int([record["count"] for record in records])
        lines.append(f"@@COUNT|{first['group']}|{first['name']}|{count}")
    numeric_fields = (
        "p50Ns", "p90Ns", "p95Ns", "p99Ns", "maxNs",
        "over120FpsBudget", "over60FpsBudget", "over30FpsBudget",
    )
    for key in distribution_keys:
        records = [sample[key] for sample in distribution_samples]
        sample_counts = {record["samples"] for record in records}
        if len(sample_counts) != 1:
            raise ValueError(f"frame distribution sample counts differ: {'|'.join(key)}")
        first = records[0]
        aggregate = {field: median_int([record[field] for record in records]) for field in numeric_fields}
        lines.append(
            f"@@FRAME_DIST|{first['group']}|{first['name']}|{aggregate['p50Ns']}|"
            f"{aggregate['p90Ns']}|{aggregate['p95Ns']}|{aggregate['p99Ns']}|"
            f"{aggregate['maxNs']}|{aggregate['over120FpsBudget']}|"
            f"{aggregate['over60FpsBudget']}|{aggregate['over30FpsBudget']}|{first['samples']}"
        )
    for key in environment_keys:
        records = [sample[key] for sample in environment_samples]
        first = records[0]
        stable_fields = ("driver", "supersample", "vsync")
        if any(record[field] != first[field] for record in records[1:] for field in stable_fields):
            raise ValueError(f"benchmark environments differ between samples: {'|'.join(key)}")
        lines.append(
            f"@@BENCH_ENV|{first['group']}|{first['name']}|{first['driver']}|"
            f"{first['supersample']}|{first['vsync']}"
        )
    return lines


def capture_stability(captures):
    """Return per-result independent-sample dispersion without discarding provenance."""
    if not captures:
        return []
    indexed = [index_records(sum(parse_results(lines), []), "benchmark result") for lines in captures]
    keys = list(indexed[0].keys())
    expected = set(keys)
    if any(set(sample.keys()) != expected for sample in indexed[1:]):
        raise ValueError("benchmark result keys differ between samples")
    result = []
    for key in keys:
        values = [int(sample[key]["ns"]) for sample in indexed]
        median = median_int(values)
        mad = median_int([abs(value - median) for value in values])
        relative_range = (max(values) - min(values)) / median if median > 0 else 0.0
        relative_mad = mad / median if median > 0 else 0.0
        result.append({
            "kind": key[0],
            "group": key[1],
            "name": key[2],
            "samplesNs": values,
            "medianNs": median,
            "minNs": min(values),
            "maxNs": max(values),
            "relativeRange": relative_range,
            "relativeMad": relative_mad,
        })
    return result


def paired_comparison_stability(stability):
    """Build aligned within-process A/B ratio samples from per-case captures."""
    indexed = {f"{item['kind']}|{item['group']}|{item['name']}": item for item in stability}
    result = []
    for name, numerator_key, denominator_key in PAIRED_COMPARISONS:
        numerator = indexed.get(numerator_key)
        denominator = indexed.get(denominator_key)
        if numerator is None or denominator is None:
            continue
        numerator_samples = numerator["samplesNs"]
        denominator_samples = denominator["samplesNs"]
        if len(numerator_samples) != len(denominator_samples):
            raise ValueError(f"paired comparison sample count differs: {name}")
        ratios = [n / d for n, d in zip(numerator_samples, denominator_samples) if d > 0]
        if len(ratios) != len(numerator_samples) or not ratios:
            raise ValueError(f"paired comparison denominator is invalid: {name}")
        median = statistics.median(ratios)
        mad = statistics.median(abs(value - median) for value in ratios)
        result.append({
            "name": name,
            "numerator": numerator_key,
            "denominator": denominator_key,
            "samples": ratios,
            "median": median,
            "relativeMad": mad / median if median > 0 else 0.0,
            "relativeRange": (max(ratios) - min(ratios)) / median if median > 0 else 0.0,
        })
    return result


def rotated_display_cases(cases, sample_index, sample_count):
    """Deterministically counterbalance fixed-order thermal/power bias across display rounds."""
    if not cases:
        return []
    step = max(1, (len(cases) + max(1, sample_count) - 1) // max(1, sample_count))
    offset = (sample_index * step) % len(cases)
    return list(cases[offset:]) + list(cases[:offset])


def comparison_environment_mismatches(baseline, current):
    """List stable host/power fields that make two absolute benchmark runs incomparable."""
    fields = (
        "platform", "machine", "processor", "logicalCpuCount", "powerSource",
        "powerScheme", "effectivePowerOverlay", "videoControllers",
    )
    mismatches = []
    for field in fields:
        before = baseline.get(field)
        now = current.get(field)
        if before != now:
            mismatches.append(f"{field}: baseline={before!r}, current={now!r}")
    return mismatches


def capture_sample_count(lines):
    """Read aggregate provenance from a cached capture; legacy captures count as one sample."""
    for line in lines:
        if line.startswith("@@BENCH_META|samples|"):
            parts = line.strip().split("|")
            if len(parts) != 3:
                raise ValueError(f"malformed benchmark metadata: {line}")
            try:
                count = int(parts[2])
            except ValueError as exc:
                raise ValueError(f"non-numeric benchmark metadata: {line}") from exc
            if count <= 0:
                raise ValueError(f"invalid benchmark metadata range: {line}")
            return count
    return 1


def index_records(records, label):
    indexed = {}
    for record in records:
        key = (record["kind"], record["group"], record["name"])
        if key in indexed:
            raise ValueError(f"duplicate {label}: {'|'.join(key)}")
        indexed[key] = record
    return indexed


def index_counts(records):
    indexed = {}
    for record in records:
        key = (record["group"], record["name"])
        if key in indexed:
            raise ValueError(f"duplicate benchmark count: {'|'.join(key)}")
        indexed[key] = record
    return indexed


def index_distributions(records):
    indexed = {}
    for record in records:
        key = (record["group"], record["name"])
        if key in indexed:
            raise ValueError(f"duplicate frame distribution: {'|'.join(key)}")
        indexed[key] = record
    return indexed


def index_environments(records):
    indexed = {}
    for record in records:
        key = (record["group"], record["name"])
        if key in indexed:
            raise ValueError(f"duplicate benchmark environment: {'|'.join(key)}")
        indexed[key] = record
    return indexed


def median_int(values):
    return int(statistics.median(values))


def fmt_dur(ns: float) -> str:
    ns = float(ns)
    if ns < 10_000:
        return f"{ns:.0f} ns"
    if ns < 10_000_000:
        return f"{ns / 1000:.2f} us"
    return f"{ns / 1_000_000:.3f} ms"


def frame_class(ns: float) -> str:
    if ns <= FRAME_120:
        return "ok"
    if ns <= FRAME_60:
        return "good"
    if ns <= FRAME_30:
        return "warn"
    return "bad"


def esc(text: str) -> str:
    return (str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def fps_of(ns: float) -> int:
    return round(1e9 / ns) if ns > 0 else 0


def frame_row(rec) -> str:
    cls = frame_class(rec["ns"])
    fps = fps_of(rec["ns"])
    pct = min(100, round(rec["ns"] / FRAME_60 * 100))
    return f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{fps}</td>
        <td><span class="badge {cls}">{RATING_LABEL[cls]}</span></td>
        <td class="barcell"><div class="bar"><div class="fill {cls}" style="width:{pct}%"></div></div></td>
      </tr>
"""


def micro_row(rec, max_ns) -> str:
    ops = fps_of(rec["ns"])
    pct = max(5, round(rec["ns"] / max_ns * 100)) if max_ns > 0 else 5
    return f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{ops:,}</td>
        <td class="barcell"><div class="bar"><div class="fill micro" style="width:{pct}%"></div></div></td>
      </tr>
"""


def build_display_section(display, distributions) -> str:
    if not display:
        return (
            '<div class="note"><p class="muted" style="margin:0">尚未采集上机实测数据。运行 '
            "<code>python bench/run.py --display</code> 会启动自终止的端到端基准（短暂开窗、跑满固定帧数后自动退出），"
            "将含 GPU 与文本光栅的真实帧率并入本报告。</p></div>"
        )
    distribution_by_case = index_distributions(distributions)
    rows = ""
    for rec in sorted(display, key=lambda r: distribution_by_case.get(
            (r["group"], r["name"]), {}).get("p95Ns", r["ns"]), reverse=True):
        distribution = distribution_by_case.get((rec["group"], rec["name"]))
        judged_ns = distribution["p95Ns"] if distribution else rec["ns"]
        cls = frame_class(judged_ns)
        fps = fps_of(rec["ns"])
        miss = (f"{distribution['over60FpsBudget'] / distribution['samples'] * 100:.1f}%"
                if distribution else "-")
        p50 = fmt_dur(distribution["p50Ns"]) if distribution else "-"
        p95 = fmt_dur(distribution["p95Ns"]) if distribution else "-"
        p99 = fmt_dur(distribution["p99Ns"]) if distribution else "-"
        maximum = fmt_dur(distribution["maxNs"]) if distribution else "-"
        rows += f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{p50}</td>
        <td class="num">{p95}</td>
        <td class="num">{p99}</td>
        <td class="num">{maximum}</td>
        <td class="num">{miss}</td>
        <td class="num">{fps}</td>
        <td><span class="badge {cls}">{RATING_LABEL[cls]}</span></td>
      </tr>
"""
    return f"""<div class="tablewrap">
    <table>
      <thead><tr><th>场景</th><th>用例</th><th>均值</th><th>P50</th><th>P95</th><th>P99</th><th>最大</th><th>超 60fps 预算</th><th>均值帧率</th><th>P95 评级</th></tr></thead>
      <tbody>
{rows}      </tbody>
    </table>
  </div>
  <p class="muted" style="font-size:12.5px">分位数来自单次上机运行的完整帧样本；多次运行时逐字段取中位数。评级按 P95，而非容易掩盖尾延迟的均值。</p>"""


def build_count_section(counts) -> str:
    if not counts:
        return ('<div class="note"><p class="muted" style="margin:0">无文本度量诊断数据。</p></div>')
    mx = max((c["count"] for c in counts), default=1) or 1
    rows = ""
    for c in sorted(counts, key=lambda r: r["count"], reverse=True):
        pct = max(3, round(c["count"] / mx * 100))
        cls = "bad" if c["count"] > 500 else ("warn" if c["count"] > 120 else "ok")
        rows += f"""      <tr>
        <td>{esc(c['name'])}</td>
        <td class="num">{c['count']:,}</td>
        <td class="barcell"><div class="bar"><div class="fill {cls}" style="width:{pct}%"></div></div></td>
      </tr>
"""
    return f"""<div class="tablewrap">
    <table>
      <thead><tr><th>场景</th><th>每帧文本度量次数</th><th>相对量（越短越好）</th></tr></thead>
      <tbody>
{rows}      </tbody>
    </table>
  </div>
  <p class="muted" style="font-size:12.5px">每帧文本度量次数 × 单次 SDL_ttf 成本 ≈ 该帧文本预算。未窗口化的组合内容页每帧上千次度量，是 planner 右栏滚动帧率偏低的主因；窗口化的表格与列表只度量可见行，故低一到两个数量级。</p>"""


def git_commit() -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True,
        )
        return out.stdout.strip() or "(no git)"
    except Exception:
        return "(no git)"


def source_fingerprint(repository: Path, include):
    """Hash every performance-relevant tracked or untracked source file in a repository."""
    try:
        completed = subprocess.run(
            ["git", "-C", str(repository), "ls-files", "-co", "--exclude-standard", "-z"],
            capture_output=True,
        )
        if completed.returncode != 0:
            raise RuntimeError("git ls-files failed")
        paths = sorted(path for raw in completed.stdout.split(b"\0") if raw
                       for path in [raw.decode("utf-8", errors="surrogateescape")]
                       if include(path.replace("\\", "/")))
        digest = hashlib.sha256()
        for relative in paths:
            normalized = relative.replace("\\", "/")
            digest.update(normalized.encode("utf-8", errors="surrogateescape"))
            digest.update(b"\0")
            path = repository / relative
            if path.is_file():
                digest.update(path.read_bytes())
            digest.update(b"\0")
        status = subprocess.run(
            ["git", "-C", str(repository), "status", "--porcelain=v1", "--untracked-files=all"],
            capture_output=True,
        ).stdout.decode("utf-8", errors="replace").splitlines()
        dirty = any(include(line[3:].replace("\\", "/").split(" -> ")[-1])
                    for line in status if len(line) > 3)
        commit = subprocess.run(
            ["git", "-C", str(repository), "rev-parse", "HEAD"], capture_output=True, text=True,
        ).stdout.strip()
        return {"commit": commit or "unknown", "sourceDigest": digest.hexdigest(), "dirty": dirty,
                "fileCount": len(paths)}
    except Exception as exc:
        return {"commit": "unknown", "sourceDigest": "unavailable", "dirty": True,
                "fileCount": 0, "error": str(exc)}


def source_context():
    gui = ROOT.parent
    sdl = gui.parent / "CangjieSDL"
    gui_include = lambda path: (path in ("cjpm.toml", ".devtools/process_runner.py") or path.startswith("src/")
                                or (path.startswith("bench/")
                                    and Path(path).suffix.lower() in (".py", ".cj", ".toml", ".html")))
    sdl_include = lambda path: path == "cjpm.toml" or path.startswith("src/")
    return {
        "cangjieGui": source_fingerprint(gui, gui_include),
        "cangjieSdl": source_fingerprint(sdl, sdl_include),
    }


def windows_power_environment():
    if os.name != "nt":
        return {"powerSource": "unknown", "powerScheme": "unknown",
                "effectivePowerOverlay": "unknown"}

    class SystemPowerStatus(ctypes.Structure):
        _fields_ = [
            ("acLineStatus", ctypes.c_ubyte),
            ("batteryFlag", ctypes.c_ubyte),
            ("batteryLifePercent", ctypes.c_ubyte),
            ("systemStatusFlag", ctypes.c_ubyte),
            ("batteryLifeTime", ctypes.c_ulong),
            ("batteryFullLifeTime", ctypes.c_ulong),
        ]

    status = SystemPowerStatus()
    source = "unknown"
    if ctypes.windll.kernel32.GetSystemPowerStatus(ctypes.byref(status)):
        source = {0: "battery", 1: "ac"}.get(status.acLineStatus, "unknown")

    scheme = "unknown"
    overlay_ac = "unknown"
    overlay_dc = "unknown"
    try:
        import winreg
        key_path = r"SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes"
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
            scheme = str(winreg.QueryValueEx(key, "ActivePowerScheme")[0]).lower()
            overlay_ac = str(winreg.QueryValueEx(key, "ActiveOverlayAcPowerScheme")[0]).lower()
            overlay_dc = str(winreg.QueryValueEx(key, "ActiveOverlayDcPowerScheme")[0]).lower()
    except OSError:
        pass
    effective = overlay_dc if source == "battery" else overlay_ac if source == "ac" else "unknown"
    return {"powerSource": source, "powerScheme": scheme, "effectivePowerOverlay": effective,
            "acPowerOverlay": overlay_ac, "dcPowerOverlay": overlay_dc}


def windows_video_environment():
    if os.name != "nt":
        return []
    command = (
        "$items=@(Get-CimInstance Win32_VideoController | "
        "Select-Object Name,DriverVersion,CurrentRefreshRate);"
        "$items | ConvertTo-Json -Compress"
    )
    try:
        completed = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", command],
            capture_output=True, text=True, timeout=15,
        )
        if completed.returncode != 0 or not completed.stdout.strip():
            return []
        value = json.loads(completed.stdout)
        items = value if isinstance(value, list) else [value]
        return sorted(items, key=lambda item: str(item.get("Name", "")))
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return []


def toolchain() -> str:
    try:
        out = subprocess.run(["cjc", "--version"], capture_output=True, text=True)
        line = (out.stdout or out.stderr).splitlines()
        return line[0].strip() if line else "-"
    except Exception:
        return "-"


def load_baseline():
    if BASELINE.exists():
        return json.loads(BASELINE.read_text(encoding="utf-8"))
    return {}


def load_baseline_metadata():
    if BASELINE_META.exists():
        return json.loads(BASELINE_META.read_text(encoding="utf-8"))
    return {}


def index_display_environments(records):
    return {f"{record['group']}|{record['name']}": {
        "driver": record["driver"],
        "supersample": record["supersample"],
        "vsync": record["vsync"],
    } for record in records}


def baseline_verdict_mode(context):
    power_source = str(context.get("hostEnvironment", {}).get("powerSource", "unknown")).lower()
    return "observational" if power_source == "battery" else "gate"


def save_baseline(frame, display, display_environments, stability, context, sample_count):
    data = {f"{r['kind']}|{r['group']}|{r['name']}": r["ns"] for r in list(frame) + list(display)}
    write_text_lf(BASELINE, json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    metadata = {
        "schemaVersion": 1,
        "generatedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
        "samples": sample_count,
        "verdictMode": baseline_verdict_mode(context),
        "source": context["source"],
        "hostEnvironment": context["hostEnvironment"],
        "displayEnvironments": index_display_environments(display_environments),
        "sampleStability": stability,
        "pairedComparisons": paired_comparison_stability(stability),
    }
    write_text_lf(BASELINE_META, json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    mode = metadata["verdictMode"]
    print(f"{mode.capitalize()} baseline saved to {BASELINE} ({len(data)} cases).")
    print(f"Baseline provenance saved to {BASELINE_META}.")


def host_environment():
    result = {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "logicalCpuCount": os.cpu_count(),
        "python": platform.python_version(),
    }
    result.update(windows_power_environment())
    result["videoControllers"] = windows_video_environment()
    return result


def write_json_report(
        path, frame, micro, display, distributions, display_environments,
        counts, sample_count, check_code, context, stability):
    """Write the complete machine-readable report even when ``--check`` exits before HTML render."""
    baseline = load_baseline()
    records = list(frame) + list(display)
    unstable = unstable_material_keys(records, stability, baseline)
    factor, gated, comparable = machine_factor(records, baseline)
    stable_gated = [pair for pair in gated if pair["key"] not in unstable]
    if len(stable_gated) != len(gated):
        factor = statistics.median([pair["ratio"] for pair in stable_gated]) if stable_gated else None
    display_environment_by_key = index_display_environments(display_environments)
    domains = {}
    for record in records:
        domains.setdefault(benchmark_domain(record, display_environment_by_key), []).append(record)
    domain_factors = {}
    for domain, records in sorted(domains.items()):
        domain_factor, domain_gated, domain_comparable = machine_factor(records, baseline)
        domain_stable = [pair for pair in domain_gated if pair["key"] not in unstable]
        if len(domain_stable) != len(domain_gated):
            domain_factor = statistics.median([pair["ratio"] for pair in domain_stable]) \
                if domain_stable else None
        domain_factors[domain] = {
            "factor": domain_factor,
            "materialCases": len(domain_stable),
            "stableMaterialCases": len(domain_stable),
            "unstableMaterialCases": len(domain_gated) - len(domain_stable),
            "comparableCases": len(domain_comparable),
        }
    payload = {
        "generatedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
        "commit": git_commit(),
        "toolchain": toolchain(),
        "hostEnvironment": context["hostEnvironment"],
        "source": context["source"],
        "baselineSource": load_baseline_metadata().get("source"),
        "samples": sample_count,
        "budgetsNs": {"fps120": FRAME_120, "fps60": FRAME_60, "fps30": FRAME_30},
        "machineFactor": factor,
        "machineFactorsByDomain": domain_factors,
        "materialBaselineCases": len(stable_gated),
        "stableMaterialBaselineCases": len(stable_gated),
        "unstableMaterialBaselineCases": len(gated) - len(stable_gated),
        "comparableBaselineCases": len(comparable),
        "checkExitCode": check_code,
        "checkStatus": {None: "not-run", 0: "pass", 1: "regression", 2: "setup-error", 3: "inconclusive"}
            .get(check_code, "unknown"),
        "frame": frame,
        "micro": micro,
        "display": display,
        "frameDistributions": distributions,
        "displayEnvironments": display_environments,
        "sampleStability": stability,
        "pairedComparisons": paired_comparison_stability(stability),
        "counts": counts,
    }
    write_text_lf(path, json.dumps(payload, ensure_ascii=False, indent=2) + "\n")


def write_text_lf(path, text):
    """Write deterministic UTF-8/LF artifacts on every host, including checked-in baselines."""
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(text)


def machine_factor(recs, base):
    """The median case's slowdown vs baseline, over cases big enough to measure reliably.

    When every case moves by the same factor, that factor is the machine — this box has been measured
    running 2.5-3x slow for hours at a stretch (thermal/power limits, or work parked on E-cores) — not
    the code. Returns (factor, gated, pairs): the factor, the material cases worth gating, and every
    comparable case. factor is None when no case is material — sub-material cases are never gated in
    its place, since they are exactly where scheduler jitter lives.
    """
    pairs = []
    for r in recs:
        was = base.get(f"{r['kind']}|{r['group']}|{r['name']}")
        if was and was > 0:
            pairs.append({
                "key": f"{r['kind']}|{r['group']}|{r['name']}",
                "was": was,
                "now": r["ns"],
                "ratio": r["ns"] / was,
            })
    gated = [p for p in pairs if max(p["was"], p["now"]) >= MATERIAL_NS]
    if not gated:
        return None, [], pairs
    return statistics.median([p["ratio"] for p in gated]), gated, pairs


def benchmark_domain(record, display_environment_by_key):
    if record["kind"] != "display":
        return "headless/frame"
    key = f"{record['group']}|{record['name']}"
    environment = display_environment_by_key.get(key, {})
    return (f"display/{environment.get('driver', 'unknown')}/"
            f"ss{environment.get('supersample', 'unknown')}/vsync{environment.get('vsync', 'unknown')}")


def baseline_context_issues(metadata, current_context, display_environments):
    issues = []
    if metadata.get("schemaVersion") != 1:
        return ["baseline provenance is missing or has an unsupported schema"]
    if int(metadata.get("samples", 0)) < 3:
        issues.append("baseline used fewer than 3 independent samples")
    baseline_source = metadata.get("source", {})
    current_source = current_context.get("source", {})
    for repository in ("cangjieGui", "cangjieSdl"):
        fingerprint = baseline_source.get(repository, {})
        if fingerprint.get("sourceDigest") in (None, "", "unavailable"):
            issues.append(f"baseline lacks a usable {repository} source fingerprint")
        current_fingerprint = current_source.get(repository, {})
        if current_fingerprint.get("sourceDigest") in (None, "", "unavailable"):
            issues.append(f"current capture lacks a usable {repository} source fingerprint")
    issues.extend(comparison_environment_mismatches(
        metadata.get("hostEnvironment", {}), current_context.get("hostEnvironment", {})))
    baseline_display = metadata.get("displayEnvironments", {})
    for key, current in index_display_environments(display_environments).items():
        before = baseline_display.get(key)
        if before is None:
            issues.append(f"display environment missing from baseline: {key}")
        elif before != current:
            issues.append(f"display environment changed for {key}: baseline={before!r}, current={current!r}")
    return issues


def same_source_fingerprints(baseline_metadata, current_context):
    """Return true only when both performance-relevant repositories exactly match the baseline."""
    before = baseline_metadata.get("source", {})
    current = current_context.get("source", {})
    for repository in ("cangjieGui", "cangjieSdl"):
        left = before.get(repository, {}).get("sourceDigest")
        right = current.get(repository, {}).get("sourceDigest")
        if not left or left == "unavailable" or not right or right == "unavailable" or left != right:
            return False
    return True


def hard_verdict_limitations(baseline_metadata, current_context, has_candidates):
    """Explain why measured candidates cannot safely become a hard pass/fail on this capture.

    Windows' selected overlay does not freeze laptop clocks on battery: firmware may still react to
    charge, temperature and platform power limits. Battery captures therefore remain useful reports,
    but are observational rather than release gates. An exact same-source replay is an even stronger
    control: any candidate it finds is session/environment drift by definition, not a code regression.
    """
    limitations = []
    power_source = str(current_context.get("hostEnvironment", {}).get("powerSource", "unknown")).lower()
    if power_source == "battery":
        limitations.append("battery power is observational; dynamic platform limits prevent a hard pass/fail")
    if baseline_metadata.get("verdictMode") == "observational":
        limitations.append("the baseline is observational and cannot produce a hard pass/fail")
    if has_candidates and same_source_fingerprints(baseline_metadata, current_context):
        limitations.append("the same source fingerprints produced the candidate; this is reproducibility drift")
    return limitations


def unstable_material_keys(records, stability, base=None):
    base = base or {}
    by_key = {f"{item['kind']}|{item['group']}|{item['name']}": item for item in stability}
    unstable = {}
    for record in records:
        key = f"{record['kind']}|{record['group']}|{record['name']}"
        sample = by_key.get(key)
        material = max(float(record["ns"]), float(base.get(key, 0))) >= MATERIAL_NS
        if material and sample is not None and sample["relativeMad"] > SAMPLE_MAD_LIMIT:
            unstable[key] = sample
    return unstable


def baseline_capture_issues(
    frame, display, stability, sample_count, diagnostic_issues=None, allow_timing_noise=False,
):
    issues = list(diagnostic_issues or [])
    if sample_count < 3:
        issues.append("a regression baseline requires at least 3 independent samples")
    if not allow_timing_noise:
        unstable = unstable_material_keys(list(frame) + list(display), stability)
        for key, sample in sorted(unstable.items()):
            issues.append(f"unstable baseline case {key}: sample MAD {sample['relativeMad'] * 100:.0f}%")
    paired = paired_comparison_stability(stability)
    if len(paired) != len(PAIRED_COMPARISONS):
        issues.append(f"complete baseline requires {len(PAIRED_COMPARISONS)} paired comparisons; got {len(paired)}")
    if not allow_timing_noise:
        for comparison in paired:
            if comparison["relativeMad"] > SAMPLE_MAD_LIMIT:
                issues.append(f"unstable paired baseline {comparison['name']}: "
                              f"ratio MAD {comparison['relativeMad'] * 100:.0f}%")
    return issues


def check_regressions(
    frame,
    display,
    display_environments=None,
    stability=None,
    baseline_metadata=None,
    current_context=None,
    diagnostic_issues=None,
) -> int:
    """Fail on a case that got slower than its peers did — and say so when the run cannot tell.

    Comparing raw times against the baseline is what this used to do, and it does not survive a slow
    machine: at a uniform 3x every one of the 39 cases "regresses" and the gate is pure noise. Two
    things fix that. Each case is judged against the *median* case, so a machine-wide slowdown cancels
    out; and the run measures its own residual spread, because a box that parks some cases on
    efficiency cores and others on performance cores does not slow down uniformly and no threshold
    separates a real regression from that. When the spread is too wide the honest answer is
    "inconclusive", not a coin flip — suspects are still listed and exit 3 blocks a false pass/fail.

    Two blind spots are inherent to judging against the median, so they are stated rather than hidden:
    a regression that slows the *majority* of cases (not only all of them) is absorbed into the machine
    factor and reads as a slow box — the factor is always printed, and a big number there means "re-run
    somewhere idle before trusting a clean result". And the flagging side normalises by max(factor, 1),
    so a commit that speeds up most cases does not turn the untouched rest into false regressions.
    """
    display_environments = display_environments or []
    stability = stability or []
    base = load_baseline()
    if not base:
        print("No baseline.json; run with --save-baseline first.", file=sys.stderr)
        return 2
    if baseline_metadata is not None:
        issues = baseline_context_issues(baseline_metadata, current_context or {}, display_environments)
        if issues:
            print("Benchmark environments are not comparable; refusing a regression verdict:", file=sys.stderr)
            for issue in issues:
                print(f"  {issue}", file=sys.stderr)
            print("Use a provenance-enabled baseline recorded under the same power/display profile.",
                  file=sys.stderr)
            return 2
    current_keys = {f"{record['kind']}|{record['group']}|{record['name']}" for record in list(frame) + list(display)}
    missing = sorted(current_keys - set(base))
    if missing:
        print("Baseline coverage error: current benchmark cases are not gated:", file=sys.stderr)
        for key in missing:
            print(f"  {key}", file=sys.stderr)
        print("Run the complete intended suite with --save-baseline after reviewing its results.", file=sys.stderr)
        return 2
    if diagnostic_issues:
        print("Deterministic performance feature contracts failed:", file=sys.stderr)
        for issue in diagnostic_issues:
            print(f"  {issue}", file=sys.stderr)
        return 1
    records = list(frame) + list(display)
    display_environment_by_key = index_display_environments(display_environments)
    domains = {}
    for record in records:
        domains.setdefault(benchmark_domain(record, display_environment_by_key), []).append(record)
    if not any(machine_factor(domain_records, base)[2] for domain_records in domains.values()):
        print("No cases in common with baseline.json; nothing to check.", file=sys.stderr)
        return 2
    unstable = unstable_material_keys(records, stability, base)
    regressions = []
    inconclusive = False
    all_pairs = []
    all_gated = []

    paired_regressions = []
    if baseline_metadata is not None:
        baseline_paired = {item["name"]: item for item in baseline_metadata.get("pairedComparisons", [])}
        current_paired = paired_comparison_stability(stability)
        missing_paired = sorted(item["name"] for item in current_paired if item["name"] not in baseline_paired)
        if missing_paired:
            print("Baseline lacks current paired A/B comparisons:", file=sys.stderr)
            for name in missing_paired:
                print(f"  {name}", file=sys.stderr)
            return 2
        for item in current_paired:
            before = baseline_paired[item["name"]]
            if item["relativeMad"] > SAMPLE_MAD_LIMIT:
                print(f"INCONCLUSIVE [paired/{item['name']}]: ratio MAD "
                      f"{item['relativeMad'] * 100:.0f}% exceeds {SAMPLE_MAD_LIMIT * 100:.0f}%.")
                inconclusive = True
                continue
            ratio = item["median"] / before["median"] if before.get("median", 0) > 0 else 0.0
            print(f"Checked [paired/{item['name']}]: {before['median']:.3f} -> {item['median']:.3f} "
                  f"({ratio:.2f}x)")
            if ratio > REGRESSION:
                paired_regressions.append((item, before, ratio))

    for domain, domain_records in sorted(domains.items()):
        factor, gated, pairs = machine_factor(domain_records, base)
        all_pairs.extend(pairs)
        stable_gated = [pair for pair in gated if pair["key"] not in unstable]
        if factor is not None and len(stable_gated) != len(gated):
            factor = statistics.median([pair["ratio"] for pair in stable_gated]) if stable_gated else None
        all_gated.extend(stable_gated)
        if factor is None:
            print(f"INCONCLUSIVE [{domain}]: no stable material cases of at least {fmt_dur(MATERIAL_NS)}.")
            inconclusive = True
            continue
        if len(stable_gated) < MIN_FLEET:
            print(f"INCONCLUSIVE [{domain}]: only {len(stable_gated)} stable material case(s); "
                  f"need {MIN_FLEET} for domain normalisation.")
            inconclusive = True
            continue

        spread = statistics.median([abs(pair["ratio"] / factor - 1.0) for pair in stable_gated])
        bound = 1.0 + max(REGRESSION - 1.0, NOISE_K * spread)
        flag_factor = max(factor, 1.0)
        suspects = sorted((pair for pair in stable_gated if pair["ratio"] / flag_factor > bound),
                          key=lambda pair: -pair["ratio"] / flag_factor)
        print(f"Checked [{domain}] {len(stable_gated)} stable material cases: factor {factor:.2f}x, "
              f"noise +/-{spread * 100:.0f}%, flags past {bound:.2f}x vs domain peers")
        if factor >= MACHINE_NOTE:
            print(f"  Domain is running ~{factor:.1f}x slower than its baseline; absolute times are not comparable.")
        if spread > NOISE_LIMIT:
            print(f"INCONCLUSIVE [{domain}]: residual disagreement +/-{spread * 100:.0f}% is too wide.")
            inconclusive = True
            continue
        regressions.extend((domain, pair, factor, bound) for pair in suspects)

    if unstable:
        inconclusive = True
        print(f"\nINCONCLUSIVE sample dispersion (MAD limit {SAMPLE_MAD_LIMIT * 100:.0f}%):")
        for key, sample in sorted(unstable.items()):
            print(f"  {key}: {sample['relativeMad'] * 100:.0f}% MAD, "
                  f"{sample['relativeRange'] * 100:.0f}% full range across "
                  f"{', '.join(fmt_dur(value) for value in sample['samplesNs'])}")

    has_candidates = bool(regressions or paired_regressions)
    verdict_limitations = hard_verdict_limitations(
        baseline_metadata or {}, current_context or {}, has_candidates) if baseline_metadata is not None else []
    if has_candidates:
        heading = ("Regression candidates measured within their execution domains:"
                   if verdict_limitations else "Regressions stable within their execution domains:")
        print(f"\n{heading}", file=sys.stderr)
        for domain, pair, factor, bound in regressions:
            print(f"  [{domain}] {pair['key']}: {fmt_dur(pair['was'])} -> {fmt_dur(pair['now'])}"
                  f"   {pair['ratio']:.2f}x raw, {pair['ratio'] / max(factor, 1.0):.2f}x vs peers"
                  f" (bound {bound:.2f}x)", file=sys.stderr)
        for item, before, ratio in paired_regressions:
            print(f"  [paired/{item['name']}] optimized/reference ratio "
                  f"{before['median']:.3f} -> {item['median']:.3f} ({ratio:.2f}x)", file=sys.stderr)
        if verdict_limitations:
            print("\nINCONCLUSIVE: hard regression verdict disabled for this capture:")
            for limitation in verdict_limitations:
                print(f"  {limitation}")
            return 3
        return 1
    if verdict_limitations:
        print("\nOBSERVATIONAL ONLY: no regression candidate was found, but this is not a hard pass:")
        for limitation in verdict_limitations:
            print(f"  {limitation}")
        return 3
    if inconclusive:
        print("\nNo regression verdict: rerun after stabilising the reported domain/sample noise.")
        return 3
    print("No regressions past threshold in any stable execution domain.")
    if all_pairs and all_gated:
        note_cheap_movers(all_pairs, all_gated, 1.0, REGRESSION)
    return 0


def note_cheap_movers(pairs, gated, flag_factor, bound):
    """List sub-material cases that moved past the bound — visibility only, never a verdict.

    A 20us case jumping 20x cannot cost a frame today, but it can be an algorithmic slip that will
    scale with content, so it deserves a line in the output even though it is far too jittery to gate.
    """
    gated_keys = {p["key"] for p in gated}
    movers = sorted((p for p in pairs if p["key"] not in gated_keys
                     and p["ratio"] / flag_factor > bound), key=lambda p: -p["ratio"] / flag_factor)
    if movers:
        print(f"\nSub-material cases that also moved (too small to gate; FYI only):")
        for p in movers:
            print(f"  {p['key']}: {fmt_dur(p['was'])} -> {fmt_dur(p['now'])}   {p['ratio']:.2f}x raw")


def main() -> int:
    ap = argparse.ArgumentParser(description="CUI benchmark runner + HTML report.")
    ap.add_argument("--no-run", action="store_true", help="reuse the last capture instead of rebuilding")
    ap.add_argument("--open", action="store_true", help="open the report when finished")
    ap.add_argument("--display", action="store_true", help="also run the display benchmarks")
    ap.add_argument("--save-baseline", action="store_true", help="record current costs as the regression baseline")
    ap.add_argument("--check", action="store_true",
                    help="gate regressions; environment mismatch/noise also exit non-zero")
    ap.add_argument("--timeout", type=int, default=600, help="timeout for each benchmark process (default 600s)")
    ap.add_argument("--samples", type=int,
                    help="independent runs aggregated by median/MAD (default 5 for --check/--save-baseline, else 1)")
    args = ap.parse_args()

    if args.timeout <= 0:
        ap.error("--timeout must be greater than zero")
    if args.samples is not None and args.samples <= 0:
        ap.error("--samples must be greater than zero")
    if args.display and args.no_run:
        ap.error("--display cannot be combined with --no-run")
    if args.no_run and args.samples is not None:
        ap.error("--samples cannot be combined with --no-run")
    if args.no_run and (args.check or args.save_baseline):
        ap.error("--no-run cannot be used for a baseline verdict or baseline capture")
    if args.check and args.save_baseline:
        ap.error("--check cannot be combined with --save-baseline")
    if args.save_baseline and not args.display:
        ap.error("--save-baseline requires --display so the reviewed baseline covers the complete suite")

    sample_count = args.samples or (5 if args.check or args.save_baseline else 1)

    RESULTS.mkdir(parents=True, exist_ok=True)
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
        print(f"Building and running headless benchmarks (bench/micro, {sample_count} sample(s))...")
        captures = []
        for sample in range(1, sample_count + 1):
            if sample_count > 1:
                print(f"  sample {sample}/{sample_count}")
            captures.append(run_cjpm(ROOT / "micro", "run", args.timeout))
        stability.extend(capture_stability(captures))
        lines = [f"@@BENCH_META|samples|{sample_count}"] + median_capture(captures)
        RAW.write_text("\n".join(lines), encoding="utf-8")

    frame, micro, display = parse_results(lines)
    counts = parse_counts(lines)
    distributions = parse_frame_distributions(lines)
    display_environments = parse_benchmark_environments(lines)

    if args.display and not args.no_run:
        available_cases = [case for case in DISPLAY_CASES if (ROOT / case[0] / "cjpm.toml").exists()]
        captures_by_case = {case: [] for case in available_cases}
        print(f"Running {len(available_cases)} display cases in {sample_count} counterbalanced round(s) "
              f"(opens brief windows)...")
        for sample in range(sample_count):
            print(f"  display round {sample + 1}/{sample_count}")
            for app, run_args in rotated_display_cases(available_cases, sample, sample_count):
                variant = f" [{run_args}]" if run_args else ""
                print(f"    bench/{app}{variant}")
                captures_by_case[(app, run_args)].append(
                    run_cjpm(ROOT / app, "run", args.timeout, run_args))
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

    if args.save_baseline:
        observational = baseline_verdict_mode(start_context) == "observational"
        strict_issues = baseline_capture_issues(
            frame, display, stability, sample_count, diagnostic_issues)
        issues = baseline_capture_issues(
            frame, display, stability, sample_count, diagnostic_issues, allow_timing_noise=True,
        ) if observational else strict_issues
        if issues:
            print("Baseline capture is not stable enough to save:", file=sys.stderr)
            for issue in issues:
                print(f"  {issue}", file=sys.stderr)
            return 3
        if observational and strict_issues:
            print("Saving an observational battery baseline with timing-noise warnings:")
            for issue in strict_issues:
                print(f"  {issue}")
            print("  These values are report/reference data only and can never produce a hard PASS/FAIL.")
        save_baseline(frame, display, display_environments, stability, start_context, sample_count)
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
        weak += f"        <li><b>{esc(r['group'])} / {esc(r['name'])}</b> - {fmt_dur(r['ns'])} (~{fps_of(r['ns'])} fps)</li>\n"
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
