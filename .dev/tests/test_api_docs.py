"""Contract tests for API coverage and documentation snippet discovery."""

import tempfile
import unittest
from pathlib import Path

from cui_dev.checks.api_surface import api_surface_failures
from cui_dev.checks.doc_snippets import verified_snippets
from cui_dev.checks.docs import broken_links


class ApiDocumentationTests(unittest.TestCase):
    def test_local_markdown_anchor_must_exist(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            target = root / "target.md"
            target.write_text("# Existing section\n", encoding="utf-8")
            source = root / "source.md"
            source.write_text("[bad](target.md#missing)\n", encoding="utf-8")

            failures = broken_links(source)

            self.assertEqual(len(failures), 1)
            self.assertEqual(failures[0][0], 1)

    def test_surface_check_requires_type_page_index_and_function_anchor(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "src"
            api = root / "api"
            package_docs = api / "core"
            source.mkdir()
            package_docs.mkdir(parents=True)
            (source / "state.cj").write_text(
                "package cui.core\npublic class State {}\npublic func derive(): Unit {}\n",
                encoding="utf-8",
            )
            umbrella = source / "cui.cj"
            umbrella.write_text(
                "package cui\npublic import cui.core.State\npublic import cui.core.derive\n",
                encoding="utf-8",
            )
            umbrella_doc = api / "index.md"
            umbrella_doc.write_text("# cui\n", encoding="utf-8")
            (package_docs / "index.md").write_text("# cui.core\n", encoding="utf-8")

            failures = api_surface_failures(source, api, umbrella, umbrella_doc)

            self.assertTrue(any("missing API page" in item for item in failures))
            self.assertTrue(any("missing function reference" in item for item in failures))
            self.assertTrue(any("umbrella reference omits" in item for item in failures))

    def test_surface_check_requires_public_type_members(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "src"
            api = root / "api"
            package_docs = api / "core"
            source.mkdir()
            package_docs.mkdir(parents=True)
            (source / "state.cj").write_text(
                "package cui.core\n"
                "public class State {\n"
                "    public func get(): Int64 { 0 }\n"
                "}\n",
                encoding="utf-8",
            )
            umbrella = source / "cui.cj"
            umbrella.write_text(
                "package cui\npublic import cui.core.State\n",
                encoding="utf-8",
            )
            umbrella_doc = api / "index.md"
            umbrella_doc.write_text("# cui\n\n[State](core/State.md)\n", encoding="utf-8")
            (package_docs / "index.md").write_text(
                "# cui.core\n\n[State](State.md)\n", encoding="utf-8"
            )
            (package_docs / "State.md").write_text(
                "# State\n\n```cangjie\npublic class State\n```\n", encoding="utf-8"
            )

            failures = api_surface_failures(source, api, umbrella, umbrella_doc)

            self.assertTrue(any("State.get" in item for item in failures))

    def test_surface_check_counts_public_overloads(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "src"
            api = root / "api"
            package_docs = api / "core"
            source.mkdir()
            package_docs.mkdir(parents=True)
            (source / "state.cj").write_text(
                "package cui.core\n"
                "public class State {\n"
                "    public func set(value: Int64): Unit {}\n"
                "    public func set(value: String): Unit {}\n"
                "}\n",
                encoding="utf-8",
            )
            umbrella = source / "cui.cj"
            umbrella.write_text(
                "package cui\npublic import cui.core.State\n", encoding="utf-8"
            )
            umbrella_doc = api / "index.md"
            umbrella_doc.write_text("# cui\n\n[State](core/State.md)\n", encoding="utf-8")
            (package_docs / "index.md").write_text(
                "# cui.core\n\n[State](State.md)\n", encoding="utf-8"
            )
            (package_docs / "State.md").write_text(
                "# State\n\n```cangjie\npublic class State\n"
                "public func set(value: Int64): Unit\n```\n",
                encoding="utf-8",
            )

            failures = api_surface_failures(source, api, umbrella, umbrella_doc)

            self.assertTrue(any("1/2 overloads" in item for item in failures))

    def test_verified_snippet_must_be_a_complete_program(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            (root / "guide.md").write_text(
                "```cangjie verify role=complete\nlet value = 1\n```\n",
                encoding="utf-8",
            )

            snippets, failures = verified_snippets((root,))

            self.assertEqual(snippets, [])
            self.assertEqual(len(failures), 1)
            self.assertIn("complete docexample program", failures[0])

    def test_verified_snippet_records_source_location(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            page = root / "guide.md"
            page.write_text(
                "# Example\n\n```cangjie verify role=complete\n"
                "package docexample\n\nmain(): Unit {}\n```\n",
                encoding="utf-8",
            )

            snippets, failures = verified_snippets((root,))

            self.assertEqual(failures, [])
            self.assertEqual(len(snippets), 1)
            self.assertEqual(snippets[0].path, page)
            self.assertEqual(snippets[0].line, 4)

    def test_guide_rejects_unverified_cangjie_fragments(self):
        with tempfile.TemporaryDirectory() as raw:
            guide = Path(raw) / "guide"
            guide.mkdir()
            (guide / "page.md").write_text(
                "```cangjie\nlet value = 1\n```\n",
                encoding="utf-8",
            )

            snippets, failures = verified_snippets((guide,), strict_roots=(guide,))

            self.assertEqual(snippets, [])
            self.assertEqual(len(failures), 1)
            self.assertIn("must be complete and marked verify", failures[0])

    def test_api_rejects_unverified_usage_but_allows_declarations(self):
        with tempfile.TemporaryDirectory() as raw:
            api = Path(raw) / "api"
            api.mkdir()
            (api / "usage.md").write_text(
                "```cangjie\nlet state = State<Int64>(0)\n```\n",
                encoding="utf-8",
            )
            (api / "declaration.md").write_text(
                "```cangjie\npublic class State<T>\n```\n",
                encoding="utf-8",
            )

            snippets, failures = verified_snippets(
                (api,), strict_roots=(), declaration_roots=(api,)
            )

            self.assertEqual(snippets, [])
            self.assertEqual(len(failures), 1)
            self.assertIn("declaration or a verified program", failures[0])


if __name__ == "__main__":
    unittest.main()
