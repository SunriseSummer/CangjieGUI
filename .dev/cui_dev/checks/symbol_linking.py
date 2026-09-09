"""Verify each embedded icon's payload is isolated in the final static executable."""

import argparse
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from cui_dev.common.paths import REPOSITORY_ROOT, DEV_TARGET_ROOT
from cui_dev.common.process import run_command


@dataclass(frozen=True)
class Symbol:
    package: str
    constant: str
    artwork: bytes


def discover_symbols(source_root: Path) -> list[Symbol]:
    result = []
    for path in sorted(source_root.glob("*/source.cj")):
        source = path.read_text(encoding="utf-8")
        package = re.search(r"^package (cui\.symbols\.[a-z_]+)$", source, re.M)
        constants = re.findall(r"^public let (ICON_[A-Z_]+): IconSource\s*=", source, re.M)
        literals = [json.loads(value) for value in re.findall(r'"(?:[^"\\]|\\.)*"', source)]
        artwork = [value for value in literals if value.startswith(("<path ", "<rect ", "<circle "))]
        if package is None or len(constants) != 1 or len(artwork) != 1:
            raise ValueError(f"icon source must declare one package, typed public let and artwork literal: {path}")
        if constants[0] != "ICON_" + package[1].rsplit(".", 1)[1].upper():
            raise ValueError(f"icon constant must match its package name: {path}")
        if re.search(r"^(?:public )?import cui\.symbols", source, re.M):
            raise ValueError(f"icon package must not import other icons: {path}")
        if re.search(r"^public (?:func|var)\b", source, re.M):
            raise ValueError(f"icon package must expose only its immutable resource: {path}")
        result.append(Symbol(package[1], constants[0], artwork[0].encode("utf-8")))
    if not result:
        raise ValueError("no embedded icon sources found")
    for index, symbol in enumerate(result):
        if any(symbol.artwork in other.artwork for other in result[:index] + result[index + 1:]):
            raise ValueError(f"ambiguous artwork fingerprint: {symbol.package}")
    return result


def inspect_payloads(binary: bytes, symbols: list[Symbol], expected: set[str]) -> dict:
    present = {symbol.package for symbol in symbols if symbol.artwork in binary}
    return {
        "ok": present == expected,
        "expected": sorted(expected),
        "present": sorted(present),
        "missing": sorted(expected - present),
        "unexpected": sorted(present - expected),
        "bytes": len(binary),
        "sha256": hashlib.sha256(binary).hexdigest(),
    }


def probe_source(symbols: list[Symbol], umbrella: bool = False) -> str:
    imports = [f"import {symbol.package}.{symbol.constant}" for symbol in symbols]
    if umbrella:
        imports.append("import cui.*")
    else:
        # The empty case still imports the exact same rendering infrastructure as the icons.
        imports.append("import cui.media.IconRenderingMode")
    calls = [f"    println(match ({symbol.constant}.renderingMode) {{ "
             'case IconRenderingMode.Template => "Template"; case _ => "Original" })'
             for symbol in symbols]
    if umbrella:
        calls.append('    let _ = Theme.light()')
    return "package symbol_link_probe\n" + "\n".join(imports) + "\nmain(): Unit {\n" + \
        "\n".join(calls) + '\n    println("symbol-link-ok")\n}\n'


def runtime_environment(native: Path, system: str = sys.platform) -> dict[str, str]:
    environment = os.environ.copy()
    variable = "PATH" if system == "win32" else \
        "DYLD_LIBRARY_PATH" if system == "darwin" else "LD_LIBRARY_PATH"
    environment[variable] = str(native) + os.pathsep + environment.get(variable, "")
    return environment


