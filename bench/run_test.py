#!/usr/bin/env python3
"""Self-test for the benchmark regression gate (bench/run.py --check).

The gate has three jobs that are each easy to get wrong: ignore a machine that is uniformly slower than
the one that recorded the baseline, still catch a single case that really did regress (even while that
machine is slow), and admit when a run is too noisy to judge at all. Synthetic fleets exercise all
three, so the gate itself is verified without needing a quiet machine to run the real benchmarks on.

Run: python bench/run_test.py
"""

import importlib.util
import io
import json
import random
import sys
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.dont_write_bytecode = True  # importing run.py for its logic should not litter a __pycache__
spec = importlib.util.spec_from_file_location("benchrun", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)

# A synthetic fleet: 12 frame cases from 1ms to 12ms, all well past the material floor.
BASE = {f"frame|g|case{i}": float(i * 1_000_000) for i in range(1, 13)}


def frames(scale):
    """Build a result set where each case i is scale(i) times its baseline."""
    return [
        {"kind": "frame", "group": "g", "name": f"case{i}", "ns": BASE[f"frame|g|case{i}"] * scale(i)}
        for i in range(1, 13)
    ]


def check(recs, base=None):
    run.load_baseline = lambda: dict(base or BASE)
    buf = io.StringIO()
    with redirect_stdout(buf), redirect_stderr(buf):
        code = run.check_regressions(recs, [])
    return code, buf.getvalue()


failures = []


def expect(name, cond, detail=""):
    if cond:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}\n{detail}")
        failures.append(name)


print("bench regression-gate self-test\n")

try:
    run.parse_results(["@@RESULT|frame|g|bad|not-a-number|10"])
    malformed_rejected = False
except ValueError:
    malformed_rejected = True
expect("malformed machine record is rejected", malformed_rejected)

try:
    run.parse_counts(["@@COUNT|g|bad|-1"])
    negative_count_rejected = False
except ValueError:
    negative_count_rejected = True
expect("negative diagnostic count is rejected", negative_count_rejected)

good_contract_counts = [
    {"group": "段落布局（上机实测）", "name": "20000 字 热缓存 paragraph misses", "count": 1},
    {"group": "段落布局（上机实测）", "name": "20000 字 热缓存 paragraph evictions", "count": 0},
    {"group": "段落布局（上机实测）", "name": "20000 字 LRU 冷抖动 paragraph evictions", "count": 20},
    {"group": "内容页滚动（上机实测）", "name": "16 区块 ss1x text measures", "count": 400},
    {"group": "内容页滚动（上机实测）", "name": "16 区块 ss1x text computes", "count": 3},
]
expect("deterministic performance feature contracts accept healthy cache counters",
       run.diagnostic_contract_issues(good_contract_counts) == [])
bad_contract_counts = [dict(item) for item in good_contract_counts]
bad_contract_counts[2]["count"] = 0
bad_contract_counts[4]["count"] = 400
contract_issues = run.diagnostic_contract_issues(bad_contract_counts)
expect("deterministic performance feature contracts catch cache-path failures",
       len(contract_issues) == 2 and any("LRU" in issue for issue in contract_issues)
       and any("ss1" in issue for issue in contract_issues), "\n".join(contract_issues))

sampling_counts = [
    {"group": "内容页滚动（上机实测）", "name": "16 区块 ss2x sampling target pixels", "count": 36741600},
    {"group": "内容页滚动（上机实测）", "name": "16 区块 ss2x sampling target bytes", "count": 146966400},
    {"group": "内容页滚动（上机实测）", "name": "16 区块 ss2x max texture edge", "count": 16384},
]
expect("render-sampling diagnostics accept exact RGBA8 resource accounting",
       run.diagnostic_contract_issues(sampling_counts) == [])
broken_sampling_counts = [dict(item) for item in sampling_counts]
broken_sampling_counts[1]["count"] = 36741600
sampling_issues = run.diagnostic_contract_issues(broken_sampling_counts)
expect("render-sampling diagnostics catch inconsistent target accounting",
       len(sampling_issues) == 1 and "resource accounting" in sampling_issues[0],
       "\n".join(sampling_issues))

lazy_phase_counts = [
    {"group": "LazyColumn 滚动相位", "name": "增量 body 总执行", "count": 51},
    {"group": "LazyColumn 滚动相位", "name": "强制全量 body 总执行", "count": 800},
    {"group": "LazyColumn 滚动相位", "name": "增量稳定化总 pass", "count": 851},
]
expect("lazy scroll phase-split contract accepts boundary-only materialization",
       run.diagnostic_contract_issues(lazy_phase_counts) == [])
broken_lazy_phase_counts = [dict(item) for item in lazy_phase_counts]
broken_lazy_phase_counts[0]["count"] = 800
broken_lazy_phase_counts[2]["count"] = 1600
lazy_phase_issues = run.diagnostic_contract_issues(broken_lazy_phase_counts)
expect("lazy scroll phase-split contract catches per-frame composition",
       len(lazy_phase_issues) == 1 and "discrete materialization" in lazy_phase_issues[0],
       "\n".join(lazy_phase_issues))

