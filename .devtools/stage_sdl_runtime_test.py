#!/usr/bin/env python3
"""Tests for explicit SDL runtime staging used by cross-platform runners."""

import tempfile
import unittest
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import stage_sdl_runtime as staging


class StageSdlRuntimeTests(unittest.TestCase):
    def test_source_must_be_explicit(self):
        with self.assertRaisesRegex(staging.BundleError, "CUI_SDL_RUNTIME_DIR"):
            staging.resolve_source(environment={})

    def test_missing_ttf_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            (source / "SDL3.dll").write_bytes(b"sdl")
            with self.assertRaisesRegex(staging.BundleError, "missing ttf"):
                staging.selected_runtime_files(source, "windows")

    def test_windows_runtime_pair_is_staged(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            destination = root / "destination"
            source.mkdir()
            (source / "SDL3.dll").write_bytes(b"sdl")
            (source / "SDL3_ttf.dll").write_bytes(b"ttf")
            staged = staging.stage(source, destination, "windows")
            self.assertEqual([(family, path.name) for family, path in staged], [
                ("sdl", "SDL3.dll"), ("ttf", "SDL3_ttf.dll"),
            ])
            self.assertEqual((destination / "SDL3.dll").read_bytes(), b"sdl")
            self.assertEqual((destination / "SDL3_ttf.dll").read_bytes(), b"ttf")

    def test_same_source_and_destination_is_safe(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "SDL3.dll").write_bytes(b"sdl")
            (root / "SDL3_ttf.dll").write_bytes(b"ttf")
            staged = staging.stage(root, root, "windows")
            self.assertEqual(len(staged), 2)


if __name__ == "__main__":
    unittest.main()
