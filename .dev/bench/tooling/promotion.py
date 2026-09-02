"""Review and explicit promotion of benchmark baseline candidates."""

import hashlib
import json
import shutil
import statistics
import sys
from datetime import datetime

from bench.tooling.baseline import (
    active_baseline_paths,
    baseline_capture_digest,
    baseline_profile,
    baseline_verdict_mode,
)
from bench.tooling.config import (
    BASELINE_CANDIDATE,
    BASELINE_CANDIDATE_META,
    PAIRED_COMPARISONS,
    SAMPLE_MAD_LIMIT,
)
from bench.tooling.gate import unstable_material_keys
from bench.tooling.io import write_text_lf
from bench.tooling.sampling import paired_comparison_stability

def candidate_promotion_issues(data, metadata):
    """Return every reason a staged capture is unsafe to make the hard regression baseline."""
    issues = []
    if not isinstance(data, dict) or not isinstance(metadata, dict):
        return ["candidate values and provenance must both be JSON objects"]
    if metadata.get("schemaVersion") != 1:
        issues.append("candidate provenance is missing or has an unsupported schema")
    recorded_profile = metadata.get("baselineProfile")
    derived_profile = baseline_profile({"hostEnvironment": metadata.get("hostEnvironment", {})})
    if recorded_profile is not None and recorded_profile != derived_profile:
        issues.append("candidate baseline profile does not match its captured host")
    if metadata.get("verdictMode") != "gate":
        issues.append("candidate is observational; only a stable AC capture can be promoted")
    if baseline_verdict_mode({"hostEnvironment": metadata.get("hostEnvironment", {})}) != "gate":
        issues.append("candidate host environment is not eligible for a hard gate")
    try:
        sample_count = int(metadata.get("samples", 0))
    except (TypeError, ValueError):
        sample_count = 0
    if sample_count < 3:
        issues.append("candidate used fewer than 3 independent samples")

    expected_digest = metadata.get("captureDigest")
    try:
        actual_digest = baseline_capture_digest(data, metadata)
    except (TypeError, ValueError):
        actual_digest = None
    if not expected_digest or actual_digest != expected_digest:
        issues.append("candidate capture digest is missing or does not match its values/provenance")

    source = metadata.get("source", {})
    source = source if isinstance(source, dict) else {}
    for repository in ("cangjieGui", "cangjieSdl"):
        fingerprint = source.get(repository, {})
        fingerprint = fingerprint if isinstance(fingerprint, dict) else {}
        digest = fingerprint.get("sourceDigest")
        if digest in (None, "", "unavailable"):
            issues.append(f"candidate lacks a usable {repository} source fingerprint")

    stability = metadata.get("sampleStability", [])
    if not isinstance(stability, list):
        stability = []
        issues.append("candidate sample stability must be an array")
    expected_keys = []
    records = []
    valid_stability = []
    for sample in stability:
        if not isinstance(sample, dict):
            issues.append("candidate contains a malformed sample stability record")
            continue
        if sample.get("kind") not in ("frame", "display"):
            continue
        key = f"{sample.get('kind')}|{sample.get('group')}|{sample.get('name')}"
        expected_keys.append(key)
        samples = sample.get("samplesNs", [])
        samples = samples if isinstance(samples, list) else []
        if len(samples) != sample_count:
            issues.append(f"candidate sample count mismatch for {key}")
        numeric_samples = (len(samples) == sample_count and all(
            isinstance(item, (int, float)) and not isinstance(item, bool)
            and float("-inf") < item < float("inf") and item >= 0 for item in samples))
        if not numeric_samples:
            issues.append(f"candidate has malformed independent samples for {key}")
        value = data.get(key)
        if not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
            issues.append(f"candidate has no positive finite value for {key}")
            continue
        if (not isinstance(value, bool) and isinstance(value, (int, float))
                and not (float("-inf") < value < float("inf"))):
            issues.append(f"candidate has no positive finite value for {key}")
            continue
        if numeric_samples and statistics.median(samples) != value:
            issues.append(f"candidate median does not match captured samples for {key}")
        mad = sample.get("relativeMad")
        if (not isinstance(mad, (int, float)) or isinstance(mad, bool)
                or not float("-inf") < mad < float("inf") or mad < 0):
            issues.append(f"candidate has no valid MAD for {key}")
            continue
        records.append({
            "kind": sample.get("kind"), "group": sample.get("group"),
            "name": sample.get("name"), "ns": value,
        })
        valid_stability.append(sample)

    if not expected_keys or not any(key.startswith("frame|") for key in expected_keys):
        issues.append("candidate does not contain the headless frame suite")
    if not any(key.startswith("display|") for key in expected_keys):
        issues.append("candidate does not contain the real-window display suite")
    if len(expected_keys) != len(set(expected_keys)):
        issues.append("candidate contains duplicate frame/display stability records")
    if set(data) != set(expected_keys):
        missing = sorted(set(expected_keys) - set(data))
        unexpected = sorted(set(data) - set(expected_keys))
        if missing:
            issues.append(f"candidate is missing {len(missing)} captured frame/display case(s)")
        if unexpected:
            issues.append(f"candidate contains {len(unexpected)} uncaptured frame/display case(s)")

    display_keys = {key.removeprefix("display|") for key in expected_keys if key.startswith("display|")}
    display_environments = metadata.get("displayEnvironments", {})
    display_environments = display_environments if isinstance(display_environments, dict) else {}
    environment_keys = set(display_environments)
    if display_keys != environment_keys:
        issues.append("candidate display environments do not exactly cover its display cases")

    expected_pairs = [item[0] for item in PAIRED_COMPARISONS]
    pairs = metadata.get("pairedComparisons", [])
    if not isinstance(pairs, list):
        pairs = []
        issues.append("candidate paired A/B evidence must be an array")
    elif any(not isinstance(item, dict) for item in pairs):
        issues.append("candidate contains a malformed paired A/B record")
        pairs = [item for item in pairs if isinstance(item, dict)]
    actual_pairs = [item.get("name") for item in pairs]
    if sorted(actual_pairs) != sorted(expected_pairs):
        issues.append("candidate paired A/B coverage does not match the current benchmark contract")
    for item in pairs:
        mad = item.get("relativeMad")
        if (not isinstance(mad, (int, float)) or isinstance(mad, bool)
                or not float("-inf") < mad < float("inf") or mad < 0):
            issues.append(f"candidate has no valid paired MAD for {item.get('name')}")
        elif mad > SAMPLE_MAD_LIMIT:
            issues.append(f"unstable paired candidate {item.get('name')}: ratio MAD "
                          f"{mad * 100:.0f}%")

    for key, sample in sorted(unstable_material_keys(records, valid_stability, data).items()):
        issues.append(f"unstable candidate case {key}: sample MAD {sample['relativeMad'] * 100:.0f}%")
    return issues


