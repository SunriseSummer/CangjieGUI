#!/usr/bin/env python3
"""Build pinned SDL3/SDL3_ttf sources into a target-platform shared runtime prefix."""

import argparse
import hashlib
import json
import os
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bootstrap_cross_platform import BootstrapError, current_profile, write_json
from process_runner import run_command
from verify_release_bundle import family_files

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TOOLCHAINS = ROOT / "target" / "toolchains"
DEFAULT_REPORTS = ROOT / "target" / "cross-platform"
SUPPORTED_BUILD_PROFILES = {"linux-x86_64", "linux-arm64", "macos-arm64"}


def utc_timestamp():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def profile_system(profile):
    if profile.startswith("linux-"):
        return "linux"
    if profile.startswith("macos-"):
        return "macos"
    raise BootstrapError(f"SDL source build is unsupported for profile: {profile}")


def validate_source(root, family):
    root = root.resolve()
    expected_header = {
        "sdl": root / "include" / "SDL3" / "SDL.h",
        "sdl_ttf": root / "include" / "SDL3_ttf" / "SDL_ttf.h",
    }[family]
    if not (root / "CMakeLists.txt").is_file() or not expected_header.is_file():
        raise BootstrapError(f"invalid {family} source root: {root}")
    return root


def configure_commands(cmake, sdl_source, sdl_ttf_source, build_root, prefix, jobs,
                       generator="Ninja", dependency_prefixes=()):
    sdl_build = build_root / "sdl"
    ttf_build = build_root / "sdl_ttf"
    common = [
        "-G", generator,
        "-DCMAKE_BUILD_TYPE=Release",
        f"-DCMAKE_INSTALL_PREFIX={prefix}",
        "-DCMAKE_INSTALL_LIBDIR=lib",
    ]
    cmake_prefix_path = ";".join(str(path) for path in (prefix, *dependency_prefixes))
    return [
        [cmake, "-S", str(sdl_source), "-B", str(sdl_build), *common,
         "-DSDL_SHARED=ON", "-DSDL_STATIC=OFF", "-DSDL_TEST_LIBRARY=OFF",
         "-DSDL_TESTS=OFF", "-DSDL_EXAMPLES=OFF"],
        [cmake, "--build", str(sdl_build), "--config", "Release", "--parallel", str(jobs)],
        [cmake, "--install", str(sdl_build), "--config", "Release"],
        [cmake, "-S", str(sdl_ttf_source), "-B", str(ttf_build), *common,
         f"-DCMAKE_PREFIX_PATH={cmake_prefix_path}", "-DBUILD_SHARED_LIBS=ON",
         "-DSDLTTF_INSTALL=ON", "-DSDLTTF_VENDORED=OFF", "-DSDLTTF_STRICT=ON",
         "-DSDLTTF_SAMPLES=OFF", "-DSDLTTF_HARFBUZZ=ON", "-DSDLTTF_PLUTOSVG=OFF"],
        [cmake, "--build", str(ttf_build), "--config", "Release", "--parallel", str(jobs)],
        [cmake, "--install", str(ttf_build), "--config", "Release"],
    ]


def run_plan(commands, cwd, timeout, runner=run_command):
    results = []
    for command in commands:
        started = time.monotonic()
        code, stdout, stderr, timed_out = runner(command, cwd, timeout)
        result = {
            "command": command,
            "exitCode": code,
            "timedOut": timed_out,
            "durationSeconds": round(time.monotonic() - started, 3),
            "stdout": stdout,
            "stderr": stderr,
        }
        results.append(result)
        if code != 0 or timed_out:
            rendered = " ".join(command)
            detail = stderr.strip() or stdout.strip() or "no process output"
            raise BootstrapError(f"SDL build command failed ({code}): {rendered}\n{detail}")
    return results