lazy_navigation_counts = [
    {"group": "scrollToKey 扩展性", "name": "10000 项平均 key 访问", "count": 575},
    {"group": "scrollToKey 扩展性", "name": "100000 项平均 key 访问", "count": 8408},
    {"group": "scrollToIndex 扩展性", "name": "10000 项平均 key 访问", "count": 75},
    {"group": "scrollToIndex 扩展性", "name": "100000 项平均 key 访问", "count": 75},
]
expect("lazy index navigation contract accepts total-size-independent visible work",
       run.diagnostic_contract_issues(lazy_navigation_counts) == [])
broken_lazy_navigation_counts = [dict(item) for item in lazy_navigation_counts]
broken_lazy_navigation_counts[3]["count"] = 8408
lazy_navigation_issues = run.diagnostic_contract_issues(broken_lazy_navigation_counts)
expect("lazy index navigation contract catches a hidden full-key scan",
       len(lazy_navigation_issues) == 1 and "total-size independence" in lazy_navigation_issues[0],
       "\n".join(lazy_navigation_issues))

automatic_contract_counts = [
    {"group": "自动组合", "name": "单 State 变更执行分支体", "count": 1},
    {"group": "自动组合", "name": "强制全量执行分支体", "count": 240},
    {"group": "自动显示列表", "name": "自动缓存 widget 绘制访问", "count": 0},
    {"group": "自动显示列表", "name": "强制直绘 widget 绘制访问", "count": 96},
    {"group": "自动显示列表", "name": "缓存命令数", "count": 96},
    {"group": "自动渲染边界", "name": "兄弟变化稳定子树 layout 访问", "count": 0},
    {"group": "自动渲染边界", "name": "强制全量稳定子树 layout 访问", "count": 24},
]
expect("automatic incremental feature contracts accept exact traversal evidence",
       run.diagnostic_contract_issues(automatic_contract_counts) == [])
broken_automatic_counts = [dict(item) for item in automatic_contract_counts]
broken_automatic_counts[2]["count"] = 96
automatic_issues = run.diagnostic_contract_issues(broken_automatic_counts)
expect("automatic incremental feature contracts catch a stale display-list path",
       len(automatic_issues) == 1 and "automatic incremental" in automatic_issues[0],
       "\n".join(automatic_issues))

paint_culling_counts = [
    {"group": "控件密集表单（上机实测）", "name": "40 分区 全量 ss2x text draws", "count": 4030},
    {"group": "控件密集表单（上机实测）", "name": "40 分区 窗口化 ss2x text draws", "count": 4467},
]
expect("ordinary ScrollView paint-culling contract accepts viewport-local draw counts",
       run.diagnostic_contract_issues(paint_culling_counts) == [])
broken_paint_culling_counts = [dict(item) for item in paint_culling_counts]
broken_paint_culling_counts[0]["count"] = 78000
paint_culling_issues = run.diagnostic_contract_issues(broken_paint_culling_counts)
expect("ordinary ScrollView paint-culling contract catches full-tree drawing",
       len(paint_culling_issues) == 1 and "paint culling" in paint_culling_issues[0],
       "\n".join(paint_culling_issues))

self_measuring_counts = [
    {"group": "控件密集表单（上机实测）", "name": "40 分区 全量 ss2x text draws", "count": 4030},
    {"group": "控件密集表单（上机实测）", "name": "40 分区 窗口化 ss2x text draws", "count": 4467},
    {"group": "控件密集表单（上机实测）", "name": "40 分区 自测量 ss2x text draws", "count": 4030},
    {"group": "控件密集表单（上机实测）", "name": "40 分区 全量 ss2x text measures", "count": 310030},
    {"group": "控件密集表单（上机实测）", "name": "40 分区 自测量 ss2x text measures", "count": 22940},
]
expect("self-measuring virtualization contracts accept visible-window work",
       run.diagnostic_contract_issues(self_measuring_counts) == [])
broken_self_measuring_counts = [dict(item) for item in self_measuring_counts]
broken_self_measuring_counts[4]["count"] = 310030
self_measuring_issues = run.diagnostic_contract_issues(broken_self_measuring_counts)
expect("self-measuring virtualization contracts catch full-list measurement",
       len(self_measuring_issues) == 1 and "layout windowing" in self_measuring_issues[0],
       "\n".join(self_measuring_issues))

distribution_line = "@@FRAME_DIST|g|case|100|200|300|400|500|4|3|2|5"
distribution = run.parse_frame_distributions([distribution_line])[0]
expect("frame distribution preserves tail latency and budget misses",
       distribution["p95Ns"] == 300 and distribution["over60FpsBudget"] == 3)
try:
    run.parse_frame_distributions(["@@FRAME_DIST|g|bad|300|200|400|500|600|4|3|2|5"])
    non_monotonic_distribution_rejected = False
except ValueError:
    non_monotonic_distribution_rejected = True
expect("non-monotonic frame distribution is rejected", non_monotonic_distribution_rejected)
try:
    run.parse_frame_distributions(["@@FRAME_DIST|g|bad|100|200|300|400|500|4|5|2|5"])
    invalid_budget_counts_rejected = False
