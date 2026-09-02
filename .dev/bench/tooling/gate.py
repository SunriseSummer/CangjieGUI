"""Noise-aware, machine-normalized performance regression decisions."""

import statistics
import sys

from bench.tooling.baseline import index_display_environments, load_baseline
from bench.tooling.config import (
    MACHINE_NOTE,
    MATERIAL_NS,
    MIN_FLEET,
    NOISE_K,
    NOISE_LIMIT,
    PAIRED_COMPARISONS,
    REGRESSION,
    SAMPLE_FAST_DOMAIN_RATIO,
    SAMPLE_MAD_LIMIT,
)
from bench.tooling.parsing import comparison_environment_mismatches
from bench.tooling.reporting import fmt_dur
from bench.tooling.sampling import paired_comparison_stability

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
        fast_domain_outlier = record["kind"] == "frame" and sample is not None and \
            sample.get("medianNs", 0) > 0 and \
            sample.get("minNs", 0) < sample["medianNs"] * SAMPLE_FAST_DOMAIN_RATIO
        if material and sample is not None and (sample["relativeMad"] > SAMPLE_MAD_LIMIT or fast_domain_outlier):
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
            issues.append(f"unstable baseline case {key}: sample MAD {sample['relativeMad'] * 100:.0f}%, "
                          f"range {sample['relativeRange'] * 100:.0f}%")
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
        print("No baseline.json; capture and promote a reviewed baseline candidate first.", file=sys.stderr)
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
        print("Capture the complete intended suite, review it, then promote the candidate.", file=sys.stderr)
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
        print(f"\nINCONCLUSIVE sample dispersion (MAD limit {SAMPLE_MAD_LIMIT * 100:.0f}%; "
              f"fast-domain floor {SAMPLE_FAST_DOMAIN_RATIO * 100:.0f}% of median):")
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