def file_record(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return {
        "path": str(path.resolve()),
        "name": path.name,
        "size": path.stat().st_size,
        "sha256": digest.hexdigest(),
    }


def runtime_inventory(prefix, system):
    result = {}
    for family in ("sdl", "ttf"):
        files = family_files(prefix, family, system)
        if not files:
            raise BootstrapError(f"built prefix has no {family} shared runtime for {system}: {prefix}")
        result[family] = [file_record(path) for path in files]
    return result


def build(profile, sdl_source, sdl_ttf_source, build_root, prefix, cmake="cmake",
          jobs=2, timeout=900, generator="Ninja", dependency_prefixes=(),
          runner=run_command, host_profile=None):
    if profile not in SUPPORTED_BUILD_PROFILES:
        raise BootstrapError(f"SDL source build is unsupported for profile: {profile}")
    actual_profile = host_profile or current_profile()
    if actual_profile != profile:
        raise BootstrapError(
            f"refusing implicit cross compilation: requested {profile}, current host is {actual_profile}")
    if not shutil.which(cmake) and runner is run_command:
        raise BootstrapError(f"CMake executable is unavailable: {cmake}")
    if generator == "Ninja" and not shutil.which("ninja") and runner is run_command:
        raise BootstrapError("Ninja executable is unavailable")
    sdl_source = validate_source(sdl_source, "sdl")
    sdl_ttf_source = validate_source(sdl_ttf_source, "sdl_ttf")
    dependency_prefixes = tuple(Path(path).resolve() for path in dependency_prefixes)
    missing_prefixes = [path for path in dependency_prefixes if not path.is_dir()]
    if missing_prefixes:
        raise BootstrapError(
            "SDL dependency prefix does not exist: " + ", ".join(str(path) for path in missing_prefixes))
    build_root.mkdir(parents=True, exist_ok=True)
    prefix.mkdir(parents=True, exist_ok=True)
    commands = configure_commands(
        cmake, sdl_source, sdl_ttf_source, build_root, prefix, jobs,
        generator=generator, dependency_prefixes=dependency_prefixes)
    results = run_plan(commands, ROOT, timeout, runner=runner)
    return {
        "schemaVersion": 1,
        "generatedAt": utc_timestamp(),
        "profile": profile,
        "hostProfile": actual_profile,
        "sources": {"sdl": str(sdl_source), "sdlTtf": str(sdl_ttf_source)},
        "buildRoot": str(build_root.resolve()),
        "prefix": str(prefix.resolve()),
        "generator": generator,
        "dependencyPrefixes": [str(path) for path in dependency_prefixes],
        "commands": results,
        "runtime": runtime_inventory(prefix, profile_system(profile)),
    }


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=sorted(SUPPORTED_BUILD_PROFILES), required=True)
    parser.add_argument("--sdl-source", type=Path, required=True)
    parser.add_argument("--sdl-ttf-source", type=Path, required=True)
    parser.add_argument("--build-root", type=Path)
    parser.add_argument("--prefix", type=Path)
    parser.add_argument("--cmake", default="cmake")
    parser.add_argument("--generator", default="Ninja")
    parser.add_argument("--dependency-prefix", action="append", type=Path,
                        dest="dependency_prefixes",
                        help="additional FreeType/HarfBuzz CMake prefix; repeatable")
    parser.add_argument("--jobs", type=int, default=max(1, min(4, os.cpu_count() or 1)))
    parser.add_argument("--timeout", type=int, default=900,
                        help="timeout in seconds for each configure/build/install command")
    parser.add_argument("--report", type=Path)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    toolchain_root = DEFAULT_TOOLCHAINS / args.profile
    build_root = (args.build_root or toolchain_root / "sdl-build").resolve()
    prefix = (args.prefix or toolchain_root / "sdl-prefix").resolve()
    report = (args.report or DEFAULT_REPORTS / f"sdl-build-{args.profile}.json").resolve()
    try:
        result = build(
            args.profile, args.sdl_source, args.sdl_ttf_source, build_root, prefix,
            cmake=args.cmake, jobs=args.jobs, timeout=args.timeout,
            generator=args.generator, dependency_prefixes=args.dependency_prefixes or ())
        write_json(report, result)
    except (BootstrapError, OSError) as error:
        print(f"SDL runtime build failed: {error}", file=sys.stderr)
        return 1
    print(f"Built SDL runtime for {args.profile}: {prefix}")
    print(f"Evidence: {report}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
