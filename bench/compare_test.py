#!/usr/bin/env python3
"""Self-tests for ``bench/compare.py`` capture validation and aggregation."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("bench_compare", Path(__file__).with_name("compare.py"))
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class CompareTest(unittest.TestCase):
    def write(self, directory, name, lines):
        path = Path(directory) / name
        path.write_text("\n".join(lines), encoding="utf-8")
        return path

    def test_median_is_default_and_min_remains_available(self):
        with tempfile.TemporaryDirectory() as directory:
            captures = [
                self.write(directory, f"sample-{index}.txt", [f"@@RESULT|frame|g|case|{value}|10"])
                for index, value in enumerate((300, 100, 200))
            ]
            self.assertEqual(compare.load_side(captures)["frame|g|case"], 200)
            self.assertEqual(compare.load_side(captures, "min")["frame|g|case"], 100)

    def test_duplicate_and_mismatched_captures_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            duplicate = self.write(directory, "duplicate.txt", [
                "@@RESULT|frame|g|case|100|10",
                "@@RESULT|frame|g|case|200|10",
            ])
            with self.assertRaises(ValueError):
                compare.parse_capture(duplicate)
            first = self.write(directory, "first.txt", ["@@RESULT|frame|g|case|100|10"])
            second = self.write(directory, "second.txt", ["@@RESULT|frame|g|other|100|10"])
            with self.assertRaises(ValueError):
                compare.load_side([first, second])

    def test_comparison_sorts_slowest_first_and_reports_asymmetry(self):
        rows, only_a, only_b = compare.compare_sides(
            {"frame|g|a": 100, "frame|g|removed": 50},
            {"frame|g|a": 150, "frame|g|added": 75},
        )
        self.assertEqual(rows[0][0], "frame|g|a")
        self.assertEqual(rows[0][3], 1.5)
        self.assertEqual(only_a, ["frame|g|removed"])
        self.assertEqual(only_b, ["frame|g|added"])


if __name__ == "__main__":
    unittest.main()