except ValueError:
    invalid_budget_counts_rejected = True
expect("invalid frame-budget miss counts are rejected", invalid_budget_counts_rejected)

environment_line = "@@BENCH_ENV|g|case|direct3d11|2|0"
environment = run.parse_benchmark_environments([environment_line])[0]
expect("display backend environment is parsed",
       environment["driver"] == "direct3d11" and environment["supersample"] == 2
       and environment["vsync"] == 0)
try:
    run.parse_benchmark_environments(["@@BENCH_ENV|g|bad||0|9"])
    invalid_environment_rejected = False
except ValueError:
    invalid_environment_rejected = True
expect("invalid display backend environment is rejected", invalid_environment_rejected)

median_lines = run.median_capture([
    ["@@RESULT|frame|g|case|300|10", "@@COUNT|g|count|9",
     "@@FRAME_DIST|g|case|300|400|500|600|700|9|8|7|10", environment_line],
    ["@@RESULT|frame|g|case|100|10", "@@COUNT|g|count|3",
     "@@FRAME_DIST|g|case|100|200|300|400|500|3|2|1|10", environment_line],
    ["@@RESULT|frame|g|case|200|10", "@@COUNT|g|count|6",
     "@@FRAME_DIST|g|case|200|300|400|500|600|6|5|4|10", environment_line],
])
median_frame, _, _ = run.parse_results(median_lines)
median_counts = run.parse_counts(median_lines)
median_distribution = run.parse_frame_distributions(median_lines)
median_environment = run.parse_benchmark_environments(median_lines)
expect("multi-sample capture uses per-case medians",
       median_frame[0]["ns"] == 200 and median_counts[0]["count"] == 6
       and median_distribution[0]["p95Ns"] == 400
       and median_distribution[0]["over60FpsBudget"] == 5
       and median_environment[0]["driver"] == "direct3d11")

expect("cached capture preserves sample provenance",
       run.capture_sample_count(["@@BENCH_META|samples|5"]) == 5)
try:
    run.capture_sample_count(["@@BENCH_META|samples|0"])
    invalid_metadata_rejected = False
except ValueError:
    invalid_metadata_rejected = True
expect("invalid cached sample provenance is rejected", invalid_metadata_rejected)

expect("display variant arguments use cjpm's single run-args payload",
       run.cjpm_command("run", "24 ss2") == ["cjpm", "run", "--run-args", "24 ss2"])
expect("drift-sensitive text and table scenarios run as same-process pairs",
       ("text_layout", "pair") in run.DISPLAY_CASES and ("large_table", "pair") in run.DISPLAY_CASES
       and ("incremental_dashboard", "pair") in run.DISPLAY_CASES
       and any(item[0] == "text-stable/churn" for item in run.PAIRED_COMPARISONS)
       and any(item[0] == "large-table-5000/500" for item in run.PAIRED_COMPARISONS))
expect("observable lazy API cost uses an aligned same-process ratio",
       any(item[0] == "observable-lazy-state/manual" for item in run.PAIRED_COMPARISONS)
       and any(item[0] == "lazy-scroll-phase/full" for item in run.PAIRED_COMPARISONS)
       and any(item[0] == "lazy-index/key-cold" for item in run.PAIRED_COMPARISONS))

try:
    run.median_capture([
        ["@@RESULT|frame|g|case|100|10"],
        ["@@RESULT|frame|g|other|100|10"],
    ])
    mismatched_samples_rejected = False
except ValueError:
    mismatched_samples_rejected = True
expect("multi-sample capture rejects mismatched case sets", mismatched_samples_rejected)

try:
    run.median_capture([
        ["@@RESULT|display|g|case|100|10", distribution_line],
        ["@@RESULT|display|g|case|100|10"],
    ])
    mismatched_distributions_rejected = False
except ValueError:
    mismatched_distributions_rejected = True
expect("multi-sample capture rejects missing frame distributions", mismatched_distributions_rejected)

stability = run.capture_stability([
    ["@@RESULT|display|g|case|100|10"],
    ["@@RESULT|display|g|case|200|10"],
    ["@@RESULT|display|g|case|300|10"],
])
expect("sample stability preserves range and median absolute deviation",
       stability[0]["medianNs"] == 200 and stability[0]["relativeRange"] == 1.0
       and stability[0]["relativeMad"] == 0.5)

expect("hybrid CPU affinity chooses only the highest efficiency class",
       run.select_performance_affinity([
           {"group": 0, "logicalProcessorIndex": 0, "efficiencyClass": 2},
           {"group": 0, "logicalProcessorIndex": 1, "efficiencyClass": 2},
           {"group": 0, "logicalProcessorIndex": 2, "efficiencyClass": 0},
           {"group": 1, "logicalProcessorIndex": 0, "efficiencyClass": 3},
       ]) == 0b11
       and run.select_performance_affinity([
           {"group": 0, "logicalProcessorIndex": 0, "efficiencyClass": 0},
           {"group": 0, "logicalProcessorIndex": 1, "efficiencyClass": 0},
       ]) is None)
