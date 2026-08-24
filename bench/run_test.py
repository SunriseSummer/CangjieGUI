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
import random
import sys
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
    {"group": "内容页滚动（上机实测）", "name": "16 区块 ss1x text computes", "count": 60},
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
       and any(item[0] == "text-stable/churn" for item in run.PAIRED_COMPARISONS)
       and any(item[0] == "large-table-5000/500" for item in run.PAIRED_COMPARISONS))

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

environment_mismatches = run.comparison_environment_mismatches(
    {"platform": "Windows", "powerSource": "battery", "effectivePowerOverlay": "best"},
    {"platform": "Windows", "powerSource": "battery", "effectivePowerOverlay": "balanced"},
)
expect("power overlay mismatch makes environments incomparable",
       any("effectivePowerOverlay" in mismatch for mismatch in environment_mismatches))
expect("battery baselines are tagged observational while AC baselines can gate",
       run.baseline_verdict_mode({"hostEnvironment": {"powerSource": "battery"}}) == "observational"
       and run.baseline_verdict_mode({"hostEnvironment": {"powerSource": "ac"}}) == "gate")

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
