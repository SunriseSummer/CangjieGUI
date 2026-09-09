"""Negative controls for the static symbol payload gate."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from cui_dev.checks.symbol_linking import (
    Symbol, discover_symbols, inspect_payloads, probe_source, readonly_probe, run_probe, runtime_environment,
)


class SymbolLinkingTests(unittest.TestCase):
    def test_native_library_lookup_uses_the_platform_variable(self):
        for system, variable in [("win32", "PATH"), ("linux", "LD_LIBRARY_PATH"),
                                 ("darwin", "DYLD_LIBRARY_PATH")]:
            with self.subTest(system=system):
                environment = runtime_environment(Path("native-runtime"), system)
                self.assertTrue(environment[variable].startswith("native-runtime"))

    def test_unexpected_and_missing_artwork_both_fail(self):
        symbols = [Symbol("cui.symbols.clock", "ICON_CLOCK", b"CLOCK"),
                   Symbol("cui.symbols.search", "ICON_SEARCH", b"SEARCH")]
        self.assertTrue(inspect_payloads(b"CLOCK", symbols, {"cui.symbols.clock"})["ok"])
        result = inspect_payloads(b"SEARCH", symbols, {"cui.symbols.clock"})
        self.assertFalse(result["ok"])
        self.assertEqual(result["missing"], ["cui.symbols.clock"])
        self.assertEqual(result["unexpected"], ["cui.symbols.search"])
        self.assertFalse(inspect_payloads(b"CLOCK SEARCH", symbols, {"cui.symbols.clock"})["ok"])
        self.assertTrue(inspect_payloads(b"no artwork", symbols, set())["ok"])

    def test_discovery_rejects_unverifiable_sources(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            with self.assertRaisesRegex(ValueError, "no embedded"):
                discover_symbols(root)
            directory = root / "clock"
            directory.mkdir()
            path = directory / "source.cj"
            path.write_text("package cui.symbols.clock\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "one package"):
                discover_symbols(root)

    def test_discovery_validates_independence_and_unique_fingerprints(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            directory = root / "clock"
            directory.mkdir()
            path = directory / "source.cj"
            source = ('package cui.symbols.clock\nlet data = "<path d=\\"M1 2\\"/>"\n'
                      'public let ICON_CLOCK: IconSource = IconSource("test")\n')
            path.write_text(source, encoding="utf-8")
            self.assertEqual(discover_symbols(root)[0].artwork, b'<path d="M1 2"/>')
            path.write_text(source + 'import cui.symbols.search.ICON_SEARCH\n', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "must not import"):
                discover_symbols(root)
            path.write_text(source, encoding="utf-8")
            other = root / "search"
            other.mkdir()
            (other / "source.cj").write_text(source.replace("clock", "search").replace("ICON_CLOCK", "ICON_SEARCH"),
                                             encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "ambiguous"):
                discover_symbols(root)

    def test_probe_has_only_requested_imports_and_reads_the_constant(self):
        source = probe_source([Symbol("cui.symbols.clock", "ICON_CLOCK", b"CLOCK")])
        self.assertIn("import cui.symbols.clock.ICON_CLOCK", source)
        self.assertIn("match (ICON_CLOCK.renderingMode)", source)
        self.assertNotIn("ICON_CLOCK()", source)
        self.assertNotIn("import cui.*", source)
        self.assertIn("import cui.*", probe_source([], umbrella=True))

    def test_discovery_rejects_mutable_or_function_resources_and_misnamed_constants(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            path = root / "clock" / "source.cj"
            path.parent.mkdir()
            prefix = 'package cui.symbols.clock\nlet data = "<path d=\\"M1 2\\"/>"\n'
            for declaration in ["public var ICON_CLOCK: IconSource = load()",
                                "public func clockIcon(): IconSource { load() }",
                                "public let ICON_WRONG: IconSource = load()",
                                "public let ICON_CLOCK: IconSource = load()\npublic func extra(): Unit {}"]:
                with self.subTest(declaration=declaration):
                    path.write_text(prefix + declaration + "\n", encoding="utf-8")
                    with self.assertRaises(ValueError):
                        discover_symbols(root)

    def test_runtime_exit_marker_and_timeout_are_all_required(self):
        symbol = Symbol("cui.symbols.clock", "ICON_CLOCK", b"CLOCK")
        cases = [(0, "symbol-link-ok", "", False), (1, "symbol-link-ok", "failed", False),
                 (0, "", "", False), (124, "symbol-link-ok", "", True)]
        for runtime in cases:
            with self.subTest(runtime=runtime), tempfile.TemporaryDirectory() as raw:
                root = Path(raw)

                def command(args, *_positional, **_keywords):
                    if args[0] == "cjc":
                        Path(args[args.index("-o") + 1]).write_bytes(b"CLOCK")
                        return 0, "", "", False
                    return runtime

                with patch("cui_dev.checks.symbol_linking.run_command", side_effect=command):
                    result = run_probe("clock", [symbol], {symbol.package}, [symbol],
                                       root, root, root, 30)
                expected = runtime == cases[0]
                self.assertEqual(result["runtime_ok"], expected)
                self.assertEqual(result["ok"], expected)

    def test_readonly_probe_requires_the_specific_compiler_rejection(self):
        symbol = Symbol("cui.symbols.clock", "ICON_CLOCK", b"CLOCK")
        diagnostic = "cannot assign to immutable value: ICON_CLOCK"
        cases = [(1, "", diagnostic, False), (0, "", diagnostic, False),
                 (1, "", "package ICON_CLOCK not found", False), (124, "", diagnostic, True)]
        for response in cases:
            with self.subTest(response=response), tempfile.TemporaryDirectory() as raw:
                with patch("cui_dev.checks.symbol_linking.run_command", return_value=response):
                    result = readonly_probe(symbol, Path(raw), Path(raw), 30)
                self.assertEqual(result["ok"], response == cases[0])
