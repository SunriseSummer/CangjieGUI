"""Fingerprint effective Git worktrees, including uncommitted and untracked source files."""

import hashlib
import tomllib
from pathlib import Path

from cui_dev.common.process import run_command


def validate_source_pair(root, fixture, sdl):
    for owner, dependency, expected in ((root, "sdl", sdl), (fixture, "cui", root)):
        with (owner / "cjpm.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        declaration = manifest.get("dependencies", {}).get(dependency, {})
        path = declaration.get("path") if isinstance(declaration, dict) else None
        if not isinstance(path, str) or (owner / path).resolve() != expected.resolve():
            raise ValueError(f"release provenance requires {owner.name} to use local {dependency} at {expected}")


def fingerprint_files(root, names):
    records = []
    combined = hashlib.sha256()
    for name in sorted(set(names)):
        path = root / name
        if not path.exists():  # tracked deletion: absence is part of the effective tree
            continue
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"source provenance requires a regular file: {name}")
        content = path.read_bytes()
        digest = hashlib.sha256(content).hexdigest()
        combined.update(name.encode("utf-8") + b"\0" + digest.encode("ascii") + b"\n")
        records.append({"path": name, "bytes": len(content), "sha256": digest})
    return {"sha256": combined.hexdigest(), "files": records}


def worktree_provenance(root):
    root = Path(root).resolve()

    def git(*arguments):
        code, out, error, timed_out = run_command(["git", *arguments], root, 30)
        if code or timed_out:
            raise ValueError(f"cannot record {root.name} provenance: {error.strip()}")
        return out

    names = git("ls-files", "--cached", "--others", "--exclude-standard", "-z").split("\0")
    result = fingerprint_files(root, [name for name in names if name])
    result.update({"repository": root.name, "head": git("rev-parse", "HEAD").strip(),
                   "dirty": bool(git("status", "--porcelain")),
                   "scope": "tracked and non-ignored untracked files; deleted tracked files omitted"})
    return result
