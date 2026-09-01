#!/usr/bin/env python3
"""Tests for the deterministic SDL3/SDL3_ttf source build driver."""

import tempfile
import unittest
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_sdl_runtime as build_sdl


def source_tree(root, family):
    root.mkdir(parents=True)
    (root / "CMakeLists.txt").write_text("", encoding="utf-8")
    namespace, header = ("SDL3", "SDL.h") if family == "sdl" else ("SDL3_ttf", "SDL_ttf.h")
    include = root / "include" / namespace
    include.mkdir(parents=True)
    (include / header).write_text("", encoding="utf-8")
    return root


class BuildSdlRuntimeTests(unittest.TestCase):
    def test_build_plan_is_shared_only_strict_and_installable(self):
        commands = build_sdl.configure_commands(
            "cmake", Path("sdl"), Path("ttf"), Path("build"), Path("prefix"), 3)
        self.assertEqual(len(commands), 6)
        self.assertIn("-DSDL_SHARED=ON", commands[0])
        self.assertIn("-DSDL_STATIC=OFF", commands[0])
        self.assertIn("-DSDLTTF_STRICT=ON", commands[3])
        self.assertIn("-DSDLTTF_VENDORED=OFF", commands[3])
        self.assertIn("-DSDLTTF_PLUTOSVG=OFF", commands[3])
        self.assertIn("-DCMAKE_PREFIX_PATH=prefix", commands[3])
        self.assertEqual(commands[0][1:3], ["-S", "sdl"])
        self.assertIn("Ninja", commands[0])
        self.assertEqual(commands[1][-2:], ["--parallel", "3"])

    def test_dependency_prefixes_are_explicit_cmake_inputs(self):
        commands = build_sdl.configure_commands(
            "cmake", Path("sdl"), Path("ttf"), Path("build"), Path("prefix"), 2,
            dependency_prefixes=(Path("freetype"), Path("harfbuzz")))
        self.assertIn("-DCMAKE_PREFIX_PATH=prefix;freetype;harfbuzz", commands[3])

    def test_invalid_source_root_and_cross_compile_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(build_sdl.BootstrapError, "invalid sdl source"):
                build_sdl.validate_source(root, "sdl")
            with self.assertRaisesRegex(build_sdl.BootstrapError, "implicit cross compilation"):
                build_sdl.build(
                    "linux-x86_64", root, root, root / "build", root / "prefix",
                    runner=lambda *_args: (0, "", "", False), host_profile="macos-arm64")

    def test_command_failure_stops_the_plan(self):
        calls = []

        def runner(command, _cwd, _timeout):
            calls.append(command)
            return 2, "configure output", "configuration failed", False

        with self.assertRaisesRegex(build_sdl.BootstrapError, "configuration failed"):
            build_sdl.run_plan([["cmake", "-S", "source"], ["never"]], Path.cwd(), 10, runner)
        self.assertEqual(len(calls), 1)

    def test_runtime_inventory_requires_both_families(self):
        with tempfile.TemporaryDirectory() as temporary:
            prefix = Path(temporary)
            (prefix / "libSDL3.so.0").write_bytes(b"sdl")
            with self.assertRaisesRegex(build_sdl.BootstrapError, "no ttf"):
                build_sdl.runtime_inventory(prefix, "linux")
            (prefix / "libSDL3_ttf.so.0").write_bytes(b"ttf")
            inventory = build_sdl.runtime_inventory(prefix, "linux")
            self.assertEqual(inventory["sdl"][0]["sha256"],
                             "8fd2cf493428683399f6d3cf8c7df3dd80e46d106d003e9dc4d77306d7c19fee")
            self.assertEqual(inventory["ttf"][0]["name"], "libSDL3_ttf.so.0")

    def test_full_build_orchestration_records_six_successful_commands(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sdl = source_tree(root / "sdl", "sdl")
            ttf = source_tree(root / "ttf", "sdl_ttf")
            prefix = root / "prefix"
            calls = []

            def runner(command, _cwd, _timeout):
                calls.append(command)
                if command[1:2] == ["--install"] and "sdl_ttf" in command[2]:
                    (prefix / "libSDL3.so").write_bytes(b"sdl")
                    (prefix / "libSDL3_ttf.so").write_bytes(b"ttf")
                return 0, "ok", "", False

            result = build_sdl.build(
                "linux-x86_64", sdl, ttf, root / "build", prefix,
                runner=runner, host_profile="linux-x86_64")
            self.assertEqual(len(calls), 6)
            self.assertEqual(len(result["commands"]), 6)
            self.assertEqual(result["hostProfile"], "linux-x86_64")


if __name__ == "__main__":
    unittest.main()
