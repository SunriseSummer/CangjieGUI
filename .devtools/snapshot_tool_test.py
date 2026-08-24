#!/usr/bin/env python3
"""Boundary tests for the dependency-free BMP snapshot reader."""

import importlib.util
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("snapshot_tool", Path(__file__).with_name("snapshot_tool.py"))
snapshot_tool = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = snapshot_tool
spec.loader.exec_module(snapshot_tool)


def bmp_1x1():
    file_header = b"BM" + struct.pack("<IHHI", 58, 0, 0, 54)
    dib = struct.pack("<IiiHHIIiiII", 40, 1, 1, 1, 24, 0, 4, 0, 0, 0, 0)
    return file_header + dib + bytes((3, 2, 1, 0))


class SnapshotToolTest(unittest.TestCase):
    def test_reads_valid_bottom_up_bmp(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "one.bmp"
            path.write_bytes(bmp_1x1())
            width, height, rows = snapshot_tool.read_bmp(path)
        self.assertEqual((width, height), (1, 1))
        self.assertEqual(rows, [[(1, 2, 3)]])

    def test_rejects_truncated_bmp_with_value_error(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.bmp"
            path.write_bytes(b"BM")
            with self.assertRaises(ValueError):
                snapshot_tool.read_bmp(path)

    def test_rejects_out_of_range_tolerance(self):
        with self.assertRaises(ValueError):
            snapshot_tool.diff_images("a.bmp", "b.bmp", tolerance=256)


if __name__ == "__main__":
    unittest.main()
