#!/usr/bin/env python3
"""Fetch and safely unpack the pinned Cangjie/SDL cross-platform toolchain inputs."""

import argparse
import hashlib
import inspect
import json
import os
import platform
import shutil
import stat
import sys
import tarfile
import tempfile
import urllib.request
import urllib.error
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = Path(__file__).resolve().with_name("cross_platform_artifacts.json")
DEFAULT_CACHE = ROOT / "target" / "toolchains" / "downloads"
DEFAULT_OUTPUT = ROOT / "target" / "toolchains"
DEFAULT_REPORTS = ROOT / "target" / "cross-platform"
COMPONENT_KEYS = {"cangjie": "cangjie", "sdl": "sdl", "sdl_ttf": "sdlTtf"}
SUPPORTED_PROFILES = {
    "windows-x86_64", "linux-x86_64", "linux-arm64", "macos-arm64",
}


class BootstrapError(RuntimeError):
    pass


def utc_timestamp():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def current_profile(system=None, machine=None):
    system = (system or platform.system()).strip().lower()
    machine = (machine or platform.machine()).strip().lower()
    systems = {"windows": "windows", "linux": "linux", "darwin": "macos"}
    architectures = {
        "amd64": "x86_64", "x86_64": "x86_64", "x64": "x86_64",
        "arm64": "arm64", "aarch64": "arm64",
    }
    if system not in systems or machine not in architectures:
        raise BootstrapError(f"unsupported host platform: {system or '<empty>'}-{machine or '<empty>'}")
    profile = f"{systems[system]}-{architectures[machine]}"
    if profile not in SUPPORTED_PROFILES:
        raise BootstrapError(f"unsupported toolchain profile: {profile}")
    return profile


def validate_artifact(component, artifact):
    required = {"filename", "url", "sha256", "size"}
    missing = sorted(required - set(artifact))
    if missing:
        raise BootstrapError(f"{component} artifact is missing: {', '.join(missing)}")
    filename = artifact["filename"]
    if not isinstance(filename, str) or Path(filename).name != filename:
        raise BootstrapError(f"{component} filename must be a single path component")
    url = artifact["url"]
    if not isinstance(url, str) or not url.startswith("https://"):
        raise BootstrapError(f"{component} artifact URL must use HTTPS")
    digest = artifact["sha256"]
    if not isinstance(digest, str) or len(digest) != 64 or any(
            character not in "0123456789abcdef" for character in digest.lower()):
        raise BootstrapError(f"{component} SHA-256 must contain exactly 64 hexadecimal characters")
    if not isinstance(artifact["size"], int) or artifact["size"] <= 0:
        raise BootstrapError(f"{component} artifact size must be a positive integer")


def load_manifest(path=DEFAULT_MANIFEST):
    try:
        manifest = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise BootstrapError(f"cannot read artifact manifest {path}: {error}") from error
    if manifest.get("schemaVersion") != 1:
        raise BootstrapError("artifact manifest schemaVersion must be 1")
    for key in ("cangjie", "sdl", "sdlTtf"):
        if not isinstance(manifest.get(key), dict) or not manifest[key].get("version"):
            raise BootstrapError(f"artifact manifest is missing {key} version data")
    artifacts = manifest["cangjie"].get("artifacts")
    if not isinstance(artifacts, dict) or set(artifacts) != SUPPORTED_PROFILES:
        raise BootstrapError("Cangjie artifacts must exactly cover the supported profiles")
    for profile, artifact in artifacts.items():
        validate_artifact(f"cangjie/{profile}", artifact)
    validate_artifact("sdl", manifest["sdl"].get("artifact", {}))
    validate_artifact("sdl_ttf", manifest["sdlTtf"].get("artifact", {}))
    return manifest


def artifact_for(manifest, component, profile):
    if component == "cangjie":
        return manifest["cangjie"]["artifacts"][profile]
    return manifest[COMPONENT_KEYS[component]]["artifact"]


def verify_cached_artifact(path, artifact):
    actual_size = path.stat().st_size
    if actual_size != artifact["size"]:
        raise BootstrapError(
            f"cached artifact size mismatch for {path.name}: expected {artifact['size']}, got {actual_size}")
    actual_digest = sha256_file(path)
    if actual_digest.lower() != artifact["sha256"].lower():
        raise BootstrapError(
            f"cached artifact SHA-256 mismatch for {path.name}: "
            f"expected {artifact['sha256']}, got {actual_digest}")
    return actual_digest


