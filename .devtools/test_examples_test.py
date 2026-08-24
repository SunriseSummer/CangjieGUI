#!/usr/bin/env python3
"""Standard-library tests for the examples E2E runner itself."""

import importlib.util
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("test_examples", Path(__file__).with_name("test_examples.py"))
runner = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = runner
spec.loader.exec_module(runner)


class ExamplesRunnerTest(unittest.TestCase):
    def test_change_selection_distinguishes_full_from_empty(self):
        self.assertEqual(runner.select_changed_paths([]), [])
        self.assertEqual(runner.select_changed_paths([Path("examples/contacts/main.cj")]), ["contacts"])
        self.assertIsNone(runner.select_changed_paths([Path("src/core/state.cj")]))

    def test_empty_explicit_selection_does_not_expand_to_full_fleet(self):
        self.assertEqual(runner.example_dirs([]), [])
        self.assertGreater(len(runner.example_dirs(None)), 0)

    def test_command_capture_reports_success(self):
        with tempfile.TemporaryDirectory() as directory:
            code, stdout, stderr, timed_out = runner.run_command(
                [sys.executable, "-c", "print('ready')"], Path(directory), 5
            )
        self.assertEqual(code, 0)
        self.assertEqual(stdout.strip(), "ready")
        self.assertEqual(stderr, "")
        self.assertFalse(timed_out)

    def test_timeout_terminates_the_process(self):
        started = time.perf_counter()
        code, _, _, timed_out = runner.run_command(
            [sys.executable, "-c", "import time; time.sleep(30)"], Path.cwd(), 0.1
        )
        self.assertEqual(code, 124)
        self.assertTrue(timed_out)
        self.assertLess(time.perf_counter() - started, 10)

    def test_timeout_preserves_output_emitted_before_termination(self):
        code, stdout, _, timed_out = runner.run_command(
            [sys.executable, "-u", "-c", "import time; print('checkpoint'); time.sleep(30)"],
            Path.cwd(),
            0.1,
        )
        self.assertEqual(code, 124)
        self.assertTrue(timed_out)
        self.assertIn("checkpoint", stdout)

    def test_retained_diff_uses_an_isolated_output_and_debug_switch(self):
        normal = runner.snapshot_command(Path("result.bmp"))
        forced = runner.snapshot_command(Path("result.full-retained.bmp"), force_full=True)

        self.assertNotIn("--cui-force-full-retained", normal[-1])
        self.assertNotIn("--skip-build", normal)
        self.assertIn("--skip-build", forced)
        self.assertIn('--snapshot "result.full-retained.bmp"', forced[-1])
        self.assertIn("--cui-force-full-retained", forced[-1])


if __name__ == "__main__":
    unittest.main()
