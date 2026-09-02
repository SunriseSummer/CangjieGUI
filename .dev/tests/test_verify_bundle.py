#!/usr/bin/env python3
"""Standard-library tests for the cross-platform clean release bundle gate."""

import tempfile
import unittest
from pathlib import Path

from cui_dev.release import verify_bundle as bundle


class ReleaseBundleTests(unittest.TestCase):
    def test_platform_profiles_normalize_supported_spellings(self):
        self.assertEqual(bundle.normalized_platform("Windows", "AMD64"), ("windows", "x86_64"))
        self.assertEqual(bundle.normalized_platform("Linux", "aarch64"), ("linux", "arm64"))
        self.assertEqual(bundle.normalized_platform("Darwin", "arm64"), ("macos", "arm64"))

    def test_unsupported_platform_or_architecture_is_rejected(self):
        with self.assertRaises(bundle.BundleError):
            bundle.normalized_platform("FreeBSD", "x86_64")
        with self.assertRaises(bundle.BundleError):
            bundle.normalized_platform("Linux", "riscv64")

    def test_windows_runtime_selection_does_not_accept_prefixed_ffi_aliases(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "libSDL3.dll").write_bytes(b"wrong alias")
            self.assertEqual(bundle.family_files(root, "sdl", "windows"), [])
            (root / "SDL3.dll").write_bytes(b"runtime")
            self.assertEqual([path.name for path in bundle.family_files(root, "sdl", "windows")],
                             ["SDL3.dll"])

    def test_macos_sdl_family_excludes_ttf(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "libSDL3.0.dylib").write_bytes(b"sdl")
            (root / "libSDL3_ttf.0.dylib").write_bytes(b"ttf")
            self.assertEqual([path.name for path in bundle.family_files(root, "sdl", "macos")],
                             ["libSDL3.0.dylib"])
            self.assertEqual([path.name for path in bundle.family_files(root, "ttf", "macos")],
                             ["libSDL3_ttf.0.dylib"])

    def test_missing_runtime_family_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sdk = root / "sdk"
            sdl = root / "sdl"
            native = root / "native"
            (sdk / "runtime" / "lib").mkdir(parents=True)
            sdl.mkdir()
            native.mkdir()
            with self.assertRaisesRegex(bundle.BundleError, "missing cangjie"):
                bundle.resolve_runtime_files("windows", sdk, sdl, native)

    def test_same_name_different_runtime_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = root / "first"
            second = root / "second"
            output = root / "output"
            first.mkdir()
            second.mkdir()
            output.mkdir()
            a = first / "runtime.dll"
            b = second / "runtime.dll"
            a.write_bytes(b"one")
            b.write_bytes(b"two")
            seen = {}
            bundle.copy_unique(a, output, seen)
            with self.assertRaisesRegex(bundle.BundleError, "conflicting"):
                bundle.copy_unique(b, output, seen)

    def test_direct_environment_prepends_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            environment = bundle.direct_environment(root, "linux")
            self.assertEqual(environment["LD_LIBRARY_PATH"].split(bundle.os.pathsep)[0], str(root))

    def test_expected_profile_argument_is_preserved(self):
        args = bundle.parse_args(["--expected-profile", "macos-arm64"])
        self.assertEqual(args.expected_profile, "macos-arm64")


if __name__ == "__main__":
    unittest.main()
