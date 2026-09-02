"""benchmark regression verdict contracts"""

from bench.tests.runner_test_support import *

print("benchmark regression verdict contracts\n")

# A box reproducing the baseline: nothing moved, nothing to report.
code, out = check(frames(lambda i: 1.0))
expect("baseline reproduced -> pass", code == 0 and "No regressions" in out, out)

# A uniformly 3x slower box. The whole fleet moved together, so that is the machine, not the code —
# this is the case that made the old absolute check flag all 39 real cases at once.
code, out = check(frames(lambda i: 3.0))
expect("uniform 3x machine -> pass", code == 0 and "No regressions" in out, out)
expect("uniform 3x is reported as the machine factor", "3.00x" in out, out)

# One case twice as slow as its peers on an otherwise steady box: the gate must fail and name it.
code, out = check(frames(lambda i: 2.0 if i == 5 else 1.0))
expect("one real regression -> fail", code == 1, out)
expect("regression is named", "case5" in out, out)

# The same regression hiding underneath a 3x-slow machine: normalising must still surface it.
code, out = check(frames(lambda i: 6.0 if i == 5 else 3.0))
expect("regression under a slow machine -> fail", code == 1, out)
expect("regression is named despite the machine", "case5" in out, out)

# A case that got faster than its peers is an improvement, not a regression.
code, out = check(frames(lambda i: 0.4 if i == 7 else 1.0))
expect("an improvement -> pass", code == 0, out)

# A commit that speeds up MOST cases must not turn the untouched rest into "regressions vs peers":
# the fleet median drops below 1, and flagging normalises by max(median, 1) to absorb that.
code, out = check(frames(lambda i: 0.4 if i <= 7 else 1.0))
expect("majority improvement -> unchanged cases not flagged", code == 0 and "Regressions" not in out, out)

# Too few material cases and the median is meaningless (a lone regressed case can be its own median):
# the gate must decline to judge, not pass or fail.
small_base = {f"frame|g|case{i}": float(i * 1_000_000) for i in range(1, 4)}
small = [{"kind": "frame", "group": "g", "name": f"case{i}",
          "ns": small_base[f"frame|g|case{i}"] * (2.0 if i == 2 else 1.0)} for i in range(1, 4)]
code, out = check(small, small_base)
expect("tiny fleet -> inconclusive exit (3), not a pass", code == 3 and "INCONCLUSIVE" in out, out)

# When nothing material is comparable the gate has no coverage at all — it must say so instead of
# quietly gating the jitter-dominated sub-material cases (or printing a false 'No regressions').
micro_base = {f"frame|g|micro{i}": 100_000.0 for i in range(1, 6)}
micro = [{"kind": "frame", "group": "g", "name": f"micro{i}", "ns": 100_000.0} for i in range(1, 6)]
code, out = check(micro, micro_base)
expect("all sub-material -> inconclusive no-coverage",
       code == 3 and "INCONCLUSIVE" in out and "No regressions" not in out, out)

# A sub-material case that exploded is never a verdict, but it must be VISIBLE as an FYI line —
# a 20x jump on a 10us case can be an algorithmic slip that will scale with content.
tiny_burst_base = dict(BASE)
tiny_burst_base["frame|g|tinyburst"] = 10_000.0
tiny_burst = [{"kind": "frame", "group": "g", "name": "tinyburst", "ns": 200_000.0}]
code, out = check(frames(lambda i: 1.0) + tiny_burst, tiny_burst_base)
expect("cheap case exploding -> pass but listed as FYI",
       code == 0 and "FYI" in out and "tinyburst" in out, out)

# A genuinely noisy run (cases disagreeing wildly after normalising, as a P/E-core box does) cannot
# separate signal from scheduling noise. It must say so rather than fail on a coin flip.
random.seed(7)
code, out = check(frames(lambda i: random.uniform(0.6, 1.8)))
expect("noisy run -> inconclusive exit (3), not a false pass/fail",
       code == 3 and "INCONCLUSIVE" in out, out)

