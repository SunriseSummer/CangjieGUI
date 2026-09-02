"""Compile every complete Cangjie example marked ``verify`` in the documentation."""

import argparse
import os
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

from cui_dev.common.paths import DEV_TARGET_ROOT, REPOSITORY_ROOT
from cui_dev.common.process import run_command


API_ROOT = REPOSITORY_ROOT / "docs" / "api"
GUIDE_ROOT = REPOSITORY_ROOT / "docs" / "guide"
DOC_ROOTS = (API_ROOT, GUIDE_ROOT)
STRICT_ROOTS = (REPOSITORY_ROOT / "docs" / "guide",)
WORKSPACE = DEV_TARGET_ROOT / "doc-snippets"
OPENING_FENCE = re.compile(r"^```cangjie(?:\s+(.*))?\s*$")
PACKAGE_LINE = re.compile(r"(?m)^package\s+docexample\s*$")


@dataclass(frozen=True)
class Snippet:
    path: Path
    line: int
    source: str


def _is_api_declaration(source: str) -> bool:
    """Whether a non-runnable API block only shows an import or public declaration."""
    if PACKAGE_LINE.search(source) is not None:
        return False
    lines = [line.strip() for line in source.splitlines() if line.strip()]
    if not lines:
        return False
    first = lines[0]
    if "public" in source:
        return True
    if first.startswith(("import ", "mut prop ", "prop ", "func ", "extend ", "|")):
        return True
    return len(lines) == 1 and re.fullmatch(r"[A-Z][A-Za-z0-9_]*(?:\(.*\))?", first) is not None


def verified_snippets(
    roots: tuple[Path, ...] = DOC_ROOTS,
    strict_roots: tuple[Path, ...] = STRICT_ROOTS,
    declaration_roots: tuple[Path, ...] = (API_ROOT,),
) -> tuple[list[Snippet], list[str]]:
    """Extract verified programs and require complete examples in strict roots."""
    snippets: list[Snippet] = []
    failures: list[str] = []
    strict = {path.resolve() for path in strict_roots}
    declarations = {path.resolve() for path in declaration_roots}
    for root in roots:
        require_verification = root.resolve() in strict
        api_declarations_only = root.resolve() in declarations
        for path in sorted(root.rglob("*.md")):
            lines = path.read_text(encoding="utf-8").splitlines()
            index = 0
            while index < len(lines):
                match = OPENING_FENCE.match(lines[index])
                if match is None:
                    index += 1
                    continue
                attributes = set((match.group(1) or "").split())
                opening_line = index + 1
                index += 1
                body: list[str] = []
                while index < len(lines) and lines[index] != "```":
                    body.append(lines[index])
                    index += 1
                if index == len(lines):
                    failures.append(f"unclosed Cangjie fence: {path}:{opening_line}")
                    break
                source = "\n".join(body).rstrip() + "\n"
                if require_verification and "verify" not in attributes:
                    failures.append(
                        f"guide Cangjie example must be complete and marked verify: "
                        f"{path}:{opening_line}"
                    )
                elif "role=complete" in attributes and "verify" not in attributes:
                    failures.append(
                        f"complete Cangjie example is not marked verify: {path}:{opening_line}"
                    )
                elif (
                    api_declarations_only
                    and "verify" not in attributes
                    and not _is_api_declaration(source)
                ):
                    failures.append(
                        f"API Cangjie block must be a declaration or a verified program: "
                        f"{path}:{opening_line}"
                    )
                if "verify" in attributes:
                    if PACKAGE_LINE.search(source) is None or "main(): Unit" not in source:
                        failures.append(
                            f"verified example must be a complete docexample program: "
                            f"{path}:{opening_line}"
                        )
                    else:
                        snippets.append(Snippet(path, opening_line + 1, source))
                index += 1
    return snippets, failures


def _reset_workspace(workspace: Path) -> None:
    resolved = workspace.resolve()
    target = DEV_TARGET_ROOT.resolve()
    if target not in resolved.parents:
        raise ValueError(f"refusing to replace snippet workspace outside {target}: {resolved}")
    if resolved.exists():
        shutil.rmtree(resolved)
    (resolved / "src").mkdir(parents=True)


def _write_workspace(snippets: list[Snippet], workspace: Path = WORKSPACE) -> dict[str, Snippet]:
    _reset_workspace(workspace)
    dependency = Path(os.path.relpath(REPOSITORY_ROOT, workspace)).as_posix()
    manifest = (
        '[package]\n'
        'cjc-version = "1.0.5"\n'
        'name = "docexample"\n'
        'version = "0.0.0"\n'
        'output-type = "executable"\n\n'
        'compile-option = "-Woff unused"\n\n'
        '[dependencies]\n'
        f'cui = {{ path = "{dependency}" }}\n'
    )
    (workspace / "cjpm.toml").write_text(manifest, encoding="utf-8", newline="\n")
    (workspace / "src" / "main.cj").write_text(
        "package docexample\n\nmain(): Unit {}\n", encoding="utf-8", newline="\n"
    )

    mapping: dict[str, Snippet] = {}
    for position, snippet in enumerate(snippets, 1):
        package = f"snippet_{position:03d}"
        source = PACKAGE_LINE.sub(f"package docexample.{package}", snippet.source, count=1)
        directory = workspace / "src" / package
        directory.mkdir()
        (directory / "main.cj").write_text(source, encoding="utf-8", newline="\n")
        mapping[package] = snippet
    return mapping


def _source_label(snippet: Snippet) -> str:
    return f"{snippet.path.relative_to(REPOSITORY_ROOT)}:{snippet.line}"


def _rewrite_diagnostics(output: str, mapping: dict[str, Snippet]) -> str:
    rewritten = output
    for package, snippet in mapping.items():
        generated = str((WORKSPACE / "src" / package / "main.cj").resolve())
        rewritten = rewritten.replace(generated, _source_label(snippet))
        rewritten = rewritten.replace(generated.replace("\\", "/"), _source_label(snippet))
    return rewritten


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="compile verified Cangjie documentation examples")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--keep-workspace", action="store_true")
    args = parser.parse_args(argv)

    snippets, failures = verified_snippets()
    if failures:
        for failure in failures:
            print(f"[DOC-SNIPPET] {failure}", file=sys.stderr)
        return 1
    if not snippets:
        print("No verified Cangjie documentation examples found.", file=sys.stderr)
        return 1

    mapping = _write_workspace(snippets)
    code, stdout, stderr, timed_out = run_command(
        ["cjpm", "build"], WORKSPACE, args.timeout
    )
    if code != 0:
        reason = "timed out" if timed_out else f"exited with {code}"
        print(f"Documentation snippet build {reason}.", file=sys.stderr)
        diagnostics = _rewrite_diagnostics(stdout + stderr, mapping)
        print(diagnostics.rstrip(), file=sys.stderr)
        return 1
    print(f"Cangjie documentation examples OK: {len(snippets)} programs compiled.")
    if not args.keep_workspace:
        _reset_workspace(WORKSPACE)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
