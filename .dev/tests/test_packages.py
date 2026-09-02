#!/usr/bin/env python3
"""Standard-library self-tests for the isolated CUI package runner."""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

from cui_dev.checks import packages as runner


class PackageRunnerTest(unittest.TestCase):
    def test_discovers_every_public_source_package(self):
        self.assertEqual(
            runner.discover_packages(),
            ["controls", "core", "desktop", "media", "testing", "text"],
        )

    def test_summary_parser_uses_the_final_project_summary(self):
        log = """Summary: TOTAL: 2
    PASSED: 1, SKIPPED: 0, ERROR: 0
    FAILED: 1
Summary: TOTAL: 5
    PASSED: 5, SKIPPED: 0, ERROR: 0
    FAILED: 0
"""
        self.assertEqual(runner.parse_summary(log), (5, 5, 0, 0, 0))

    def test_summary_parser_rejects_unstructured_success_text(self):
        with self.assertRaises(ValueError):
            runner.parse_summary("cjpm test success")

    def test_coverage_command_is_explicit(self):
        build = runner.package_build_command("core", coverage=True)
        normal = runner.package_command("core")
        coverage = runner.package_command("core", coverage=True)
        self.assertIn("--no-run", build)
        self.assertIn("--skip-build", normal)
        self.assertIn("--coverage", build)
        self.assertNotIn("--coverage", normal)
        self.assertIn("--coverage", coverage)

    def test_coverage_environment_isolates_gcov_counters(self):
        directory = runner.ROOT / "target" / "probe-coverage"
        environment = runner.coverage_environment(directory)
        self.assertEqual(environment["GCOV_PREFIX"], str(directory))
        self.assertEqual(environment["GCOV_PREFIX_STRIP"], "100")
        self.assertEqual(environment.get("PATH"), os.environ.get("PATH"))

    def test_coverage_session_removes_only_its_generated_metadata_root(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT / "target") as temporary:
            base = Path(temporary)
            metadata = base / "cov_output"
            sibling = base / "keep"
            metadata.mkdir()
            sibling.mkdir()
            (metadata / "stale.gcno").write_bytes(b"stale")
            (sibling / "user.txt").write_text("keep", encoding="utf-8")

            runner.reset_coverage_metadata(metadata)

            self.assertFalse(metadata.exists())
            self.assertEqual((sibling / "user.txt").read_text(encoding="utf-8"), "keep")

    def test_coverage_session_removes_only_the_cjpm_release_cache(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT / "target") as temporary:
            base = Path(temporary)
            release = base / "release"
            sibling = base / "cross-platform"
            release.mkdir()
            sibling.mkdir()
            (release / "compiled.bin").write_bytes(b"generated")
            (sibling / "evidence.json").write_text("{}", encoding="utf-8")

            runner.reset_cjpm_build_cache(release)

            self.assertFalse(release.exists())
            self.assertEqual((sibling / "evidence.json").read_text(encoding="utf-8"), "{}")

    def test_coverage_session_rejects_a_symlink_metadata_root(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT / "target") as temporary:
            base = Path(temporary)
            target = base / "actual"
            link = base / "cov_output"
            target.mkdir()
            try:
                link.symlink_to(target, target_is_directory=True)
            except OSError:
                self.skipTest("symbolic links are unavailable on this Windows host")
            with self.assertRaisesRegex(ValueError, "symbolic link"):
                runner.reset_coverage_metadata(link)
            self.assertTrue(target.is_dir())

    def test_coverage_session_rejects_generated_roots_outside_workspace(self):
        outside = Path(tempfile.gettempdir()) / "release"
        with self.assertRaisesRegex(ValueError, "within the workspace"):
            runner.reset_cjpm_build_cache(outside)

    def test_coverage_sources_are_normalized_from_staging(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT / "target") as temporary:
            base = Path(temporary)
            staging = base / "a" / "b"
            staging.mkdir(parents=True)
            report = base / "coverage.json"
            relative_source = os.path.relpath(
                runner.ROOT / "src" / "core" / "state.cj", staging)
            report.write_text(json.dumps({"fileLists": [
                {"filepath": relative_source, "totalLines": 1, "hitLines": [1]},
                {"filepath": "core/state.cj", "totalLines": 1, "hitLines": [1]},
            ]}), encoding="utf-8")

            runner.normalize_coverage_sources(report, staging)

            payload = json.loads(report.read_text(encoding="utf-8"))
            self.assertEqual(payload["fileLists"][0]["filepath"], "src/core/state.cj")
            self.assertEqual(payload["fileLists"][1]["filepath"], "src/core/state.cj")

    def test_coverage_staging_recovers_production_graph_from_another_package_build(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT / "target") as temporary:
            base = Path(temporary)
            metadata = base / "cov_output"
            current = metadata / "cui.core"
            donor = metadata / "cui.controls"
            counters = base / "counters"
            staging = base / "staging"
            current.mkdir(parents=True)
            donor.mkdir(parents=True)
            counters.mkdir(parents=True)
            (current / "0-cui.core$test.gcno").write_bytes(b"test graph")
            (donor / "0-cui.core.gcno").write_bytes(b"production graph")
            (counters / "0-cui.core.gcda").write_bytes(b"production counter")
            (counters / "0-cui.core$test.gcda").write_bytes(b"test counter")

            graphs, counter_count = runner.stage_coverage_inputs(
                "core", counters, staging, metadata_root=metadata)

            self.assertEqual((graphs, counter_count), (1, 1))
            self.assertEqual((staging / "0-cui.core.gcno").read_bytes(), b"production graph")
            self.assertEqual((staging / "0-cui.core.gcda").read_bytes(), b"production counter")
            self.assertFalse((staging / "0-cui.core$test.gcda").exists())

    def test_coverage_staging_rejects_ambiguous_graph_generations(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT / "target") as temporary:
            base = Path(temporary)
            metadata = base / "cov_output"
            first = metadata / "cui.controls"
            second = metadata / "cui.text"
            current = metadata / "cui.core"
            counters = base / "counters"
            for directory in (first, second, current, counters):
                directory.mkdir(parents=True)
            (first / "0-cui.core.gcno").write_bytes(b"first generation")
            (second / "0-cui.core.gcno").write_bytes(b"second generation")
            (counters / "0-cui.core.gcda").write_bytes(b"counter")

            with self.assertRaisesRegex(ValueError, "non-identical"):
                runner.stage_coverage_inputs(
                    "core", counters, base / "staging", metadata_root=metadata)

    def test_coverage_aggregation_unions_packages_and_excludes_tests_and_dependencies(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT / "target") as temporary:
            base = Path(temporary)
            first = base / "first.json"
            second = base / "second.json"
            first.write_text(json.dumps({"fileLists": [
                {"filepath": "src\\core\\state.cj", "totalLines": 4, "hitLines": [1, 2]},
                {"filepath": "src\\core\\state_test.cj", "totalLines": 2, "hitLines": [1, 2]},
                {"filepath": "..\\CangjieSDL\\src\\renderer.cj", "totalLines": 5, "hitLines": [1]},
            ]}), encoding="utf-8")
            second.write_text(json.dumps({"fileLists": [
                {"filepath": "src\\core\\state.cj", "totalLines": 4, "hitLines": [2, 3]},
                {"filepath": "src\\text\\text_field.cj", "totalLines": 2, "hitLines": [1]},
            ]}), encoding="utf-8")
            results = [
                runner.PackageResult("core", True, 0.0, 0, 1, 1, 0, 0, 0, [], [], "",
                                     coverage_report=str(first.relative_to(runner.ROOT))),
                runner.PackageResult("text", True, 0.0, 0, 1, 1, 0, 0, 0, [], [], "",
                                     coverage_report=str(second.relative_to(runner.ROOT))),
            ]
            summary = runner.aggregate_coverage(results)
            self.assertEqual(summary["overall"]["files"], 2)
            self.assertEqual(summary["overall"]["hit_lines"], 4)
            self.assertEqual(summary["overall"]["total_lines"], 6)
            self.assertEqual(summary["packages"]["core"]["hit_lines"], 3)


if __name__ == "__main__":
    unittest.main()