def promote_baseline_candidate(
        candidate_path=None, candidate_metadata_path=None,
        baseline_path=None, baseline_metadata_path=None):
    candidate_path = candidate_path or BASELINE_CANDIDATE
    candidate_metadata_path = candidate_metadata_path or BASELINE_CANDIDATE_META
    if not candidate_path.exists() or not candidate_metadata_path.exists():
        print("No complete baseline candidate; capture one with --capture-baseline-candidate.", file=sys.stderr)
        return 2
    try:
        data = json.loads(candidate_path.read_text(encoding="utf-8"))
        metadata = json.loads(candidate_metadata_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"Cannot read baseline candidate: {error}", file=sys.stderr)
        return 2
    issues = candidate_promotion_issues(data, metadata)
    candidate_context = {"hostEnvironment": metadata.get("hostEnvironment", {})}
    candidate_profile = metadata.get("baselineProfile") or baseline_profile(candidate_context)
    current_profile = baseline_profile()
    if candidate_profile != current_profile:
        issues.append(
            f"candidate belongs to {candidate_profile}, but promotion is running on {current_profile}")
    if issues:
        print("Baseline candidate cannot be promoted:", file=sys.stderr)
        for issue in issues:
            print(f"  {issue}", file=sys.stderr)
        return 2
    default_baseline_path, default_baseline_metadata_path = active_baseline_paths(candidate_context)
    baseline_path = baseline_path or default_baseline_path
    baseline_metadata_path = baseline_metadata_path or default_baseline_metadata_path
    promoted = dict(metadata)
    promoted["promotion"] = {
        "promotedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
        "protocol": "explicit-reviewed-candidate-v1",
    }
    write_text_lf(baseline_path, json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    write_text_lf(
        baseline_metadata_path,
        json.dumps(promoted, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    print(f"Promoted reviewed AC baseline candidate ({len(data)} cases) to {baseline_path}.")
    print(f"Promotion audit record saved to {baseline_metadata_path}.")
    return 0