def run_probe(label: str, chosen: list[Symbol], expected: set[str], symbols: list[Symbol],
              build: Path, out: Path, native: Path, timeout: int, umbrella: bool = False) -> dict:
    directory = out / label
    directory.mkdir(parents=True, exist_ok=True)
    source = directory / "main.cj"
    source.write_text(probe_source(chosen, umbrella), encoding="utf-8", newline="\n")
    binary = directory / ("probe.exe" if os.name == "nt" else "probe")
    # Cangjie statically links non-std packages by default. Do not use whole-archive or LTO flags.
    command = ["cjc", str(source), "-O2", "--import-path", str(build), "-o", str(binary)]
    for name in ["cui", "sdl"]:
        libraries = build / name
        command += ["-L", str(libraries)]
        command += ["-l" + path.name[3:-2] for path in sorted(libraries.glob("lib*.a"))]
    command += ["-L", str(native), "-lSDL3", "-lSDL3_ttf", "-lSDL3_image"]
    code, stdout, stderr, timed_out = run_command(command, REPOSITORY_ROOT, timeout)
    (directory / "build.log").write_text(stdout + stderr, encoding="utf-8", newline="\n")
    if code != 0 or timed_out:
        return {"case": label, "ok": False, "returncode": code, "log": str(directory / "build.log")}
    result = inspect_payloads(binary.read_bytes(), symbols, expected)
    run_code, run_stdout, run_stderr, run_timeout = run_command(
        [str(binary)], directory, timeout, env=runtime_environment(native))
    (directory / "run.log").write_text(run_stdout + run_stderr, encoding="utf-8", newline="\n")
    result["runtime_ok"] = run_code == 0 and not run_timeout and "symbol-link-ok" in run_stdout
    result["ok"] = result["ok"] and result["runtime_ok"]
    result["runtime_returncode"] = run_code
    result.update(case=label, command=command)
    return result


def readonly_probe(symbol: Symbol, build: Path, out: Path, timeout: int) -> dict:
    directory = out / "readonly"
    directory.mkdir(parents=True, exist_ok=True)
    source = directory / "main.cj"
    source.write_text(
        f"package symbol_readonly_probe\nimport {symbol.package}.{symbol.constant}\n"
        f"main(): Unit {{ {symbol.constant} = {symbol.constant} }}\n",
        encoding="utf-8", newline="\n")
    binary = directory / ("probe.exe" if os.name == "nt" else "probe")
    command = ["cjc", str(source), "--import-path", str(build), "-o", str(binary)]
    code, stdout, stderr, timed_out = run_command(command, REPOSITORY_ROOT, timeout)
    diagnostics = stdout + stderr
    (directory / "build.log").write_text(diagnostics, encoding="utf-8", newline="\n")
    ok = code != 0 and not timed_out and "cannot assign to immutable value" in diagnostics \
        and symbol.constant in diagnostics
    return {"ok": ok, "returncode": code, "command": command}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args(argv)
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    symbols = discover_symbols(REPOSITORY_ROOT / "src" / "symbols")
    out = DEV_TARGET_ROOT / "symbol-linking"
    out.mkdir(parents=True, exist_ok=True)
    # Own the build directory: concurrent ordinary builds/tests may replace archives in target/release.
    build_root = out / "framework"
    code, stdout, stderr, timed_out = run_command(
        ["cjpm", "build", "--target-dir", str(build_root)], REPOSITORY_ROOT, 600)
    (out / "framework-build.log").write_text(stdout + stderr, encoding="utf-8", newline="\n")
    if code or timed_out:
        raise RuntimeError(f"framework build failed; see {out / 'framework-build.log'}")
    build = build_root / "release"
    native = REPOSITORY_ROOT.parent / "CangjieSDL" / ".sdl3"
    cases = [("none", [], set())]
    cases += [(symbol.package.rsplit(".", 1)[1], [symbol], {symbol.package}) for symbol in symbols]
    cases += [("all", symbols, {symbol.package for symbol in symbols})]
    cases += [("umbrella", [], {"cui.symbols.calendar", "cui.symbols.clock"})]
    results = []
    for label, chosen, expected in cases:
        result = run_probe(label, chosen, expected, symbols, build, out, native, args.timeout,
                           umbrella=label == "umbrella")
        results.append(result)
        print(f"[{'OK' if result['ok'] else 'FAIL'}] {label}: {result.get('bytes', 0)} bytes", flush=True)
    readonly = readonly_probe(next(symbol for symbol in symbols if symbol.constant == "ICON_CLOCK"),
                              build, out, args.timeout)
    print(f"[{'OK' if readonly['ok'] else 'FAIL'}] public let rejects reassignment", flush=True)
    version_code, version, version_error, _ = run_command(["cjc", "-v"], REPOSITORY_ROOT, 30)
    if version_code:
        raise RuntimeError(f"cannot record compiler version: {version_error}")
    report = {"symbols": len(symbols), "compiler": version.strip(), "cases": results,
              "readonly": readonly, "ok": all(result["ok"] for result in results) and readonly["ok"]}
    (out / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8", newline="\n")
    print(f"Report: {out / 'report.json'}")
    return 0 if report["ok"] else 1
