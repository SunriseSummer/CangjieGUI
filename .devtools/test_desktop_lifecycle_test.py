#!/usr/bin/env python3
"""Self-tests for the isolated real-window lifecycle runner CLI."""

import contextlib
import io
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_desktop_lifecycle as lifecycle


class DesktopLifecycleRunnerTests(unittest.TestCase):
    def test_defaults_are_single_bounded_run(self):
        args = lifecycle.parse_args([])
        self.assertEqual(args.repeat, 1)
        self.assertEqual(args.timeout, 120)

    def test_repeat_and_timeout_are_configurable(self):
        args = lifecycle.parse_args(["--repeat", "20", "--timeout", "30"])
        self.assertEqual(args.repeat, 20)
        self.assertEqual(args.timeout, 30)

    def test_non_positive_repeat_is_rejected(self):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                lifecycle.parse_args(["--repeat", "0"])

    def test_each_global_state_contract_is_process_isolated(self):
        self.assertEqual(lifecycle.SCENARIOS, (
            "retained-damage", "automatic-partial", "automatic-fallback", "lifecycle"))


if __name__ == "__main__":
    unittest.main()
