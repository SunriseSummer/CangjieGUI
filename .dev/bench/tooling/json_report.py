"""Complete machine-readable benchmark evidence reports."""

import json
import statistics
from datetime import datetime

from bench.tooling.baseline import (
    active_baseline_paths,
    baseline_profile,
    index_display_environments,
    load_baseline,
    load_baseline_metadata,
)
from bench.tooling.config import FRAME_120, FRAME_30, FRAME_60
from bench.tooling.environment import git_commit, toolchain
from bench.tooling.gate import benchmark_domain, machine_factor, unstable_material_keys
from bench.tooling.io import write_text_lf
from bench.tooling.sampling import paired_comparison_stability

def write_json_report(
        path, frame, micro, display, distributions, display_environments,
        counts, sample_count, check_code, context, stability, baseline_capture=None):
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
        "baselineProfile": baseline_profile(context),
        "activeBaseline": str(active_baseline_paths(context)[0]),
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
    if baseline_capture is not None:
        payload["baselineCapture"] = baseline_capture
    write_text_lf(path, json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
