#!/usr/bin/env python3
"""Build and run the real desktop fixture from a temporary, self-contained release directory.

The ordinary E2E runners execute through cjpm, which adds SDK/FFI search paths.  This gate instead
copies only the executable and its declared runtime dependencies into a fresh directory, launches
the executable directly, and verifies startup, text rendering, retained/full pixel equivalence,
background wake-up, shutdown, and cleanup.  It emits one platform-qualified JSON report suitable
for CI artifacts and release review.
"""

import argparse
import hashlib
import json
import os
import platform
import shutil
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

from cui_dev.common.paths import DEV_TARGET_ROOT, FIXTURES_ROOT, REPOSITORY_ROOT
from cui_dev.common.process import run_command
from cui_dev.e2e.desktop_lifecycle import PASS_MARKER, SCENARIOS
from cui_dev.snapshots.images import diff_images


ROOT = REPOSITORY_ROOT
SDL_ROOT = ROOT.parent / "CangjieSDL"
FIXTURE = FIXTURES_ROOT / "desktop_lifecycle"
RESULTS = DEV_TARGET_ROOT / "release"
EXPECTED_SDK_VERSION = "1.0.5"


class BundleError(RuntimeError):
    pass


def normalized_platform(system=None, machine=None):
    system = (system or platform.system()).strip().lower()
    machine = (machine or platform.machine()).strip().lower()
    systems = {"windows": "windows", "linux": "linux", "darwin": "macos", "macos": "macos"}
    architectures = {
        "amd64": "x86_64", "x86_64": "x86_64", "x64": "x86_64",
        "arm64": "arm64", "aarch64": "arm64",
    }
    if system not in systems:
        raise BundleError(f"unsupported release platform: {system or '<empty>'}")
    if machine not in architectures:
        raise BundleError(f"unsupported release architecture: {machine or '<empty>'}")
    return systems[system], architectures[machine]


def cangjie_home(environment=None, which=shutil.which):
    environment = os.environ if environment is None else environment
    configured = environment.get("CANGJIE_HOME")
    if configured:
        root = Path(configured).resolve()
    else:
        compiler = which("cjc")
        if not compiler:
            raise BundleError("CANGJIE_HOME is unset and cjc is not on PATH")
        root = Path(compiler).resolve().parent.parent
    if not (root / "runtime" / "lib").is_dir():
        raise BundleError(f"Cangjie runtime directory is missing under {root}")
    return root


def family_files(root, family, system):
    if not root.is_dir():
        return []
    names = {
        ("cangjie", "windows"): ("libcangjie-runtime.dll",),
        ("bounds", "windows"): ("libboundscheck.dll",),
        ("sdl", "windows"): ("SDL3.dll",),
        ("ttf", "windows"): ("SDL3_ttf.dll",),
        ("uia", "windows"): ("cui_uia.dll",),
    }
    exact = names.get((family, system))
    if exact is not None:
        return sorted(path for name in exact for path in root.rglob(name) if path.is_file())

    candidates = [path for path in root.rglob("*") if path.is_file()]
    if system == "linux":
        prefixes = {
            "cangjie": "libcangjie-runtime.so",
            "bounds": "libboundscheck.so",
            "sdl": "libSDL3.so",
            "ttf": "libSDL3_ttf.so",
        }
        prefix = prefixes.get(family)
        return sorted(path for path in candidates if prefix and path.name.startswith(prefix))
    if system == "macos":
        predicates = {
            "cangjie": lambda name: name.startswith("libcangjie-runtime") and name.endswith(".dylib"),
            "bounds": lambda name: name.startswith("libboundscheck") and name.endswith(".dylib"),
            "sdl": lambda name: name.startswith("libSDL3") and "_ttf" not in name and name.endswith(".dylib"),
            "ttf": lambda name: name.startswith("libSDL3_ttf") and name.endswith(".dylib"),
        }
        predicate = predicates.get(family)
        return sorted(path for path in candidates if predicate and predicate(path.name))
    return []


