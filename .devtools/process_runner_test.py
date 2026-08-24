import pathlib
import sys
import unittest


DEVTOOLS = pathlib.Path(__file__).resolve().parent
if str(DEVTOOLS) not in sys.path:
    sys.path.insert(0, str(DEVTOOLS))

from process_runner import decode_process_output, run_command


class ProcessRunnerEncodingTests(unittest.TestCase):
    def test_utf8_output_wins_even_when_fallback_differs(self):
        self.assertEqual(decode_process_output("字体布局".encode("utf-8"), "cp936"), "字体布局")

    def test_windows_ansi_output_falls_back_without_replacement(self):
        self.assertEqual(decode_process_output("字体布局".encode("cp936"), "cp936"), "字体布局")

    def test_run_command_returns_text_for_ascii_child(self):
        code, stdout, stderr, timed_out = run_command(
            [sys.executable, "-c", "print('benchmark-ok')"], DEVTOOLS, 10
        )
        self.assertEqual(code, 0)
        self.assertEqual(stdout.strip(), "benchmark-ok")
        self.assertEqual(stderr, "")
        self.assertFalse(timed_out)


if __name__ == "__main__":
    unittest.main()
