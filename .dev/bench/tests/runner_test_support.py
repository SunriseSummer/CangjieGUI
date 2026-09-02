"""Shared fixtures for benchmark-tool contract tests."""

import io
import json
import random
import sys
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from bench.tooling import execution, gate, promotion, runner as run, sampling

# A synthetic fleet: 12 frame cases from 1ms to 12ms, all well past the material floor.
BASE = {f"frame|g|case{i}": float(i * 1_000_000) for i in range(1, 13)}


def frames(scale):
    """Build a result set where each case i is scale(i) times its baseline."""
    return [
        {"kind": "frame", "group": "g", "name": f"case{i}", "ns": BASE[f"frame|g|case{i}"] * scale(i)}
        for i in range(1, 13)
    ]


def check(recs, base=None):
    gate.load_baseline = lambda: dict(base or BASE)
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


def finish():
    """Fail one imported contract module after printing every named assertion."""
    print()
    if failures:
        raise AssertionError("\\n".join(failures))
    failures.clear()