if run.os.name == "nt":
    live_affinity = run.apply_benchmark_affinity()
    expect("Windows benchmark affinity can be applied to the live runner process",
           live_affinity["policy"] in ("windows-highest-efficiency-class", "windows-uniform"),
           str(live_affinity))

clean_calls = []
original_run_command = run.run_command
run.CLEANED_BENCHMARK_PACKAGES.clear()
run.run_command = lambda command, package, timeout: (clean_calls.append(command) or (0, "", "", False))
run.ensure_fresh_benchmark_package(run.ROOT / "fake-package", 60)
run.ensure_fresh_benchmark_package(run.ROOT / "fake-package", 60)
run.run_command = original_run_command
run.CLEANED_BENCHMARK_PACKAGES.clear()
expect("benchmark package preflight removes incompatible build profiles exactly once",
       clean_calls == [["cjpm", "clean"]])

original_pairs = run.PAIRED_COMPARISONS
run.PAIRED_COMPARISONS = [("optimized/reference", "display|g|optimized", "display|g|reference")]
paired = run.paired_comparison_stability([
    {"kind": "display", "group": "g", "name": "optimized", "samplesNs": [50, 60, 55]},
    {"kind": "display", "group": "g", "name": "reference", "samplesNs": [100, 120, 110]},
])
run.PAIRED_COMPARISONS = original_pairs
expect("same-process paired ratios preserve aligned sample cancellation",
       len(paired) == 1 and paired[0]["median"] == 0.5 and paired[0]["relativeMad"] == 0.0)

orders = [run.rotated_display_cases(list(range(9)), sample, 3) for sample in range(3)]
expect("display rounds rotate cases across early middle and late positions",
       orders[0] == list(range(9)) and orders[1][0] == 3 and orders[2][0] == 6
       and all(sorted(order) == list(range(9)) for order in orders))
expect("same-process pair order alternates AB/BA across independent samples",
       run.counterbalanced_run_args("pair", 0) == "pair"
       and run.counterbalanced_run_args("pair", 1) == "pair reverse"
       and run.counterbalanced_run_args("24 ss2", 1) == "24 ss2")

display_pair_calls = []
original_run_cjpm = run.run_cjpm
run.run_cjpm = lambda package, action, timeout, run_args: (
    display_pair_calls.append(run_args)
    or [f"@@RESULT|display|g|case|{100 if run_args == 'pair' else 200}|1"]
)
display_pair_capture = run.run_display_sample_case("fake", "pair", 60, 0)
run.run_cjpm = original_run_cjpm
display_pair_result = run.parse_results(display_pair_capture)[2]
expect("each paired display sample aggregates both AB and BA orders",
       display_pair_calls == ["pair", "pair reverse"]
       and len(display_pair_result) == 1 and display_pair_result[0]["ns"] == 150)

repeated_pair_calls = []
original_repetitions = run.DISPLAY_CASE_REPETITIONS
run.DISPLAY_CASE_REPETITIONS = {("fake", "pair"): 3}
run.run_cjpm = lambda package, action, timeout, run_args: (
    repeated_pair_calls.append(run_args)
    or [f"@@RESULT|display|g|case|{100 if run_args == 'pair' else 200}|1"]
)
repeated_pair_capture = run.run_display_sample_case("fake", "pair", 60, 0)
run.run_cjpm = original_run_cjpm
run.DISPLAY_CASE_REPETITIONS = original_repetitions
repeated_pair_result = run.parse_results(repeated_pair_capture)[2]
expect("DVFS-sensitive paired displays use three counterbalanced within-round medians",
       repeated_pair_calls == ["pair", "pair reverse", "pair reverse", "pair", "pair", "pair reverse"]
       and len(repeated_pair_result) == 1 and repeated_pair_result[0]["ns"] == 150)

expect("allocation-sensitive dashboard is counterbalanced within every sample",
       run.DISPLAY_CASE_REPETITIONS.get(("incremental_dashboard", "pair")) == 3
       and run.DISPLAY_CASE_REPETITIONS.get(("controls_form", "40 lazy ss2")) == 3
       and run.DISPLAY_WARMUP_ROUNDS == 2)

headless_calls = []
original_run_cjpm = run.run_cjpm
run.run_cjpm = lambda package, action, timeout, run_args: headless_calls.append(run_args) or []
run.run_headless_sample(60, 1, 5)
run.run_cjpm = original_run_cjpm
headless_base_calls = [call.removesuffix(" reverse") for call in headless_calls]
expect("headless samples isolate and rotate every daily GC domain",
       len(run.HEADLESS_GROUPS) == 25 and len(set(run.HEADLESS_GROUPS)) == 25
       and set(headless_base_calls) == set(run.HEADLESS_GROUPS)
       and headless_base_calls.count("daily 9") == 11
       and headless_base_calls.count("daily 22") == 5
       and headless_base_calls.count("daily 23") == 3
       and headless_calls.count("daily 9 reverse") == 5
       and headless_calls.count("daily 22 reverse") == 2
       and len(headless_base_calls) == len(run.HEADLESS_GROUPS) + 16
       and headless_base_calls[0] != run.HEADLESS_GROUPS[0])

