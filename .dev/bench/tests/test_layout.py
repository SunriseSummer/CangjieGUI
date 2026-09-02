"""Structural contracts for benchmark and fixture Cangjie projects."""

import tomllib
import unittest

from cui_dev.common.paths import (
    BENCH_TARGET_ROOT,
    BENCH_WORKLOADS_ROOT,
    DEV_TARGET_ROOT,
    FIXTURES_ROOT,
    REPOSITORY_ROOT,
)


class DevelopmentProjectLayoutTests(unittest.TestCase):
    def _manifest(self, path):
        with path.open("rb") as stream:
            return tomllib.load(stream)

    def test_every_benchmark_has_a_centralized_build_directory(self):
        manifests = sorted(BENCH_WORKLOADS_ROOT.rglob("cjpm.toml"))
        self.assertEqual(len(manifests), 10)
        for manifest in manifests:
            configured = self._manifest(manifest)["package"]["target-dir"]
            target = (manifest.parent / configured).resolve()
            self.assertTrue(target.is_relative_to(BENCH_TARGET_ROOT.resolve()), manifest)
            self.assertFalse((manifest.parent / "target").exists(), manifest)

    def test_fixtures_have_centralized_build_directories(self):
        manifests = sorted(FIXTURES_ROOT.rglob("cjpm.toml"))
        self.assertEqual(len(manifests), 2)
        for manifest in manifests:
            configured = self._manifest(manifest)["package"]["target-dir"]
            target = (manifest.parent / configured).resolve()
            self.assertTrue(target.is_relative_to((DEV_TARGET_ROOT / "build" / "fixtures").resolve()))

    def test_internal_path_dependencies_resolve(self):
        manifests = sorted(BENCH_WORKLOADS_ROOT.rglob("cjpm.toml")) + \
            sorted(FIXTURES_ROOT.rglob("cjpm.toml"))
        for manifest in manifests:
            dependencies = self._manifest(manifest).get("dependencies", {})
            for name, declaration in dependencies.items():
                dependency = (manifest.parent / declaration["path"]).resolve()
                if dependency.is_relative_to(REPOSITORY_ROOT.resolve()):
                    self.assertTrue((dependency / "cjpm.toml").is_file(),
                                    f"{manifest}: unresolved dependency {name} -> {dependency}")


if __name__ == "__main__":
    unittest.main()
