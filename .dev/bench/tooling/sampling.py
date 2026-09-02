"""Counterbalanced execution and robust multi-sample aggregation."""

import statistics

from bench.tooling.config import (
    DISPLAY_CASE_REPETITIONS,
    HEADLESS_GROUP_REPETITIONS,
    HEADLESS_GROUPS,
    PAIRED_COMPARISONS,
)
from bench.tooling.execution import run_cjpm
from bench.tooling.parsing import (
    index_counts,
    index_distributions,
    index_environments,
    index_records,
    median_int,
    parse_benchmark_environments,
    parse_counts,
    parse_frame_distributions,
    parse_results,
)
from cui_dev.common.paths import workload

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


def counterbalanced_run_args(run_args, sample_index):
    """Alternate the internal order of same-process pairs across independent samples."""
    if run_args == "pair" and sample_index % 2 == 1:
        return "pair reverse"
    return run_args


def run_display_sample_case(app, run_args, timeout, sample_index):
    """Capture pair variants in both orders before they become one independent sample."""
    effective_run_args = counterbalanced_run_args(run_args, sample_index)
    repetitions = DISPLAY_CASE_REPETITIONS.get((app, run_args), 1)
    if run_args != "pair":
        captures = [
            run_cjpm(workload("display", app), "run", timeout, effective_run_args)
            for _ in range(repetitions)
        ]
        return median_capture(captures) if repetitions > 1 else captures[0]
    reverse_run_args = "pair" if effective_run_args == "pair reverse" else "pair reverse"
    captures = []
    for repetition in range(repetitions):
        first = effective_run_args if repetition % 2 == 0 else reverse_run_args
        second = reverse_run_args if repetition % 2 == 0 else effective_run_args
        captures.append(median_capture([
            run_cjpm(workload("display", app), "run", timeout, first),
            run_cjpm(workload("display", app), "run", timeout, second),
        ]))
    return median_capture(captures) if repetitions > 1 else captures[0]


def run_headless_sample(timeout, sample_index, sample_count):
    """Run the complete headless key set with a fresh process per GC/ownership domain."""
    lines = []
    for run_args in rotated_display_cases(HEADLESS_GROUPS, sample_index, sample_count):
        repetitions = HEADLESS_GROUP_REPETITIONS.get(run_args, 1)
        captures = []
        for repetition in range(repetitions):
            counterbalanced = run_args in ("daily 9", "daily 22") and repetition % 2 == 1
            effective_run_args = f"{run_args} reverse" if counterbalanced \
                else run_args
            captures.append(run_cjpm(
                workload("headless", "micro"), "run", timeout, effective_run_args))
        lines.extend(median_capture(captures) if repetitions > 1 else captures[0])
    return lines
