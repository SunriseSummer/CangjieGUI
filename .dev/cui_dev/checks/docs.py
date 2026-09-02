#!/usr/bin/env python3
"""Check repository Markdown links without third-party dependencies."""

import re
import sys
from functools import lru_cache
from urllib.parse import unquote, urlsplit

from cui_dev.common.paths import DEV_ROOT, REPOSITORY_ROOT
from cui_dev.checks.api_surface import api_surface_failures


ROOT = REPOSITORY_ROOT
LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*#*\s*$")
SCAN = [ROOT / "README.md", DEV_ROOT, ROOT / "examples" / "README.md", ROOT / "docs"]


def markdown_files():
    files = []
    for entry in SCAN:
        if entry.is_file():
            files.append(entry)
        elif entry.is_dir():
            files.extend(entry.rglob("*.md"))
    return sorted(set(files))


def link_target(raw):
    target = raw.strip()
    if target.startswith("<") and ">" in target:
        target = target[1:target.index(">")]
    elif " \"" in target:
        target = target.split(" \"", 1)[0]
    parsed = urlsplit(target)
    if parsed.scheme or (not parsed.path and not parsed.fragment):
        return None
    return unquote(parsed.path), unquote(parsed.fragment)


@lru_cache(maxsize=None)
def heading_anchors(path):
    """Return GitHub-style anchors for Markdown headings, including duplicate suffixes."""
    anchors = set()
    occurrences = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = HEADING.match(line)
        if match is None:
            continue
        heading = re.sub(r"!?\[([^\]]+)\]\([^)]+\)", r"\1", match.group(1))
        heading = heading.replace("`", "").lower()
        anchor = re.sub(r"[^\w\- ]", "", heading, flags=re.UNICODE)
        anchor = re.sub(r"\s+", "-", anchor.strip())
        duplicate = occurrences.get(anchor, 0)
        occurrences[anchor] = duplicate + 1
        anchors.add(anchor if duplicate == 0 else f"{anchor}-{duplicate}")
    return anchors


def broken_links(path):
    failures = []
    text = path.read_text(encoding="utf-8")
    for line_number, line in enumerate(text.splitlines(), 1):
        for match in LINK.finditer(line):
            target = link_target(match.group(1))
            if target is None:
                continue
            local, fragment = target
            if not local:
                resolved = path
            elif local.startswith("/"):
                resolved = ROOT / local.lstrip("/")
            else:
                resolved = path.parent / local
            if not resolved.resolve().exists():
                failures.append((line_number, match.group(1), resolved.resolve()))
            elif fragment and resolved.suffix.lower() == ".md":
                if fragment not in heading_anchors(resolved.resolve()):
                    failures.append((line_number, match.group(1), resolved.resolve()))
    return failures


def main():
    failures = []
    files = markdown_files()
    for path in files:
        for line, target, resolved in broken_links(path):
            failures.append((path, line, target, resolved))
    surface_failures = api_surface_failures()
    if failures or surface_failures:
        for path, line, target, resolved in failures:
            print(f"[BROKEN] {path.relative_to(ROOT)}:{line}: {target} -> {resolved}")
        for failure in surface_failures:
            print(f"[API] {failure}")
        print(
            f"Documentation check failed: {len(failures)} broken link(s), "
            f"{len(surface_failures)} API coverage error(s)."
        )
        return 1
    print(f"Documentation OK: {len(files)} Markdown files; public API surface covered.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