def fetch_artifact(artifact, cache, opener=urllib.request.urlopen):
    cache.mkdir(parents=True, exist_ok=True)
    destination = cache / artifact["filename"]
    if destination.exists():
        verify_cached_artifact(destination, artifact)
        return destination, True

    temporary = cache / f".{artifact['filename']}.{os.getpid()}.part"
    if temporary.exists():
        raise BootstrapError(f"refusing to overwrite partial download: {temporary}")
    request = urllib.request.Request(
        artifact["url"], headers={"User-Agent": "CangjieGUI-cross-platform-bootstrap/1"})
    digest = hashlib.sha256()
    total = 0
    try:
        with opener(request, timeout=120) as response, temporary.open("xb") as stream:
            final_url = response.geturl()
            if not final_url.startswith("https://"):
                raise BootstrapError(f"artifact redirected to a non-HTTPS URL: {final_url}")
            for chunk in iter(lambda: response.read(1024 * 1024), b""):
                total += len(chunk)
                if total > artifact["size"]:
                    raise BootstrapError(
                        f"download exceeded pinned size for {artifact['filename']}")
                digest.update(chunk)
                stream.write(chunk)
        if total != artifact["size"]:
            raise BootstrapError(
                f"download size mismatch for {artifact['filename']}: expected {artifact['size']}, got {total}")
        actual_digest = digest.hexdigest()
        if actual_digest.lower() != artifact["sha256"].lower():
            raise BootstrapError(
                f"download SHA-256 mismatch for {artifact['filename']}: "
                f"expected {artifact['sha256']}, got {actual_digest}")
        temporary.replace(destination)
    except (OSError, urllib.error.URLError) as error:
        raise BootstrapError(f"cannot download {artifact['filename']}: {error}") from error
    finally:
        if temporary.exists():
            temporary.unlink()
    return destination, False


def safe_member_path(root, name, allow_parent=False):
    normalized = name.replace("\\", "/")
    member = PurePosixPath(normalized)
    if member.is_absolute() or (".." in member.parts and not allow_parent) or (
            member.parts and ":" in member.parts[0]):
        raise BootstrapError(f"archive member escapes extraction root: {name}")
    destination = (root / Path(*member.parts)).resolve()
    try:
        destination.relative_to(root.resolve())
    except ValueError as error:
        raise BootstrapError(f"archive member escapes extraction root: {name}") from error
    return destination


def extract_zip(archive, destination):
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            safe_member_path(destination, member.filename)
            mode = member.external_attr >> 16
            if stat.S_ISLNK(mode):
                raise BootstrapError(f"archive symbolic link is not allowed: {member.filename}")
        bundle.extractall(destination)


def extract_tar(archive, destination):
    with tarfile.open(archive, mode="r:gz") as bundle:
        for member in bundle.getmembers():
            safe_member_path(destination, member.name)
            if member.issym():
                link_parent = PurePosixPath(member.name.replace("\\", "/")).parent
                safe_member_path(
                    destination, str(link_parent / member.linkname), allow_parent=True)
            elif member.islnk():
                safe_member_path(destination, member.linkname, allow_parent=True)
            elif not (member.isdir() or member.isfile()):
                raise BootstrapError(f"unsupported tar member type: {member.name}")
        arguments = {"filter": "fully_trusted"} if "filter" in inspect.signature(
            bundle.extractall).parameters else {}
        bundle.extractall(destination, **arguments)


def extraction_marker(destination):
    return destination / ".cui-bootstrap.json"


def extract_artifact(archive, artifact, destination):
    marker = extraction_marker(destination)
    if destination.exists():
        if not marker.is_file():
            raise BootstrapError(f"existing extraction has no provenance marker: {destination}")
        try:
            provenance = json.loads(marker.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise BootstrapError(f"invalid extraction provenance at {marker}: {error}") from error
        if provenance.get("sha256") != artifact["sha256"]:
            raise BootstrapError(f"existing extraction does not match pinned artifact: {destination}")
        return True

    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=f".{destination.name}-", dir=destination.parent))
    try:
        if archive.name.lower().endswith(".zip"):
            extract_zip(archive, staging)
        elif archive.name.lower().endswith((".tar.gz", ".tgz")):
            extract_tar(archive, staging)
        else:
            raise BootstrapError(f"unsupported archive format: {archive.name}")
        with extraction_marker(staging).open("w", encoding="utf-8", newline="\n") as stream:
            stream.write(json.dumps({
                "filename": artifact["filename"],
                "sha256": artifact["sha256"],
                "size": artifact["size"],
            }, indent=2) + "\n")
        staging.replace(destination)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    return False


def exactly_one(candidates, description):
    candidates = sorted(set(path.resolve() for path in candidates))
    if len(candidates) != 1:
        rendered = ", ".join(str(path) for path in candidates) or "none"
        raise BootstrapError(f"expected one {description}, found {len(candidates)}: {rendered}")
    return candidates[0]