noisy_samples = [{
    "kind": "frame", "group": "g", "name": "case5", "samplesNs": [1_000_000, 2_000_000, 3_000_000],
    "medianNs": 2_000_000, "minNs": 1_000_000, "maxNs": 3_000_000,
    "relativeRange": 1.0, "relativeMad": 0.5,
}]
gate.load_baseline = lambda: dict(BASE)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 2.0 if i == 5 else 1.0), [], stability=noisy_samples)
expect("a dispersed suspect becomes inconclusive instead of a regression",
       code == 3 and "sample dispersion" in buf.getvalue(), buf.getvalue())

fast_domain_samples = [{
    "kind": "frame", "group": "g", "name": "case5",
    "samplesNs": [2_000_000, 2_000_000, 900_000, 2_000_000, 2_000_000],
    "medianNs": 2_000_000, "minNs": 900_000, "maxNs": 2_000_000,
    "relativeRange": 0.55, "relativeMad": 0.0,
}]
gate.load_baseline = lambda: dict(BASE)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 2.0 if i == 5 else 1.0), [], stability=fast_domain_samples)
expect("a faster-core outlier makes a slow cluster inconclusive instead of a false regression",
       code == 3 and "sample dispersion" in buf.getvalue(), buf.getvalue())

display_base = {f"display|dg|case{i}": float(i * 1_000_000) for i in range(1, 13)}
display_records = [
    {"kind": "display", "group": "dg", "name": f"case{i}",
     "ns": display_base[f"display|dg|case{i}"] * (2.0 if i == 5 else 1.0)}
    for i in range(1, 13)
]
display_environments = [
    {"group": "dg", "name": f"case{i}", "driver": "direct3d11", "supersample": 1, "vsync": 0}
    for i in range(1, 13)
]
gate.load_baseline = lambda: {**BASE, **display_base}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 3.0), display_records, display_environments)
expect("headless and display domains normalise independently",
       code == 1 and "display|dg|case5" in buf.getvalue(), buf.getvalue())

source = {
    "cangjieGui": {"sourceDigest": "gui"},
    "cangjieSdl": {"sourceDigest": "sdl"},
}
baseline_metadata = {
    "schemaVersion": 1,
    "samples": 3,
    "source": source,
    "hostEnvironment": {"platform": "Windows", "powerSource": "battery",
                        "effectivePowerOverlay": "best"},
    "displayEnvironments": {},
}
current_context = {
    "source": source,
    "hostEnvironment": {"platform": "Windows", "powerSource": "battery",
                        "effectivePowerOverlay": "balanced"},
}
gate.load_baseline = lambda: dict(BASE)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 1.0), [], baseline_metadata=baseline_metadata,
                                 current_context=current_context)
expect("incompatible power profile is a setup error, never a regression verdict",
       code == 2 and "not comparable" in buf.getvalue(), buf.getvalue())

# A laptop on battery can keep the selected Windows overlay while firmware silently changes clocks as
# charge and temperature move. Such a run is useful evidence, but it must never emit a hard pass/fail.
battery_baseline = {
    "schemaVersion": 1,
    "samples": 5,
    "source": {
        "cangjieGui": {"sourceDigest": "gui-before"},
        "cangjieSdl": {"sourceDigest": "sdl"},
    },
    "hostEnvironment": {"platform": "Windows", "powerSource": "battery",
                        "effectivePowerOverlay": "best"},
    "displayEnvironments": {},
}
battery_current = {
    "source": {
        "cangjieGui": {"sourceDigest": "gui-after"},
        "cangjieSdl": {"sourceDigest": "sdl"},
    },
    "hostEnvironment": {"platform": "Windows", "powerSource": "battery",
                        "effectivePowerOverlay": "best"},
}
gate.load_baseline = lambda: dict(BASE)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 2.0 if i == 5 else 1.0), [],
                                 baseline_metadata=battery_baseline, current_context=battery_current)