def required_runtime_families(system):
    families = ("cangjie", "bounds", "sdl", "ttf")
    return families + (("uia",) if system == "windows" else ())


def resolve_runtime_files(system, sdk_root, sdl_runtime, uia_root):
    locations = {
        "cangjie": sdk_root / "runtime" / "lib",
        "bounds": sdk_root / "runtime" / "lib",
        "sdl": sdl_runtime,
        "ttf": sdl_runtime,
        "uia": uia_root,
    }
    result = {}
    for family in required_runtime_families(system):
        files = family_files(locations[family], family, system)
        if not files:
            raise BundleError(f"missing {family} release runtime for {system} under {locations[family]}")
        result[family] = files
    return result


def copy_unique(source, destination, seen):
    target = destination / source.name
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    previous = seen.get(source.name)
    if previous is not None and previous != digest:
        raise BundleError(f"conflicting runtime files share the name {source.name}")
    if previous is None:
        shutil.copy2(source, target)
        seen[source.name] = digest
    return target, digest


def direct_environment(bundle, system):
    environment = os.environ.copy()
    variable = {"windows": "PATH", "linux": "LD_LIBRARY_PATH", "macos": "DYLD_LIBRARY_PATH"}[system]
    current = environment.get(variable, "")
    environment[variable] = str(bundle) + (os.pathsep + current if current else "")
    return environment


def executable_path():
    name = "main.exe" if platform.system() == "Windows" else "main"
    path = DEV_TARGET_ROOT / "build" / "fixtures" / "desktop_lifecycle" / \
        "release" / "bin" / name
    if not path.is_file():
        raise BundleError(f"built fixture executable is missing: {path}")
    return path


def run_stage(command, cwd, timeout, environment=None):
    started = time.perf_counter()
    code, stdout, stderr, timed_out = run_command(command, cwd, timeout, env=environment)
    log = stdout + stderr
    if timed_out:
        log += f"\nTimed out after {timeout}s; process tree terminated"
    return {
        "command": [str(item) for item in command],
        "returncode": code,
        "timedOut": timed_out,
        "seconds": round(time.perf_counter() - started, 3),
        "log": log,
        "ok": code == 0 and not timed_out,
    }


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-dir", type=Path,
                        help="directory containing target-platform SDL3 and SDL3_ttf runtime files")
    parser.add_argument("--timeout", type=int, default=120,
                        help="timeout for each direct executable scenario (default 120s)")
    parser.add_argument("--build-timeout", type=int, default=180,
                        help="timeout for native/UI fixture builds (default 180s)")
    parser.add_argument("--expected-sdk", default=EXPECTED_SDK_VERSION,
                        help=f"required cjc version substring (default {EXPECTED_SDK_VERSION})")
    parser.add_argument("--expected-profile",
                        help="required normalized platform profile, e.g. linux-x86_64")
    args = parser.parse_args(argv)
    if args.timeout < 1 or args.build_timeout < 1:
        parser.error("timeouts must be positive")
    return args


