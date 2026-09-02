"""benchmark capture and scheduling contracts"""

from bench.tests.runner_test_support import *

print("benchmark capture and scheduling contracts\n")

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
original_run_command = execution.run_command
run.CLEANED_BENCHMARK_PACKAGES.clear()
execution.run_command = lambda command, package, timeout: (clean_calls.append(command) or (0, "", "", False))
run.ensure_fresh_benchmark_package(run.ROOT / "fake-package", 60)
run.ensure_fresh_benchmark_package(run.ROOT / "fake-package", 60)
execution.run_command = original_run_command
run.CLEANED_BENCHMARK_PACKAGES.clear()
expect("benchmark package preflight removes incompatible build profiles exactly once",
       clean_calls == [["cjpm", "clean"]])

original_pairs = sampling.PAIRED_COMPARISONS
sampling.PAIRED_COMPARISONS = [("optimized/reference", "display|g|optimized", "display|g|reference")]
paired = run.paired_comparison_stability([
    {"kind": "display", "group": "g", "name": "optimized", "samplesNs": [50, 60, 55]},
    {"kind": "display", "group": "g", "name": "reference", "samplesNs": [100, 120, 110]},
])
sampling.PAIRED_COMPARISONS = original_pairs
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
original_run_cjpm = sampling.run_cjpm
sampling.run_cjpm = lambda package, action, timeout, run_args: (
    display_pair_calls.append(run_args)
    or [f"@@RESULT|display|g|case|{100 if run_args == 'pair' else 200}|1"]
)
display_pair_capture = run.run_display_sample_case("fake", "pair", 60, 0)
sampling.run_cjpm = original_run_cjpm
display_pair_result = run.parse_results(display_pair_capture)[2]
expect("each paired display sample aggregates both AB and BA orders",
       display_pair_calls == ["pair", "pair reverse"]
       and len(display_pair_result) == 1 and display_pair_result[0]["ns"] == 150)

repeated_pair_calls = []
original_repetitions = sampling.DISPLAY_CASE_REPETITIONS
sampling.DISPLAY_CASE_REPETITIONS = {("fake", "pair"): 3}
sampling.run_cjpm = lambda package, action, timeout, run_args: (
    repeated_pair_calls.append(run_args)
    or [f"@@RESULT|display|g|case|{100 if run_args == 'pair' else 200}|1"]
)
repeated_pair_capture = run.run_display_sample_case("fake", "pair", 60, 0)
sampling.run_cjpm = original_run_cjpm
sampling.DISPLAY_CASE_REPETITIONS = original_repetitions
repeated_pair_result = run.parse_results(repeated_pair_capture)[2]
expect("DVFS-sensitive paired displays use three counterbalanced within-round medians",
       repeated_pair_calls == ["pair", "pair reverse", "pair reverse", "pair", "pair", "pair reverse"]
       and len(repeated_pair_result) == 1 and repeated_pair_result[0]["ns"] == 150)

expect("allocation-sensitive dashboard is counterbalanced within every sample",
       run.DISPLAY_CASE_REPETITIONS.get(("incremental_dashboard", "pair")) == 3
       and run.DISPLAY_CASE_REPETITIONS.get(("controls_form", "40 lazy ss2")) == 3
       and run.DISPLAY_WARMUP_ROUNDS == 2)

headless_calls = []
original_run_cjpm = sampling.run_cjpm
sampling.run_cjpm = lambda package, action, timeout, run_args: headless_calls.append(run_args) or []
run.run_headless_sample(60, 1, 5)
sampling.run_cjpm = original_run_cjpm
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

finish()