environment_mismatches = run.comparison_environment_mismatches(
    {"platform": "Windows", "powerSource": "battery", "effectivePowerOverlay": "best"},
    {"platform": "Windows", "powerSource": "battery", "effectivePowerOverlay": "balanced"},
)
expect("power overlay mismatch makes environments incomparable",
       any("effectivePowerOverlay" in mismatch for mismatch in environment_mismatches))
expect("battery baselines are tagged observational while AC baselines can gate",
       run.baseline_verdict_mode({"hostEnvironment": {"powerSource": "battery"}}) == "observational"
       and run.baseline_verdict_mode({"hostEnvironment": {"powerSource": "unknown"}}) == "observational"
       and run.baseline_verdict_mode({"hostEnvironment": {"powerSource": "ac"}}) == "gate")
expect("performance baselines are isolated by target platform and architecture",
       run.baseline_profile({"hostEnvironment": {"system": "Windows", "machine": "AMD64"}}) ==
       "windows-x86_64"
       and run.active_baseline_paths(
           {"hostEnvironment": {"system": "Windows", "machine": "AMD64"}}) ==
       (run.BASELINE, run.BASELINE_META)
       and run.active_baseline_paths(
           {"hostEnvironment": {"system": "Linux", "machine": "x86_64"}}) ==
       (run.PLATFORM_BASELINES / "linux-x86_64.json",
        run.PLATFORM_BASELINES / "linux-x86_64.meta.json")
       and run.active_baseline_paths(
           {"hostEnvironment": {"system": "Darwin", "machine": "arm64"}}) ==
       (run.PLATFORM_BASELINES / "macos-arm64.json",
        run.PLATFORM_BASELINES / "macos-arm64.meta.json"))
with tempfile.TemporaryDirectory() as temporary:
    power_root = Path(temporary)
    ac = power_root / "AC"
    battery = power_root / "BAT0"
    ac.mkdir()
    battery.mkdir()
    (ac / "type").write_text("Mains", encoding="utf-8")
    (ac / "online").write_text("1", encoding="utf-8")
    (battery / "type").write_text("Battery", encoding="utf-8")
    (battery / "status").write_text("Discharging", encoding="utf-8")
    expect("Linux power evidence prefers an online adapter over battery status",
           run.linux_power_environment(power_root)["powerSource"] == "ac")
    (ac / "online").write_text("0", encoding="utf-8")
    expect("Linux discharging state is observational battery evidence",
           run.linux_power_environment(power_root)["powerSource"] == "battery")
expect("macOS pmset output is parsed without locale-sensitive punctuation",
       run.parse_macos_power_source("Now drawing from 'AC Power'") == "ac"
       and run.parse_macos_power_source("Now drawing from 'Battery Power'") == "battery"
       and run.parse_macos_power_source("unknown") == "unknown")
save_alias_destination = run.baseline_capture_destination(True, False)
explicit_candidate_destination = run.baseline_capture_destination(False, True)
expect("all capture spellings stage candidates and cannot overwrite the active baseline",
       save_alias_destination == explicit_candidate_destination
       and save_alias_destination[0] == "candidate"
       and save_alias_destination[1:] == (run.BASELINE_CANDIDATE, run.BASELINE_CANDIDATE_META)
       and run.BASELINE not in save_alias_destination
       and run.BASELINE_META not in save_alias_destination)

candidate_original_pairs = run.PAIRED_COMPARISONS
run.PAIRED_COMPARISONS = [
    ("candidate-optimized/reference", "display|candidate|optimized", "display|candidate|reference"),
]
candidate_frame = [{"kind": "frame", "group": "candidate", "name": "frame", "ns": 2_000_000}]
candidate_display = [
    {"kind": "display", "group": "candidate", "name": "optimized", "ns": 1_000_000},
    {"kind": "display", "group": "candidate", "name": "reference", "ns": 2_000_000},
]
candidate_stability = [
    {"kind": "frame", "group": "candidate", "name": "frame",
     "samplesNs": [2_000_000] * 5, "medianNs": 2_000_000,
     "minNs": 2_000_000, "maxNs": 2_000_000, "relativeRange": 0.0, "relativeMad": 0.0},
    {"kind": "display", "group": "candidate", "name": "optimized",
     "samplesNs": [1_000_000] * 5, "medianNs": 1_000_000,
     "minNs": 1_000_000, "maxNs": 1_000_000, "relativeRange": 0.0, "relativeMad": 0.0},
    {"kind": "display", "group": "candidate", "name": "reference",
     "samplesNs": [2_000_000] * 5, "medianNs": 2_000_000,
     "minNs": 2_000_000, "maxNs": 2_000_000, "relativeRange": 0.0, "relativeMad": 0.0},
]
candidate_environments = [
    {"group": "candidate", "name": name, "driver": "direct3d11", "supersample": 1, "vsync": 0}
    for name in ("optimized", "reference")
]
candidate_context = {
    "source": {
        "cangjieGui": {"sourceDigest": "gui-candidate"},
        "cangjieSdl": {"sourceDigest": "sdl-candidate"},
    },
    "hostEnvironment": {"system": "Windows", "platform": "Windows", "machine": "AMD64", "powerSource": "ac",
                        "effectivePowerOverlay": "best"},
}
candidate_data, candidate_metadata = run.baseline_documents(
    candidate_frame, candidate_display, candidate_environments,
    candidate_stability, candidate_context, 5)
