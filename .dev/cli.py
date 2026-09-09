#!/usr/bin/env python3
"""Stable command-line interface for CUI development and performance tools."""

import argparse
import os
import sys
import unittest
from collections.abc import Callable, Sequence
from pathlib import Path

# The bundled Windows Python runs in isolated mode and does not add the script
# directory to sys.path.  Bootstrap it once at the public entry point; internal
# modules remain ordinary package imports with no path manipulation.
DEV_ROOT = Path(__file__).resolve().parent
REPOSITORY_ROOT = DEV_ROOT.parent
if str(DEV_ROOT) not in sys.path:
    sys.path.insert(0, str(DEV_ROOT))

# Keep bytecode out of the source tree, including Python children that run with
# a fixture as their working directory.  Relative user values are normalized
# against the repository rather than each child's cwd.
configured_cache = os.environ.get("PYTHONPYCACHEPREFIX")
cache_root = Path(configured_cache) if configured_cache else \
    REPOSITORY_ROOT / "target" / "dev" / "pycache"
if not cache_root.is_absolute():
    cache_root = REPOSITORY_ROOT / cache_root
cache_root = cache_root.resolve()
os.environ["PYTHONPYCACHEPREFIX"] = str(cache_root)
sys.pycache_prefix = str(cache_root)

from cui_dev.checks import doc_snippets, docs, packages, symbol_linking
from cui_dev.e2e import desktop_lifecycle, examples
from cui_dev.release import bootstrap, build_sdl, stage_runtime, verify_bundle
from cui_dev.snapshots import gallery, images
from bench.tooling import compare, phase3_probe, runner, suite


Command = Callable[[Sequence[str] | None], int | None]


def _without_arguments(command: Callable[[], int | None]) -> Command:
    def invoke(arguments: Sequence[str] | None = None) -> int | None:
        if arguments:
            raise SystemExit(f"this command accepts no arguments: {' '.join(arguments)}")
        return command()
    return invoke


def _tool_tests(_arguments: Sequence[str] | None = None) -> int:
    if _arguments:
        raise SystemExit("test tools accepts no additional arguments")
    loader = unittest.TestLoader()
    suite_root = loader.discover(str(DEV_ROOT / "tests"), top_level_dir=str(DEV_ROOT))
    suite_bench = loader.discover(
        str(DEV_ROOT / "bench" / "tests"), top_level_dir=str(DEV_ROOT),
    )
    combined = unittest.TestSuite((suite_root, suite_bench))
    result = unittest.TextTestRunner(verbosity=2).run(combined)
    return 0 if result.wasSuccessful() else 1


COMMANDS: dict[tuple[str, ...], Command] = {
    ("check", "docs"): _without_arguments(docs.main),
    ("check", "snippets"): doc_snippets.main,
    ("check", "symbol-linking"): symbol_linking.main,
    ("test", "tools"): _tool_tests,
    ("test", "packages"): packages.main,
    ("test", "examples"): examples.main,
    ("test", "desktop"): desktop_lifecycle.main,
    ("snapshot",): images.main,
    ("gallery",): gallery.main,
    ("release", "bootstrap"): bootstrap.main,
    ("release", "build-sdl"): build_sdl.main,
    ("release", "stage-runtime"): stage_runtime.main,
    ("release", "verify"): verify_bundle.main,
    ("bench", "run"): runner.main,
    ("bench", "suite"): suite.main,
    ("bench", "probe"): phase3_probe.main,
    ("bench", "compare"): compare.main,
}


def _usage() -> str:
    commands = "\n".join(f"  {' '.join(parts)}" for parts in sorted(COMMANDS))
    return f"usage: python .dev/cli.py <command> [arguments]\n\ncommands:\n{commands}"


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if not arguments or arguments[0] in {"-h", "--help"}:
        print(_usage())
        return 0

    for parts, command in sorted(COMMANDS.items(), key=lambda item: -len(item[0])):
        if tuple(arguments[:len(parts)]) == parts:
            try:
                result = command(arguments[len(parts):])
                return 0 if result is None else int(result)
            except (OSError, RuntimeError, ValueError) as error:
                print(f"{' '.join(parts)} failed: {error}", file=sys.stderr)
                return 2

    parser = argparse.ArgumentParser(usage=_usage(), add_help=False)
    parser.error(f"unknown command: {' '.join(arguments[:2])}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