expect("battery capture is observational and cannot false-fail",
       code == 3 and "battery" in buf.getvalue().lower() and "case5" in buf.getvalue(), buf.getvalue())

# Replaying the exact same sources is a control experiment. A stable timing shift then proves an
# unmodelled environment/session effect, not a code regression, even on nominally controlled AC.
same_source = {
    "cangjieGui": {"sourceDigest": "gui-same"},
    "cangjieSdl": {"sourceDigest": "sdl-same"},
}
same_source_baseline = {
    "schemaVersion": 1,
    "samples": 5,
    "source": same_source,
    "hostEnvironment": {"platform": "Windows", "powerSource": "AC",
                        "effectivePowerOverlay": "best"},
    "displayEnvironments": {},
}
same_source_current = {
    "source": same_source,
    "hostEnvironment": {"platform": "Windows", "powerSource": "AC",
                        "effectivePowerOverlay": "best"},
}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 2.0 if i == 5 else 1.0), [],
                                 baseline_metadata=same_source_baseline,
                                 current_context=same_source_current)
expect("same-source replay drift is inconclusive instead of a false regression",
       code == 3 and "same source" in buf.getvalue().lower() and "case5" in buf.getvalue(),
       buf.getvalue())

observational_baseline = dict(same_source_baseline)
observational_baseline["verdictMode"] = "observational"
changed_source_current = {
    "source": {
        "cangjieGui": {"sourceDigest": "gui-new"},
        "cangjieSdl": {"sourceDigest": "sdl-same"},
    },
    "hostEnvironment": dict(same_source_current["hostEnvironment"]),
}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 1.0), [],
                                 baseline_metadata=observational_baseline,
                                 current_context=changed_source_current)
expect("observational baseline can never produce a hard pass",
       code == 3 and "baseline is observational" in buf.getvalue().lower(), buf.getvalue())

# Display domains intentionally isolate backend/supersample/vsync. Six independent material workloads
# are enough for a robust median and MAD; requiring the old global fleet of eight made the ss1 domain
# permanently inconclusive after sub-material timing cases were correctly excluded.
six_base = {f"display|six|case{i}": float(i * 1_000_000) for i in range(1, 7)}
six_display = [
    {"kind": "display", "group": "six", "name": f"case{i}",
     "ns": six_base[f"display|six|case{i}"] * (2.0 if i == 4 else 1.0)}
    for i in range(1, 7)
]
six_environment = [
    {"group": "six", "name": f"case{i}", "driver": "direct3d11", "supersample": 1, "vsync": 0}
    for i in range(1, 7)
]
gate.load_baseline = lambda: dict(six_base)
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions([], six_display, six_environment)
expect("six-case display domain can produce a regression verdict",
       code == 1 and "display|six|case4" in buf.getvalue(), buf.getvalue())

# A case too cheap to cost a frame doubling is not a regression: 10us -> 20us cannot hurt anything,
# and sub-millisecond cases are where nearly all the jitter lives.
tiny_base = dict(BASE)
tiny_base["frame|g|tiny"] = 10_000.0
tiny = [{"kind": "frame", "group": "g", "name": "tiny", "ns": 20_000.0}]
code, out = check(frames(lambda i: 1.0) + tiny, tiny_base)
expect("sub-material case is FYI only", code == 0 and "FYI" in out and "tiny" in out, out)

# With no baseline there is nothing to compare against, which is a setup error, not a pass.
gate.load_baseline = lambda: {}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 1.0), [])
expect("missing baseline -> setup error (2)", code == 2, buf.getvalue())

incomplete_base = dict(BASE)
incomplete_base.pop("frame|g|case12")
code, out = check(frames(lambda i: 1.0), incomplete_base)
expect("new benchmark without baseline -> coverage error (2)",
       code == 2 and "not gated" in out and "case12" in out, out)

finish()