def write_report(profile, report):
    RESULTS.mkdir(parents=True, exist_ok=True)
    path = RESULTS / f"{profile}-delivery.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def main(argv=None):
    args = parse_args(argv)
    system, architecture = normalized_platform()
    profile = f"{system}-{architecture}"
    report = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "profile": profile,
        "host": {"system": platform.system(), "release": platform.release(),
                 "machine": platform.machine(), "python": platform.python_version()},
        "toolchain": None,
        "builds": [],
        "bundle": {"files": []},
        "scenarios": [],
        "pixelDiff": {"ok": False, "pixels": -1, "maxDelta": -1, "bbox": None},
        "capabilities": {
            "realWindow": False,
            "textRaster": False,
            "backgroundWake": False,
            "resourceCleanup": False,
            "retainedDamage": False,
            "nativeAccessibility": "windows-uia" if system == "windows" else "not-implemented",
        },
        "ok": False,
        "error": None,
    }
    try:
        if args.expected_profile and args.expected_profile != profile:
            raise BundleError(
                f"runner profile mismatch: expected {args.expected_profile}, observed {profile}")
        sdk_root = cangjie_home()
        compiler = run_stage(["cjc", "-v"], ROOT, 30)
        report["toolchain"] = compiler
        if not compiler["ok"] or args.expected_sdk not in compiler["log"]:
            raise BundleError(f"cjc does not report required SDK {args.expected_sdk}")

        if system == "windows":
            native = run_stage([
                "powershell", "-ExecutionPolicy", "Bypass", "-File",
                str(ROOT / ".dev" / "platform" / "windows" / "build_uia.ps1"),
            ], ROOT, args.build_timeout)
            report["builds"].append({"name": "windows-uia", **native})
            if not native["ok"]:
                raise BundleError("Windows UIA bridge build failed")

        fixture_build = run_stage(["cjpm", "build"], FIXTURE, args.build_timeout)
        report["builds"].append({"name": "desktop-fixture", **fixture_build})
        if not fixture_build["ok"]:
            raise BundleError("desktop fixture build failed")

        sdl_runtime = (args.runtime_dir or (SDL_ROOT / ".sdl3")).resolve()
        uia_runtime = ROOT / "target" / "native" / "windows" / architecture
        runtime = resolve_runtime_files(system, sdk_root, sdl_runtime, uia_runtime)
        RESULTS.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=f"{profile}-bundle-", dir=RESULTS) as temporary:
            bundle = Path(temporary)
            executable = executable_path()
            copied, digest = copy_unique(executable, bundle, {})
            copied.chmod(copied.stat().st_mode | 0o111)
            report["bundle"]["files"].append({
                "family": "executable", "name": copied.name, "sha256": digest,
                "bytes": copied.stat().st_size,
            })
            seen = {copied.name: digest}
            for family in required_runtime_families(system):
                for source in runtime[family]:
                    target, file_digest = copy_unique(source, bundle, seen)
                    if not any(item["name"] == target.name for item in report["bundle"]["files"]):
                        report["bundle"]["files"].append({
                            "family": family, "name": target.name, "sha256": file_digest,
                            "bytes": target.stat().st_size,
                        })

            environment = direct_environment(bundle, system)
            for scenario in SCENARIOS:
                result = run_stage([str(copied), scenario], bundle, args.timeout, environment)
                result["scenario"] = scenario
                result["ok"] = result["ok"] and PASS_MARKER in result["log"]
                report["scenarios"].append(result)
                if not result["ok"]:
                    raise BundleError(f"direct clean-bundle scenario failed: {scenario}")

            incremental = bundle / "retained-damage.bmp"
            full = bundle / "retained-full.bmp"
            if not incremental.is_file() or not full.is_file():
                raise BundleError("clean bundle did not produce retained incremental/full screenshots")
            pixels, max_delta, bbox = diff_images(incremental, full, tolerance=0)
            report["pixelDiff"] = {
                "ok": pixels == 0, "pixels": pixels, "maxDelta": max_delta, "bbox": bbox,
            }
            for source, suffix in ((incremental, "incremental"), (full, "full")):
                shutil.copy2(source, RESULTS / f"{profile}-retained-{suffix}.bmp")
            if pixels != 0:
                raise BundleError(f"clean-bundle retained/full screenshots differ at {pixels} pixels")

        report["capabilities"].update({
            "realWindow": True,
            "textRaster": True,
            "backgroundWake": True,
            "resourceCleanup": True,
            "retainedDamage": True,
        })
        report["ok"] = True
    except (BundleError, OSError, ValueError) as error:
        report["error"] = str(error)

    path = write_report(profile, report)
    print(f"[{'OK' if report['ok'] else 'FAIL'}] clean release bundle {profile}; report: {path.relative_to(ROOT)}")
    if not report["ok"]:
        print(report["error"], file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
