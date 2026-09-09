import tempfile
import unittest
from pathlib import Path

from cui_dev.release.provenance import fingerprint_files, validate_source_pair


class ReleaseProvenanceTests(unittest.TestCase):
    def test_source_pair_rejects_git_or_different_local_dependency(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            root, fixture, sdl = (parent / name for name in ("gui", "fixture", "sdl"))
            for directory in (root, fixture, sdl):
                directory.mkdir()
            (root / "cjpm.toml").write_text('[dependencies]\nsdl = {path = "../sdl"}\n')
            (fixture / "cjpm.toml").write_text('[dependencies]\ncui = {path = "../gui"}\n')
            validate_source_pair(root, fixture, sdl)
            for declaration in ('sdl = {git = "https://example.invalid/sdl"}', 'sdl = {path = "../other"}'):
                (root / "cjpm.toml").write_text('[dependencies]\n' + declaration)
                with self.assertRaises(ValueError):
                    validate_source_pair(root, fixture, sdl)

    def test_order_is_stable_and_content_rename_deletion_change_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "a.cj").write_bytes(b"one")
            (root / "b.cj").write_bytes(b"two")
            before = fingerprint_files(root, ["a.cj", "b.cj"])
            self.assertEqual(before, fingerprint_files(root, ["b.cj", "a.cj", "a.cj"]))
            (root / "b.cj").write_bytes(b"modified")
            changed = fingerprint_files(root, ["a.cj", "b.cj"])
            self.assertNotEqual(before["sha256"], changed["sha256"])
            (root / "b.cj").rename(root / "c.cj")
            renamed = fingerprint_files(root, ["a.cj", "c.cj"])
            self.assertNotEqual(changed["sha256"], renamed["sha256"])
            deleted = fingerprint_files(root, ["a.cj", "b.cj"])
            self.assertEqual(len(deleted["files"]), 1)
            self.assertNotEqual(deleted["sha256"], renamed["sha256"])
