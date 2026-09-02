#!/usr/bin/env python3
"""Stage an explicit target-platform SDL3/SDL3_ttf runtime into the sibling SDL checkout."""

import argparse
import os
import shutil
import sys
from pathlib import Path

from cui_dev.common.paths import REPOSITORY_ROOT
from cui_dev.release.verify_bundle import BundleError, family_files, normalized_platform

ROOT = REPOSITORY_ROOT
DEFAULT_DESTINATION = ROOT.parent / "CangjieSDL" / ".sdl3"


def resolve_source(argument=None, environment=None):
    environment = os.environ if environment is None else environment
    value = argument or environment.get("CUI_SDL_RUNTIME_DIR")
    if not value:
        raise BundleError("set CUI_SDL_RUNTIME_DIR or pass --source with target-platform SDL runtimes")
    source = Path(value).resolve()
    if not source.is_dir():
        raise BundleError(f"SDL runtime source is not a directory: {source}")
    return source


def selected_runtime_files(source, system):
    result = {}
    for family in ("sdl", "ttf"):
        files = family_files(source, family, system)
        if not files:
            raise BundleError(f"missing {family} runtime for {system} under {source}")
        result[family] = files
    return result


def stage(source, destination, system):
    selected = selected_runtime_files(source, system)
    destination.mkdir(parents=True, exist_ok=True)
    staged = []
    for family in ("sdl", "ttf"):
        for runtime in selected[family]:
            target = destination / runtime.name
            if runtime.resolve() != target.resolve():
                shutil.copy2(runtime, target)
            staged.append((family, target))
    return staged


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path,
                        help="runtime source; defaults to CUI_SDL_RUNTIME_DIR")
    parser.add_argument("--destination", type=Path, default=DEFAULT_DESTINATION,
                        help="target CangjieSDL .sdl3 directory")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        system, architecture = normalized_platform()
        source = resolve_source(args.source)
        staged = stage(source, args.destination.resolve(), system)
    except (BundleError, OSError) as error:
        print(f"SDL runtime staging failed: {error}", file=sys.stderr)
        return 1
    print(f"Staged {len(staged)} SDL runtime file(s) for {system}-{architecture}:")
    for family, path in staged:
        print(f"  {family}: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
