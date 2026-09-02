"""Constants and canonical paths for the benchmark suite."""

from cui_dev.common.paths import BENCH_RESULTS_ROOT, BENCH_ROOT

ROOT = BENCH_ROOT
RESULTS = BENCH_RESULTS_ROOT
TEMPLATE = ROOT / "templates" / "report.html"
RAW = RESULTS / "micro.out.txt"
CAPTURE_META = RESULTS / "capture.meta.json"
REPORT = RESULTS / "report.html"
JSON_REPORT = RESULTS / "report.json"
CHECK_JSON_REPORT = RESULTS / "check.json"
BASELINE_CAPTURE_JSON_REPORT = RESULTS / "baseline-capture.json"
BASELINE = ROOT / "baselines" / "default" / "baseline.json"
BASELINE_META = ROOT / "baselines" / "default" / "baseline.meta.json"
PLATFORM_BASELINES = ROOT / "baselines"
BASELINE_CANDIDATE = RESULTS / "baseline-candidate.json"
BASELINE_CANDIDATE_META = RESULTS / "baseline-candidate.meta.json"
BUILT_WINDOWS_PACKAGES = set()
CLEANED_BENCHMARK_PACKAGES = set()
LAST_WINDOWS_BENCHMARK_END = None
WINDOWS_BENCHMARK_COOLDOWN_SECONDS = 1.0
BENCHMARK_AFFINITY = {"policy": "not-configured"}

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
# A lone slow sample is safely rejected by the median. A lone sample more than 30% *faster* than
# the median is different: on hybrid Windows CPUs it proves that the same process sometimes ran on
# a faster core class, so the slower cluster cannot be called a code regression with confidence.
SAMPLE_FAST_DOMAIN_RATIO = 0.70

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
    ("controls_form", "40 measured ss2"),
    ("large_table", "pair"),
    ("incremental_dashboard", "pair"),
]
DISPLAY_CASE_REPETITIONS = {
    ("planner_scroll", "pair"): 3,
    ("controls_form", "12 ss2"): 3,
    ("controls_form", "40 lazy ss2"): 3,
    ("incremental_dashboard", "pair"): 3,
}
DISPLAY_WARMUP_ROUNDS = 2

HEADLESS_GROUPS = [f"daily {index}" for index in range(25)]
HEADLESS_GROUP_REPETITIONS = {
    "daily 9": 11,
    "daily 22": 5,
    "daily 23": 3,
}

# Ratios whose numerator is the optimized path. Both sides are emitted by one benchmark process, so
# they cancel most CPU/GPU power and presentation drift that absolute cross-process times cannot.
PAIRED_COMPARISONS = [
    ("lazy-index/key-cold",
     "frame|scrollToIndex 扩展性|100000 项随机 scrollToIndex+帧",
     "frame|scrollToKey 扩展性|100000 项随机 scrollToKey+帧"),
    ("lazy-scroll-phase/full",
     "frame|LazyColumn 滚动相位|增量物化",
     "frame|LazyColumn 滚动相位|强制全量"),
    ("observable-lazy-state/manual",
     "frame|可观察惰性数据|10000 项 State 自动版本",
     "frame|可观察惰性数据|10000 项 显式 snapshot+revision"),
    ("primitive-batch/single",
     "display|原语提交（上机实测）|2048 rect 相邻批处理",
     "display|原语提交（上机实测）|2048 rect 单条提交"),
    ("text-stable/churn",
     "display|段落布局（上机实测）|20000 字 热缓存",
     "display|段落布局（上机实测）|20000 字 LRU 冷抖动"),
    ("planner-ss1/ss2",
     "display|内容页滚动（上机实测）|16 区块 ss1x",
     "display|内容页滚动（上机实测）|16 区块 ss2x"),
    ("planner-auto/ss1",
     "display|内容页滚动（上机实测）|16 区块 Auto",
     "display|内容页滚动（上机实测）|16 区块 ss1x"),
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
