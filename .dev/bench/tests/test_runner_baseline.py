"""benchmark baseline lifecycle contracts"""

from bench.tests.runner_test_support import *

print("benchmark baseline lifecycle contracts\n")

candidate_original_pairs = sampling.PAIRED_COMPARISONS
sampling.PAIRED_COMPARISONS = [
    ("candidate-optimized/reference", "display|candidate|optimized", "display|candidate|reference"),
]
promotion.PAIRED_COMPARISONS = sampling.PAIRED_COMPARISONS
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
sampling.PAIRED_COMPARISONS = candidate_original_pairs
promotion.PAIRED_COMPARISONS = candidate_original_pairs

finish()
