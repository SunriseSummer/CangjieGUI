#!/usr/bin/env python3
"""Tests for the pinned, fail-closed cross-platform artifact bootstrap."""

import hashlib
import io
import json
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

from cui_dev.release import bootstrap


class FakeResponse(io.BytesIO):
    def __init__(self, payload, url="https://downloads.example/artifact"):
        super().__init__(payload)
        self.url = url

    def geturl(self):
        return self.url

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        self.close()


def artifact(payload, filename="artifact.zip"):
    return {
        "filename": filename,
        "url": f"https://downloads.example/{filename}",
        "sha256": hashlib.sha256(payload).hexdigest(),
        "size": len(payload),
    }


class BootstrapCrossPlatformTests(unittest.TestCase):
    def test_current_profile_normalizes_supported_hosts(self):
        self.assertEqual(bootstrap.current_profile("Windows", "AMD64"), "windows-x86_64")
        self.assertEqual(bootstrap.current_profile("Linux", "aarch64"), "linux-arm64")
        self.assertEqual(bootstrap.current_profile("Darwin", "arm64"), "macos-arm64")
        with self.assertRaisesRegex(bootstrap.BootstrapError, "unsupported toolchain profile"):
            bootstrap.current_profile("Darwin", "x86_64")

    def test_checked_in_manifest_is_complete(self):
        manifest = bootstrap.load_manifest()
        self.assertEqual(manifest["cangjie"]["version"], "1.0.5")
        self.assertEqual(set(manifest["cangjie"]["artifacts"]), bootstrap.SUPPORTED_PROFILES)
        self.assertEqual(manifest["sdl"]["version"], "3.4.12")
        self.assertEqual(manifest["sdlTtf"]["version"], "3.2.2")

    def test_download_is_atomic_and_cache_is_reverified(self):
        payload = b"verified payload"
        expected = artifact(payload)
        calls = []

        def opener(_request, timeout):
            calls.append(timeout)
            return FakeResponse(payload)

        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            path, hit = bootstrap.fetch_artifact(expected, cache, opener=opener)
            self.assertFalse(hit)
            self.assertEqual(path.read_bytes(), payload)
            cached, hit = bootstrap.fetch_artifact(expected, cache, opener=lambda *_a, **_k: None)
            self.assertTrue(hit)
            self.assertEqual(cached, path)
            self.assertEqual(calls, [120])

    def test_bad_download_and_bad_cache_fail_closed(self):
        payload = b"expected"
        expected = artifact(payload)
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            with self.assertRaisesRegex(bootstrap.BootstrapError, "size mismatch"):
                bootstrap.fetch_artifact(
                    expected, cache, opener=lambda *_a, **_k: FakeResponse(b"bad"))
            destination = cache / expected["filename"]
            destination.write_bytes(b"corrupt!")
            with self.assertRaisesRegex(bootstrap.BootstrapError, "SHA-256 mismatch"):
                bootstrap.fetch_artifact(expected, cache, opener=lambda *_a, **_k: None)

    def test_non_https_redirect_is_rejected(self):
        payload = b"expected"
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(bootstrap.BootstrapError, "non-HTTPS"):
                bootstrap.fetch_artifact(
                    artifact(payload), Path(temporary),
                    opener=lambda *_a, **_k: FakeResponse(payload, "http://unsafe.example/file"))

    def test_zip_traversal_and_symbolic_link_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            traversal = root / "traversal.zip"
            with zipfile.ZipFile(traversal, "w") as bundle:
                bundle.writestr("../escape", b"bad")
            with self.assertRaisesRegex(bootstrap.BootstrapError, "escapes extraction root"):
                bootstrap.extract_zip(traversal, root / "out")

            symbolic = root / "symbolic.zip"
            link = zipfile.ZipInfo("link")
            link.create_system = 3
            link.external_attr = (0o120777 << 16)
            with zipfile.ZipFile(symbolic, "w") as bundle:
                bundle.writestr(link, "target")
            with self.assertRaisesRegex(bootstrap.BootstrapError, "symbolic link"):
                bootstrap.extract_zip(symbolic, root / "out")

    def test_tar_traversal_and_escaping_links_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            traversal = root / "traversal.tar.gz"
            with tarfile.open(traversal, "w:gz") as bundle:
                member = tarfile.TarInfo("../escape")
                member.size = 3
                bundle.addfile(member, io.BytesIO(b"bad"))
            with self.assertRaisesRegex(bootstrap.BootstrapError, "escapes extraction root"):
                bootstrap.extract_tar(traversal, root / "out")

            symbolic = root / "symbolic.tar.gz"
            with tarfile.open(symbolic, "w:gz") as bundle:
                member = tarfile.TarInfo("link")
                member.type = tarfile.SYMTYPE
                member.linkname = "../target"
                bundle.addfile(member)
            with self.assertRaisesRegex(bootstrap.BootstrapError, "escapes extraction root"):
                bootstrap.extract_tar(symbolic, root / "out")

    def test_safe_tar_symbolic_link_is_supported(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / "safe-link.tar.gz"
            with tarfile.open(archive, "w:gz") as bundle:
                target = tarfile.TarInfo("framework/Versions/A/library")
                target.size = 2
                bundle.addfile(target, io.BytesIO(b"ok"))
                link = tarfile.TarInfo("framework/Versions/Current")
                link.type = tarfile.SYMTYPE
                link.linkname = "A"
                bundle.addfile(link)
            destination = root / "out"
            bootstrap.extract_tar(archive, destination)
            self.assertEqual((destination / "framework/Versions/Current/library").read_bytes(), b"ok")
            resolved = bootstrap.safe_member_path(
                destination, "cangjie/third_party/llvm/lib/../../../runtime/lib",
                allow_parent=True)
            self.assertEqual(resolved, (destination / "cangjie/runtime/lib").resolve())

    def test_extraction_provenance_is_required_and_reused(self):
        payload = b"archive placeholder"
        expected = artifact(payload)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination = root / "component"
            destination.mkdir()
            with self.assertRaisesRegex(bootstrap.BootstrapError, "no provenance marker"):
                bootstrap.extract_artifact(root / "missing.zip", expected, destination)
            bootstrap.extraction_marker(destination).write_text(json.dumps({
                "sha256": expected["sha256"],
            }), encoding="utf-8")
            self.assertTrue(bootstrap.extract_artifact(root / "missing.zip", expected, destination))

    def test_component_roots_and_github_outputs_are_unambiguous(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sdk = root / "sdk" / "nested"
            (sdk / "bin").mkdir(parents=True)
            (sdk / "runtime" / "lib").mkdir(parents=True)
            (sdk / "bin" / "cjc").write_bytes(b"compiler")
            (sdk / "tools" / "bin").mkdir(parents=True)
            (sdk / "tools" / "bin" / "cjpm").write_bytes(b"manager")
            setup = sdk / "envsetup.sh"
            setup.write_text("", encoding="utf-8")
            decoy = sdk / "runtime" / "envsetup.sh"
            decoy.write_text("", encoding="utf-8")
            resolved, env_setup = bootstrap.locate_component_root(
                "cangjie", root / "sdk", "linux-x86_64")
            self.assertEqual(resolved, sdk.resolve())
            self.assertEqual(env_setup, setup.resolve())
            runtime = sdk / "runtime" / "lib" / "linux_x86_64_cjnative"
            runtime.mkdir(parents=True)
            self.assertEqual(
                bootstrap.sdk_runtime_directory(sdk, "linux-x86_64"), runtime.resolve())

            output = root / "github-output"
            bootstrap.append_github_outputs({"cangjie_root": resolved}, {"GITHUB_OUTPUT": str(output)})
            self.assertEqual(output.read_text(encoding="utf-8"), f"cangjie_root={resolved}\n")
            with self.assertRaisesRegex(bootstrap.BootstrapError, "single line"):
                bootstrap.append_github_outputs({"bad": "a\nb"}, {"GITHUB_OUTPUT": str(output)})


if __name__ == "__main__":
    unittest.main()