expect("stable AC candidate is complete and promotion-safe",
       candidate_metadata["baselineProfile"] == "windows-x86_64"
       and run.candidate_promotion_issues(candidate_data, candidate_metadata) == [])
wrong_profile_metadata = json.loads(json.dumps(candidate_metadata))
wrong_profile_metadata["baselineProfile"] = "linux-x86_64"
wrong_profile_metadata["captureDigest"] = run.baseline_capture_digest(
    candidate_data, wrong_profile_metadata)
expect("candidate profile cannot contradict its captured host",
       any("profile" in issue for issue in
           run.candidate_promotion_issues(candidate_data, wrong_profile_metadata)))
tampered_candidate = dict(candidate_data)
tampered_candidate["frame|candidate|frame"] *= 2
expect("candidate digest detects edited timing values",
       any("digest" in issue for issue in
           run.candidate_promotion_issues(tampered_candidate, candidate_metadata)))

battery_candidate_metadata = json.loads(json.dumps(candidate_metadata))
battery_candidate_metadata["verdictMode"] = "observational"
battery_candidate_metadata["hostEnvironment"]["powerSource"] = "battery"
battery_candidate_metadata["captureDigest"] = run.baseline_capture_digest(
    candidate_data, battery_candidate_metadata)
expect("observational candidate cannot be promoted into the hard gate",
       any("observational" in issue for issue in
           run.candidate_promotion_issues(candidate_data, battery_candidate_metadata)))

with tempfile.TemporaryDirectory() as temporary:
    temporary_root = Path(temporary)
    candidate_path = temporary_root / "candidate.json"
    candidate_metadata_path = temporary_root / "candidate.meta.json"
    baseline_path = temporary_root / "baseline.json"
    baseline_metadata_path = temporary_root / "baseline.meta.json"
    baseline_path.write_text("sentinel", encoding="utf-8")
    baseline_metadata_path.write_text("sentinel-meta", encoding="utf-8")
    candidate_path.write_text(json.dumps(candidate_data), encoding="utf-8")
    candidate_metadata_path.write_text(json.dumps(battery_candidate_metadata), encoding="utf-8")
    with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
        rejected_code = run.promote_baseline_candidate(
            candidate_path, candidate_metadata_path, baseline_path, baseline_metadata_path)
    expect("rejected candidate leaves the active baseline untouched",
           rejected_code == 2 and baseline_path.read_text(encoding="utf-8") == "sentinel"
           and baseline_metadata_path.read_text(encoding="utf-8") == "sentinel-meta")

    candidate_metadata_path.write_text(json.dumps(candidate_metadata), encoding="utf-8")
    with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
        promoted_code = run.promote_baseline_candidate(
            candidate_path, candidate_metadata_path, baseline_path, baseline_metadata_path)
    promoted_metadata = json.loads(baseline_metadata_path.read_text(encoding="utf-8"))
    expect("explicit promotion records its protocol and preserves the reviewed capture",
           promoted_code == 0 and json.loads(baseline_path.read_text(encoding="utf-8")) == candidate_data
           and promoted_metadata.get("promotion", {}).get("protocol") ==
           "explicit-reviewed-candidate-v1"
           and run.baseline_capture_digest(candidate_data, promoted_metadata) ==
           candidate_metadata["captureDigest"])
run.PAIRED_COMPARISONS = candidate_original_pairs

# A box reproducing the baseline: nothing moved, nothing to report.
code, out = check(frames(lambda i: 1.0))
expect("baseline reproduced -> pass", code == 0 and "No regressions" in out, out)

# A uniformly 3x slower box. The whole fleet moved together, so that is the machine, not the code —
# this is the case that made the old absolute check flag all 39 real cases at once.
code, out = check(frames(lambda i: 3.0))
expect("uniform 3x machine -> pass", code == 0 and "No regressions" in out, out)
expect("uniform 3x is reported as the machine factor", "3.00x" in out, out)

# One case twice as slow as its peers on an otherwise steady box: the gate must fail and name it.
code, out = check(frames(lambda i: 2.0 if i == 5 else 1.0))
expect("one real regression -> fail", code == 1, out)
expect("regression is named", "case5" in out, out)

# The same regression hiding underneath a 3x-slow machine: normalising must still surface it.
code, out = check(frames(lambda i: 6.0 if i == 5 else 3.0))
expect("regression under a slow machine -> fail", code == 1, out)
expect("regression is named despite the machine", "case5" in out, out)

# A case that got faster than its peers is an improvement, not a regression.
code, out = check(frames(lambda i: 0.4 if i == 7 else 1.0))
expect("an improvement -> pass", code == 0, out)

