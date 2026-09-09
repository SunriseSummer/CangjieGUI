"""Check that the handwritten API reference covers the public CUI surface."""

import re
from pathlib import Path

from cui_dev.common.paths import REPOSITORY_ROOT


SOURCE_ROOT = REPOSITORY_ROOT / "src"
API_ROOT = REPOSITORY_ROOT / "docs" / "api" / "cui"
UMBRELLA_SOURCE = SOURCE_ROOT / "cui.cj"
UMBRELLA_DOC = API_ROOT / "index.md"

PACKAGE = re.compile(r"(?m)^package\s+(cui(?:\.[a-z][a-z0-9_]*)*)\s*$")
PUBLIC_TYPE = re.compile(
    r"(?m)^public\s+(?:open\s+)?(?:class|interface|struct|enum)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)"
)
PUBLIC_FUNCTION = re.compile(r"(?m)^public\s+func\s+([A-Za-z_][A-Za-z0-9_]*)")
PUBLIC_VALUE = re.compile(r"(?m)^public\s+(let|const|var)\s+([A-Za-z_][A-Za-z0-9_]*)")
CUI_IMPORT = re.compile(
    r"(?m)^public\s+import\s+cui\.([a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*)\.([A-Za-z_][A-Za-z0-9_]*)\s*$"
)
SPECIAL_PAGES = {"extensions.md", "functions.md", "values.md", "index.md"}
PUBLIC_MEMBER = re.compile(
    r"^public\s+(?:(?:static|mut|open|override)\s+)*"
    r"(let|var|prop|func)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
INTERFACE_MEMBER = re.compile(
    r"^(?:(?:static|mut)\s+)*(prop|func)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
ENUM_CASE = re.compile(r"^\|\s*([A-Za-z_][A-Za-z0-9_]*)")
WIDGET_CALLBACKS = {
    "acceptsStretch",
    "draw",
    "flexWeight",
    "focusableId",
    "focusableIds",
    "handle",
    "isFlexible",
    "layout",
    "measure",
    "needsDetachedLayout",
    "paintOutset",
    "participatesInLayout",
    "pointerEventScope",
}


def _code_only(text: str) -> str:
    """Blank comments and strings while preserving newlines for brace scanning."""
    output: list[str] = []
    index = 0
    state = "code"
    while index < len(text):
        if state == "code":
            if text.startswith("//", index):
                output.extend("  ")
                index += 2
                state = "line-comment"
            elif text.startswith("/*", index):
                output.extend("  ")
                index += 2
                state = "block-comment"
            elif text[index] == '"':
                output.append(" ")
                index += 1
                state = "string"
            else:
                output.append(text[index])
                index += 1
        elif state == "line-comment":
            output.append("\n" if text[index] == "\n" else " ")
            if text[index] == "\n":
                state = "code"
            index += 1
        elif state == "block-comment":
            if text.startswith("*/", index):
                output.extend("  ")
                index += 2
                state = "code"
            else:
                output.append("\n" if text[index] == "\n" else " ")
                index += 1
        elif text[index] == "\\" and index + 1 < len(text):
            output.extend("  ")
            index += 2
        elif text[index] == '"':
            output.append(" ")
            index += 1
            state = "code"
        else:
            output.append("\n" if text[index] == "\n" else " ")
            index += 1
    return "".join(output)


def _type_members(text: str) -> dict[str, dict[tuple[str, str], int]]:
    """Return public member declaration counts for each top-level public type."""
    code = _code_only(text)
    members: dict[str, dict[tuple[str, str], int]] = {}
    for match in PUBLIC_TYPE.finditer(code):
        kind = match.group(0).split()[1]
        if kind == "open":
            kind = match.group(0).split()[2]
        name = match.group(1)
        opening = code.find("{", match.end())
        if opening < 0:
            continue
        depth = 0
        closing = None
        for position in range(opening, len(code)):
            if code[position] == "{":
                depth += 1
            elif code[position] == "}":
                depth -= 1
                if depth == 0:
                    closing = position
                    break
        if closing is None:
            continue

        is_widget_subtype = re.search(r"<:\s*Widget\b", code[match.end():opening]) is not None
        found: dict[tuple[str, str], int] = {}
        depth = 1
        for line in code[opening + 1:closing].splitlines():
            stripped = line.strip()
            if depth == 1:
                member = PUBLIC_MEMBER.match(stripped)
                implicit_interface_member = False
                if member is None and kind == "interface":
                    member = INTERFACE_MEMBER.match(stripped)
                    implicit_interface_member = member is not None
                if member is not None:
                    member_kind, member_name = member.groups()
                    if implicit_interface_member:
                        member_kind = f"interface-{member_kind}"
                    if not (is_widget_subtype and member_name in WIDGET_CALLBACKS):
                        key = (member_kind, member_name)
                        found[key] = found.get(key, 0) + 1
                elif re.match(r"^public\s+init\b", stripped):
                    key = ("init", "init")
                    found[key] = found.get(key, 0) + 1
                elif kind == "enum":
                    enum_case = ENUM_CASE.match(stripped)
                    if enum_case is not None:
                        key = ("case", enum_case.group(1))
                        found[key] = found.get(key, 0) + 1
            depth += line.count("{") - line.count("}")
        members[name] = found
    return members


def source_surface(source_root: Path = SOURCE_ROOT) -> tuple[set[tuple[str, str]], set[tuple[str, str]]]:
    """Return public top-level types and functions as ``(subpackage, name)`` pairs."""
    types: set[tuple[str, str]] = set()
    functions: set[tuple[str, str]] = set()
    for path in sorted(source_root.rglob("*.cj")):
        if path.name.endswith("_test.cj"):
            continue
        text = path.read_text(encoding="utf-8")
        package_match = PACKAGE.search(text)
        if package_match is None or "." not in package_match.group(1):
            continue
        subpackage = package_match.group(1).split(".", 1)[1]
        types.update((subpackage, match.group(1)) for match in PUBLIC_TYPE.finditer(text))
        functions.update(
            (subpackage, match.group(1)) for match in PUBLIC_FUNCTION.finditer(text)
        )
    return types, functions


def source_type_members(
    source_root: Path = SOURCE_ROOT,
) -> dict[tuple[str, str], dict[tuple[str, str], int]]:
    """Return public member counts keyed by ``(subpackage, type)``."""
    result: dict[tuple[str, str], dict[tuple[str, str], int]] = {}
    for path in sorted(source_root.rglob("*.cj")):
        if path.name.endswith("_test.cj"):
            continue
        text = path.read_text(encoding="utf-8")
        package_match = PACKAGE.search(text)
        if package_match is None or "." not in package_match.group(1):
            continue
        subpackage = package_match.group(1).split(".", 1)[1]
        for type_name, members in _type_members(text).items():
            target = result.setdefault((subpackage, type_name), {})
            for member, count in members.items():
                target[member] = target.get(member, 0) + count
    return result


def source_values(source_root: Path) -> dict[tuple[str, str], str]:
    """Return public package values and their declared mutability (excluding type fields)."""
    result = {}
    for path in sorted(source_root.rglob("*.cj")):
        if path.name.endswith("_test.cj"):
            continue
        code = _code_only(path.read_text(encoding="utf-8"))
        package = PACKAGE.search(code)
        if package is None or "." not in package[1]:
            continue
        subpackage = package[1].split(".", 1)[1]
        for kind, name in PUBLIC_VALUE.findall(code):
            result[subpackage, name] = kind
    return result


def api_surface_failures(
    source_root: Path = SOURCE_ROOT,
    api_root: Path = API_ROOT,
    umbrella_source: Path = UMBRELLA_SOURCE,
    umbrella_doc: Path = UMBRELLA_DOC,
) -> list[str]:
    """Return actionable API coverage failures without changing repository state."""
    failures: list[str] = []
    types, functions = source_surface(source_root)
    members_by_type = source_type_members(source_root)
    values = source_values(source_root)

    for subpackage, name in sorted(types):
        package_docs = api_root.joinpath(*subpackage.split("."))
        page = package_docs / f"{name}.md"
        index = package_docs / "index.md"
        if not page.is_file():
            failures.append(f"missing API page for cui.{subpackage}.{name}: {page}")
            continue
        page_text = page.read_text(encoding="utf-8")
        if f"# {name}" not in page_text:
            failures.append(f"API page has no '# {name}' heading: {page}")
        declaration = re.compile(
            rf"public\s+(?:open\s+)?(?:class|interface|struct|enum)\s+{re.escape(name)}\b"
        )
        if declaration.search(page_text) is None:
            failures.append(f"API page has no public declaration for {name}: {page}")
        for (member_kind, member), count in sorted(
            members_by_type.get((subpackage, name), {}).items()
        ):
            marker = "public init" if member_kind == "init" else member
            if re.search(rf"\b{re.escape(marker)}\b", page_text) is None:
                failures.append(
                    f"API page omits public member cui.{subpackage}.{name}.{member}: {page}"
                )
                continue
            if member_kind == "init":
                documented_count = len(re.findall(r"\bpublic\s+init\b", page_text))
            elif member_kind == "func":
                documented_count = len(
                    re.findall(
                        rf"\bpublic\s+(?:static\s+)?func\s+{re.escape(member)}\b",
                        page_text,
                    )
                )
            else:
                continue
            if documented_count < count:
                failures.append(
                    f"API page documents {documented_count}/{count} overloads for "
                    f"cui.{subpackage}.{name}.{member}: {page}"
                )
        if not index.is_file() or f"]({name}.md)" not in index.read_text(encoding="utf-8"):
            failures.append(f"package index does not link {name}.md: {index}")

    for subpackage, name in sorted(functions):
        package_docs = api_root.joinpath(*subpackage.split("."))
        functions_page = package_docs / "functions.md"
        index = package_docs / "index.md"
        if not functions_page.is_file():
            failures.append(f"missing function reference for cui.{subpackage}.{name}")
            continue
        function_text = functions_page.read_text(encoding="utf-8")
        if re.search(rf"(?m)^###\s+{re.escape(name)}\s*$", function_text) is None:
            failures.append(f"function reference has no heading for cui.{subpackage}.{name}")
        anchor = name.lower()
        if not index.is_file() or f"](functions.md#{anchor})" not in index.read_text(encoding="utf-8"):
            failures.append(f"package index does not link cui.{subpackage}.{name}")

    for (subpackage, name), kind in sorted(values.items()):
        package_docs = api_root.joinpath(*subpackage.split("."))
        page = package_docs / "values.md"
        index = package_docs / "index.md"
        if not page.is_file():
            failures.append(f"missing value reference for cui.{subpackage}.{name}")
            continue
        text = page.read_text(encoding="utf-8")
        if re.search(rf"(?m)^###\s+{re.escape(name)}\s*$", text) is None:
            failures.append(f"value reference has no heading for cui.{subpackage}.{name}")
        if re.search(rf"\bpublic\s+{kind}\s+{re.escape(name)}\s*[:=]", text) is None:
            failures.append(f"value reference has no matching public {kind} declaration: {page}")
        if not index.is_file() or f"](values.md#{name.lower()})" not in index.read_text(encoding="utf-8"):
            failures.append(f"package index does not link cui.{subpackage}.{name}")

    for page in api_root.rglob("values.md"):
        subpackage = ".".join(page.parent.relative_to(api_root).parts)
        for name in re.findall(r"(?m)^###\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", page.read_text(encoding="utf-8")):
            if (subpackage, name) not in values:
                failures.append(f"stale API value without a public declaration: cui.{subpackage}.{name}")

    documented_types = {
        (".".join(page.parent.relative_to(api_root).parts), page.stem)
        for page in api_root.rglob("*.md")
        if page.parent != api_root and page.name not in SPECIAL_PAGES
    }
    for subpackage, name in sorted(documented_types - types):
        failures.append(f"stale API page without a public type: {subpackage}/{name}.md")

    if umbrella_source.is_file() and umbrella_doc.is_file():
        source_text = umbrella_source.read_text(encoding="utf-8")
        doc_text = umbrella_doc.read_text(encoding="utf-8")
        for match in CUI_IMPORT.finditer(source_text):
            subpackage, name = match.groups()
            package_path = subpackage.replace(".", "/")
            type_target = f"]({package_path}/{name}.md)"
            function_target = f"]({package_path}/functions.md#{name.lower()})"
            value_target = f"]({package_path}/values.md#{name.lower()})"
            if all(target not in doc_text for target in [type_target, function_target, value_target]):
                failures.append(
                    f"cui umbrella reference omits re-export cui.{subpackage}.{name}"
                )

    return failures
