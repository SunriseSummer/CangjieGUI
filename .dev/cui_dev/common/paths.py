"""Canonical repository paths for all development tooling.

Keeping path discovery here prevents scripts from deriving the repository root
from their own nesting depth.  Generated files live under ``target``; source
directories under ``.dev`` remain reviewable and disposable.
"""

from pathlib import Path


DEV_ROOT = Path(__file__).resolve().parents[2]
REPOSITORY_ROOT = DEV_ROOT.parent
TARGET_ROOT = REPOSITORY_ROOT / "target"

CONFIG_ROOT = DEV_ROOT / "config"
FIXTURES_ROOT = DEV_ROOT / "fixtures"
BENCH_ROOT = DEV_ROOT / "bench"
BENCH_WORKLOADS_ROOT = BENCH_ROOT / "workloads"

DEV_TARGET_ROOT = TARGET_ROOT / "dev"
BENCH_TARGET_ROOT = TARGET_ROOT / "bench"
BENCH_RESULTS_ROOT = BENCH_TARGET_ROOT / "results"


def workload(*parts: str) -> Path:
    """Return a benchmark workload path without exposing layout arithmetic."""
    return BENCH_WORKLOADS_ROOT.joinpath(*parts)


def benchmark_build_root(package: Path) -> Path:
    """Return the centralized cjpm output root for a benchmark package."""
    relative = package.resolve().relative_to(BENCH_WORKLOADS_ROOT.resolve())
    return BENCH_TARGET_ROOT / "build" / relative
