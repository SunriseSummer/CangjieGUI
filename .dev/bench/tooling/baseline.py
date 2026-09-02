"""Platform-qualified performance baseline storage and metadata."""

import hashlib
import json
import platform
from datetime import datetime
from pathlib import Path

from bench.tooling.config import BASELINE, BASELINE_META, PLATFORM_BASELINES
from bench.tooling.io import write_text_lf
from bench.tooling.sampling import paired_comparison_stability

def baseline_profile(context=None):
    """Return the host family/architecture that owns one non-portable performance baseline."""
    if context is None:
        system = platform.system()
        machine = platform.machine()
    else:
        environment = context.get("hostEnvironment", {})
        system = str(environment.get("system", "")).strip()
        machine = str(environment.get("machine", "")).strip()
        if not system:
            platform_name = str(environment.get("platform", "")).lower()
            if platform_name.startswith("windows"):
                system = "windows"
            elif platform_name.startswith("linux"):
                system = "linux"
            elif platform_name.startswith(("macos", "darwin")):
                system = "macos"
    system_key = {"windows": "windows", "linux": "linux", "darwin": "macos", "macos": "macos"}.get(
        system.lower(), system.lower() or "unknown")
    machine_key = {
        "amd64": "x86_64", "x86_64": "x86_64", "x64": "x86_64",
        "arm64": "arm64", "aarch64": "arm64",
    }.get(machine.lower(), machine.lower() or "unknown")
    safe_system = "".join(char if char.isalnum() or char in "-_" else "-" for char in system_key)
    safe_machine = "".join(char if char.isalnum() or char in "-_" else "-" for char in machine_key)
    return f"{safe_system}-{safe_machine}"


def active_baseline_paths(context=None):
    """Keep the checked-in Windows x64 path compatible; isolate every other target profile."""
    profile = baseline_profile(context)
    if profile == "windows-x86_64":
        return BASELINE, BASELINE_META
    return PLATFORM_BASELINES / f"{profile}.json", PLATFORM_BASELINES / f"{profile}.meta.json"


def load_baseline(context=None):
    data_path, _ = active_baseline_paths(context)
    if data_path.exists():
        return json.loads(data_path.read_text(encoding="utf-8"))
    return {}


def load_baseline_metadata(context=None):
    _, metadata_path = active_baseline_paths(context)
    if metadata_path.exists():
        return json.loads(metadata_path.read_text(encoding="utf-8"))
    return {}


def index_display_environments(records):
    return {f"{record['group']}|{record['name']}": {
        "driver": record["driver"],
        "supersample": record["supersample"],
        "vsync": record["vsync"],
    } for record in records}


def baseline_verdict_mode(context):
    power_source = str(context.get("hostEnvironment", {}).get("powerSource", "unknown")).lower()
    return "gate" if power_source == "ac" else "observational"


def baseline_capture_digest(data, metadata):
    """Bind baseline values and provenance into one reviewable, tamper-evident capture."""
    captured_metadata = dict(metadata)
    captured_metadata.pop("captureDigest", None)
    captured_metadata.pop("promotion", None)
    document = {"baseline": data, "metadata": captured_metadata}
    encoded = json.dumps(
        document, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def baseline_documents(frame, display, display_environments, stability, context, sample_count):
    data = {f"{r['kind']}|{r['group']}|{r['name']}": r["ns"] for r in list(frame) + list(display)}
    metadata = {
        "schemaVersion": 1,
        "generatedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
        "samples": sample_count,
        "baselineProfile": baseline_profile(context),
        "verdictMode": baseline_verdict_mode(context),
        "source": context["source"],
        "hostEnvironment": context["hostEnvironment"],
        "displayEnvironments": index_display_environments(display_environments),
        "sampleStability": stability,
        "pairedComparisons": paired_comparison_stability(stability),
    }
    metadata["captureDigest"] = baseline_capture_digest(data, metadata)
    return data, metadata


def save_baseline(
        frame, display, display_environments, stability, context, sample_count,
        data_path=None, metadata_path=None, label="baseline"):
    data_path = data_path or BASELINE
    metadata_path = metadata_path or BASELINE_META
    data, metadata = baseline_documents(
        frame, display, display_environments, stability, context, sample_count)
    write_text_lf(data_path, json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    write_text_lf(metadata_path, json.dumps(metadata, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    mode = metadata["verdictMode"]
    print(f"{mode.capitalize()} {label} saved to {data_path} ({len(data)} cases).")
    print(f"{label.capitalize()} provenance saved to {metadata_path}.")