# A commit that speeds up MOST cases must not turn the untouched rest into "regressions vs peers":
# the fleet median drops below 1, and flagging normalises by max(median, 1) to absorb that.
code, out = check(frames(lambda i: 0.4 if i <= 7 else 1.0))
expect("majority improvement -> unchanged cases not flagged", code == 0 and "Regressions" not in out, out)

# Too few material cases and the median is meaningless (a lone regressed case can be its own median):
# the gate must decline to judge, not pass or fail.
small_base = {f"frame|g|case{i}": float(i * 1_000_000) for i in range(1, 4)}
small = [{"kind": "frame", "group": "g", "name": f"case{i}",
          "ns": small_base[f"frame|g|case{i}"] * (2.0 if i == 2 else 1.0)} for i in range(1, 4)]
code, out = check(small, small_base)
expect("tiny fleet -> inconclusive exit (3), not a pass", code == 3 and "INCONCLUSIVE" in out, out)

# When nothing material is comparable the gate has no coverage at all — it must say so instead of
# quietly gating the jitter-dominated sub-material cases (or printing a false 'No regressions').
micro_base = {f"frame|g|micro{i}": 100_000.0 for i in range(1, 6)}
micro = [{"kind": "frame", "group": "g", "name": f"micro{i}", "ns": 100_000.0} for i in range(1, 6)]
code, out = check(micro, micro_base)
expect("all sub-material -> inconclusive no-coverage",
       code == 3 and "INCONCLUSIVE" in out and "No regressions" not in out, out)

# A sub-material case that exploded is never a verdict, but it must be VISIBLE as an FYI line —
# a 20x jump on a 10us case can be an algorithmic slip that will scale with content.
tiny_burst_base = dict(BASE)
tiny_burst_base["frame|g|tinyburst"] = 10_000.0
tiny_burst = [{"kind": "frame", "group": "g", "name": "tinyburst", "ns": 200_000.0}]
code, out = check(frames(lambda i: 1.0) + tiny_burst, tiny_burst_base)
expect("cheap case exploding -> pass but listed as FYI",
       code == 0 and "FYI" in out and "tinyburst" in out, out)

# A genuinely noisy run (cases disagreeing wildly after normalising, as a P/E-core box does) cannot
# separate signal from scheduling noise. It must say so rather than fail on a coin flip.
random.seed(7)
code, out = check(frames(lambda i: random.uniform(0.6, 1.8)))
expect("noisy run -> inconclusive exit (3), not a false pass/fail",
       code == 3 and "INCONCLUSIVE" in out, out)

noisy_samples = [{
    "kind": "frame", "group": "g", "name": "case5", "samplesNs": [1_000_000, 2_000_000, 3_000_000],
    "medianNs": 2_000_000, "minNs": 1_000_000, "maxNs": 3_000_000,
    "relativeRange": 1.0, "relativeMad": 0.5,
}]
run.load_baseline = lambda: dict(BASE)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 2.0 if i == 5 else 1.0), [], stability=noisy_samples)
expect("a dispersed suspect becomes inconclusive instead of a regression",
       code == 3 and "sample dispersion" in buf.getvalue(), buf.getvalue())

fast_domain_samples = [{
    "kind": "frame", "group": "g", "name": "case5",
    "samplesNs": [2_000_000, 2_000_000, 900_000, 2_000_000, 2_000_000],
    "medianNs": 2_000_000, "minNs": 900_000, "maxNs": 2_000_000,
    "relativeRange": 0.55, "relativeMad": 0.0,
}]
run.load_baseline = lambda: dict(BASE)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 2.0 if i == 5 else 1.0), [], stability=fast_domain_samples)
expect("a faster-core outlier makes a slow cluster inconclusive instead of a false regression",
       code == 3 and "sample dispersion" in buf.getvalue(), buf.getvalue())

display_base = {f"display|dg|case{i}": float(i * 1_000_000) for i in range(1, 13)}
display_records = [
    {"kind": "display", "group": "dg", "name": f"case{i}",
     "ns": display_base[f"display|dg|case{i}"] * (2.0 if i == 5 else 1.0)}
    for i in range(1, 13)
]
display_environments = [
    {"group": "dg", "name": f"case{i}", "driver": "direct3d11", "supersample": 1, "vsync": 0}
    for i in range(1, 13)
]
run.load_baseline = lambda: {**BASE, **display_base}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 3.0), display_records, display_environments)
expect("headless and display domains normalise independently",
       code == 1 and "display|dg|case5" in buf.getvalue(), buf.getvalue())

source = {
    "cangjieGui": {"sourceDigest": "gui"},
    "cangjieSdl": {"sourceDigest": "sdl"},
}
baseline_metadata = {
    "schemaVersion": 1,
    "samples": 3,
    "source": source,
    "hostEnvironment": {"platform": "Windows", "powerSource": "battery",
                        "effectivePowerOverlay": "best"},
    "displayEnvironments": {},
}
current_context = {
    "source": source,
    "hostEnvironment": {"platform": "Windows", "powerSource": "battery",
                        "effectivePowerOverlay": "balanced"},
}
run.load_baseline = lambda: dict(BASE)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 1.0), [], baseline_metadata=baseline_metadata,
                                 current_context=current_context)
