"""Strict parsers and indexes for benchmark machine records."""

import statistics

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
    for variant in ("ss2x", "Auto", "ss1x"):
        prefix = f"16 区块 {variant} text "
        if any(key[0] == planner_group and key[1].startswith(prefix) for key in values):
            measure_name = f"16 区块 {variant} text measures"
            compute_name = f"16 区块 {variant} text computes"
            measures = values.get((planner_group, measure_name))
            computes = values.get((planner_group, compute_name))
            if measures is None or computes is None or measures <= 0:
                issues.append(f"{variant} text-cache diagnostics are incomplete")
            elif computes * 100 >= measures:
                issues.append(
                    f"{variant} scaled text-metrics cache lost warm reuse: {computes} computes / {measures} measures"
                )

    sampling_suffix = " sampling target pixels"
    sampling_keys = [key for key in values if key[1].endswith(sampling_suffix)]
    for group, pixel_name in sampling_keys:
        prefix = pixel_name[:-len(sampling_suffix)]
        pixels = values[(group, pixel_name)]
        target_bytes = values.get((group, f"{prefix} sampling target bytes"))
        max_texture_edge = values.get((group, f"{prefix} max texture edge"))
        if target_bytes is None or max_texture_edge is None:
            issues.append(f"{prefix} render-sampling diagnostics are incomplete")
        elif target_bytes != pixels * 4 or max_texture_edge <= 0:
            issues.append(
                f"{prefix} render-sampling resource accounting is inconsistent: "
                f"pixels={pixels}, bytes={target_bytes}, max edge={max_texture_edge}"
            )

    controls_group = "控件密集表单（上机实测）"
    full_draw_name = "40 分区 全量 ss2x text draws"
    lazy_draw_name = "40 分区 窗口化 ss2x text draws"
    full_draws = values.get((controls_group, full_draw_name))
    lazy_draws = values.get((controls_group, lazy_draw_name))
    if full_draws is not None or lazy_draws is not None:
        if full_draws is None or lazy_draws is None or lazy_draws <= 0:
            issues.append("controls-form paint-culling diagnostics are incomplete")
        elif full_draws > lazy_draws * 2:
            issues.append(
                f"ordinary ScrollView lost paint culling: {full_draws} full draws / {lazy_draws} virtualized draws"
            )
    measured_draw_name = "40 分区 自测量 ss2x text draws"
    measured_measure_name = "40 分区 自测量 ss2x text measures"
    full_measure_name = "40 分区 全量 ss2x text measures"
    measured_draws = values.get((controls_group, measured_draw_name))
    measured_measures = values.get((controls_group, measured_measure_name))
    full_measures = values.get((controls_group, full_measure_name))
    if measured_draws is not None or measured_measures is not None:
        if (measured_draws is None or measured_measures is None or full_measures is None
                or lazy_draws is None or lazy_draws <= 0):
            issues.append("self-measuring virtualization diagnostics are incomplete")
        else:
            if measured_draws > lazy_draws * 2:
                issues.append(
                    f"self-measuring list lost paint windowing: {measured_draws} measured draws / "
                    f"{lazy_draws} fixed draws"
                )
            if measured_measures * 4 >= full_measures:
                issues.append(
                    f"self-measuring list lost layout windowing: {measured_measures} measured / "
                    f"{full_measures} full measures"
                )

    lazy_phase_group = "LazyColumn 滚动相位"
    lazy_phase_keys = [key for key in values if key[0] == lazy_phase_group]
    if lazy_phase_keys:
        incremental_bodies = values.get((lazy_phase_group, "增量 body 总执行"))
        full_bodies = values.get((lazy_phase_group, "强制全量 body 总执行"))
        incremental_passes = values.get((lazy_phase_group, "增量稳定化总 pass"))
        if incremental_bodies is None or full_bodies is None or incremental_passes is None:
            issues.append("lazy scroll phase-split diagnostics are incomplete")
        elif (full_bodies != 800 or incremental_bodies * 4 >= full_bodies
              or incremental_passes != 800 + incremental_bodies):
            issues.append(
                "lazy scroll phase split lost discrete materialization: "
                f"incremental bodies={incremental_bodies}, full bodies={full_bodies}, "
                f"incremental passes={incremental_passes}"
            )

    lazy_navigation_groups = {"scrollToKey 扩展性", "scrollToIndex 扩展性"}
    if any(key[0] in lazy_navigation_groups for key in values):
        index_10k = values.get(("scrollToIndex 扩展性", "10000 项平均 key 访问"))
        index_100k = values.get(("scrollToIndex 扩展性", "100000 项平均 key 访问"))
        key_10k = values.get(("scrollToKey 扩展性", "10000 项平均 key 访问"))
        key_100k = values.get(("scrollToKey 扩展性", "100000 项平均 key 访问"))
        if index_10k is None or index_100k is None or key_10k is None or key_100k is None:
            issues.append("lazy index/key navigation diagnostics are incomplete")
        elif (index_10k > 128 or index_100k > 128 or index_100k > index_10k * 2
              or key_100k <= index_100k * 10 or key_100k <= key_10k * 5):
            issues.append(
                "lazy index navigation lost total-size independence: "
                f"index 10k/100k={index_10k}/{index_100k}, key 10k/100k={key_10k}/{key_100k}"
            )

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

def comparison_environment_mismatches(baseline, current):
    """List stable host/power fields that make two absolute benchmark runs incomparable."""
    fields = (
        "platform", "machine", "processor", "logicalCpuCount", "powerSource",
        "powerScheme", "effectivePowerOverlay", "videoControllers", "benchmarkAffinity",
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
