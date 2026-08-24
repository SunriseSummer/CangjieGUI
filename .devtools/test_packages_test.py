#!/usr/bin/env python3
"""Standard-library self-tests for the isolated CUI package runner."""

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("test_packages", Path(__file__).with_name("test_packages.py"))
runner = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = runner
spec.loader.exec_module(runner)


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