expect("incompatible power profile is a setup error, never a regression verdict",
       code == 2 and "not comparable" in buf.getvalue(), buf.getvalue())

# A laptop on battery can keep the selected Windows overlay while firmware silently changes clocks as
# charge and temperature move. Such a run is useful evidence, but it must never emit a hard pass/fail.
battery_baseline = {
    "schemaVersion": 1,
    "samples": 5,
    "source": {
        "cangjieGui": {"sourceDigest": "gui-before"},
        "cangjieSdl": {"sourceDigest": "sdl"},
    },
    "hostEnvironment": {"platform": "Windows", "powerSource": "battery",
                        "effectivePowerOverlay": "best"},
    "displayEnvironments": {},
}
battery_current = {
    "source": {
        "cangjieGui": {"sourceDigest": "gui-after"},
        "cangjieSdl": {"sourceDigest": "sdl"},
    },
    "hostEnvironment": {"platform": "Windows", "powerSource": "battery",
                        "effectivePowerOverlay": "best"},
}
run.load_baseline = lambda: dict(BASE)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 2.0 if i == 5 else 1.0), [],
                                 baseline_metadata=battery_baseline, current_context=battery_current)
expect("battery capture is observational and cannot false-fail",
       code == 3 and "battery" in buf.getvalue().lower() and "case5" in buf.getvalue(), buf.getvalue())

# Replaying the exact same sources is a control experiment. A stable timing shift then proves an
# unmodelled environment/session effect, not a code regression, even on nominally controlled AC.
same_source = {
    "cangjieGui": {"sourceDigest": "gui-same"},
    "cangjieSdl": {"sourceDigest": "sdl-same"},
}
same_source_baseline = {
    "schemaVersion": 1,
    "samples": 5,
    "source": same_source,
    "hostEnvironment": {"platform": "Windows", "powerSource": "AC",
                        "effectivePowerOverlay": "best"},
    "displayEnvironments": {},
}
same_source_current = {
    "source": same_source,
    "hostEnvironment": {"platform": "Windows", "powerSource": "AC",
                        "effectivePowerOverlay": "best"},
}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 2.0 if i == 5 else 1.0), [],
                                 baseline_metadata=same_source_baseline,
                                 current_context=same_source_current)
expect("same-source replay drift is inconclusive instead of a false regression",
       code == 3 and "same source" in buf.getvalue().lower() and "case5" in buf.getvalue(),
       buf.getvalue())

observational_baseline = dict(same_source_baseline)
observational_baseline["verdictMode"] = "observational"
changed_source_current = {
    "source": {
        "cangjieGui": {"sourceDigest": "gui-new"},
        "cangjieSdl": {"sourceDigest": "sdl-same"},
    },
    "hostEnvironment": dict(same_source_current["hostEnvironment"]),
}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 1.0), [],
                                 baseline_metadata=observational_baseline,
                                 current_context=changed_source_current)
expect("observational baseline can never produce a hard pass",
       code == 3 and "baseline is observational" in buf.getvalue().lower(), buf.getvalue())

# Display domains intentionally isolate backend/supersample/vsync. Six independent material workloads
# are enough for a robust median and MAD; requiring the old global fleet of eight made the ss1 domain
# permanently inconclusive after sub-material timing cases were correctly excluded.
six_base = {f"display|six|case{i}": float(i * 1_000_000) for i in range(1, 7)}
six_display = [
    {"kind": "display", "group": "six", "name": f"case{i}",
     "ns": six_base[f"display|six|case{i}"] * (2.0 if i == 4 else 1.0)}
    for i in range(1, 7)
]
six_environment = [
    {"group": "six", "name": f"case{i}", "driver": "direct3d11", "supersample": 1, "vsync": 0}
    for i in range(1, 7)
]
run.load_baseline = lambda: dict(six_base)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions([], six_display, six_environment)
expect("six-case display domain can produce a regression verdict",
       code == 1 and "display|six|case4" in buf.getvalue(), buf.getvalue())

# A case too cheap to cost a frame doubling is not a regression: 10us -> 20us cannot hurt anything,
# and sub-millisecond cases are where nearly all the jitter lives.
tiny_base = dict(BASE)
tiny_base["frame|g|tiny"] = 10_000.0
tiny = [{"kind": "frame", "group": "g", "name": "tiny", "ns": 20_000.0}]
code, out = check(frames(lambda i: 1.0) + tiny, tiny_base)
expect("sub-material case is FYI only", code == 0 and "FYI" in out and "tiny" in out, out)

# With no baseline there is nothing to compare against, which is a setup error, not a pass.
run.load_baseline = lambda: {}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 1.0), [])
expect("missing baseline -> setup error (2)", code == 2, buf.getvalue())

incomplete_base = dict(BASE)
incomplete_base.pop("frame|g|case12")
code, out = check(frames(lambda i: 1.0), incomplete_base)
expect("new benchmark without baseline -> coverage error (2)",
       code == 2 and "not gated" in out and "case12" in out, out)

print()
if failures:
    print(f"{len(failures)} FAILED: {failures}")
    sys.exit(1)
print("all gate self-tests passed")
