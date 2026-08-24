#!/usr/bin/env python3
"""Check repository Markdown links without third-party dependencies."""

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
SCAN = [ROOT / "README.md", ROOT / ".devtools" / "README.md", ROOT / "bench" / "README.md",
        ROOT / "examples" / "README.md", ROOT / "docs"]


def markdown_files():
    files = []
    for entry in SCAN:
        if entry.is_file():
            files.append(entry)
        elif entry.is_dir():
            files.extend(entry.rglob("*.md"))
    return sorted(set(files))


def link_path(raw):
    target = raw.strip()
    if target.startswith("<") and ">" in target:
        target = target[1:target.index(">")]
    elif " \"" in target:
        target = target.split(" \"", 1)[0]
    parsed = urlsplit(target)
    if parsed.scheme or not parsed.path:
        return None
    return unquote(parsed.path)


def broken_links(path):
    failures = []
    text = path.read_text(encoding="utf-8")
    for line_number, line in enumerate(text.splitlines(), 1):
        for match in LINK.finditer(line):
            local = link_path(match.group(1))
            if local is None:
                continue
            resolved = (ROOT / local.lstrip("/")) if local.startswith("/") else (path.parent / local)
            if not resolved.resolve().exists():
                failures.append((line_number, match.group(1), resolved.resolve()))
    return failures


def main():
    failures = []
    files = markdown_files()
    for path in files:
        for line, target, resolved in broken_links(path):
            failures.append((path, line, target, resolved))
    if failures:
        for path, line, target, resolved in failures:
            print(f"[BROKEN] {path.relative_to(ROOT)}:{line}: {target} -> {resolved}")
        print(f"{len(failures)} broken local Markdown link(s) in {len(files)} files.")
        return 1
    print(f"Markdown links OK: {len(files)} files checked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