def locate_component_root(component, destination, profile):
    if component == "cangjie":
        setup_name = "envsetup.ps1" if profile.startswith("windows-") else "envsetup.sh"
        setups = [path for path in destination.rglob(setup_name)
                  if (path.parent / "runtime" / "lib").is_dir()
                  and any((path.parent / "bin" / compiler).is_file()
                          for compiler in ("cjc", "cjc.exe"))
                  and any((path.parent / "tools" / "bin" / manager).is_file()
                          for manager in ("cjpm", "cjpm.exe"))]
        setup = exactly_one(setups, f"SDK-root {setup_name}")
        return setup.parent, setup
    header = "SDL.h" if component == "sdl" else "SDL_ttf.h"
    namespace = "SDL3" if component == "sdl" else "SDL3_ttf"
    headers = destination.rglob(header)
    roots = [path.parent.parent.parent for path in headers if path.parent.name == namespace]
    return exactly_one(roots, f"{component} source root"), None


def sdk_runtime_directory(sdk_root, profile):
    names = {
        "windows-x86_64": "windows_x86_64_cjnative",
        "linux-x86_64": "linux_x86_64_cjnative",
        "linux-arm64": "linux_aarch64_cjnative",
        "macos-arm64": "darwin_aarch64_cjnative",
    }
    runtime = sdk_root / "runtime" / "lib" / names[profile]
    if not runtime.is_dir():
        raise BootstrapError(f"target SDK runtime directory is missing: {runtime}")
    return runtime.resolve()


def append_github_outputs(values, environment=None):
    environment = os.environ if environment is None else environment
    output = environment.get("GITHUB_OUTPUT")
    if not output:
        return
    with Path(output).open("a", encoding="utf-8", newline="\n") as stream:
        for key, value in values.items():
            if value is not None:
                text = str(value)
                if "\n" in text or "\r" in text:
                    raise BootstrapError(f"GitHub output {key} must be a single line")
                stream.write(f"{key}={text}\n")


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def bootstrap(profile, components, manifest_path, cache, output, download_only=False,
              opener=urllib.request.urlopen):
    if profile not in SUPPORTED_PROFILES:
        raise BootstrapError(f"unsupported toolchain profile: {profile}")
    manifest = load_manifest(manifest_path)
    component_results = {}
    output_root = output / profile
    for component in components:
        artifact = artifact_for(manifest, component, profile)
        archive, cache_hit = fetch_artifact(artifact, cache, opener=opener)
        result = {
            "version": manifest[COMPONENT_KEYS[component]]["version"],
            "archive": str(archive.resolve()),
            "sha256": artifact["sha256"],
            "size": artifact["size"],
            "cacheHit": cache_hit,
            "root": None,
            "envSetup": None,
            "runtimeDir": None,
        }
        if not download_only:
            destination = output_root / component
            extraction_hit = extract_artifact(archive, artifact, destination)
            root, setup = locate_component_root(component, destination, profile)
            result.update({
                "extractionHit": extraction_hit,
                "root": str(root),
                "envSetup": str(setup) if setup else None,
                "runtimeDir": str(sdk_runtime_directory(root, profile))
                if component == "cangjie" else None,
            })
        component_results[component] = result
    return {
        "schemaVersion": 1,
        "generatedAt": utc_timestamp(),
        "profile": profile,
        "manifest": str(Path(manifest_path).resolve()),
        "manifestSha256": sha256_file(Path(manifest_path)),
        "downloadOnly": download_only,
        "components": component_results,
    }


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=sorted(SUPPORTED_PROFILES), default=current_profile())
    parser.add_argument("--component", action="append", choices=sorted(COMPONENT_KEYS),
                        dest="components", help="component to prepare; repeatable, defaults to all")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--report", type=Path,
                        help="report path; defaults to target/cross-platform/bootstrap-<profile>.json")
    parser.add_argument("--download-only", action="store_true")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    components = tuple(dict.fromkeys(args.components or COMPONENT_KEYS))
    report_path = args.report or DEFAULT_REPORTS / f"bootstrap-{args.profile}.json"
    try:
        result = bootstrap(
            args.profile, components, args.manifest.resolve(), args.cache.resolve(),
            args.output.resolve(), download_only=args.download_only)
        write_json(report_path.resolve(), result)
        outputs = {"profile": args.profile, "report": report_path.resolve()}
        for component, component_result in result["components"].items():
            outputs[f"{component}_root"] = component_result["root"]
            outputs[f"{component}_env"] = component_result["envSetup"]
            outputs[f"{component}_runtime"] = component_result["runtimeDir"]
        append_github_outputs(outputs)
    except (BootstrapError, OSError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(f"Cross-platform bootstrap failed: {error}", file=sys.stderr)
        return 1
    print(f"Prepared {', '.join(components)} for {args.profile}; evidence: {report_path.resolve()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
