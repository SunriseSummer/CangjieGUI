"""Source provenance and host environment capture."""

import ctypes
import hashlib
import json
import os
import platform
import subprocess
from ctypes import wintypes
from pathlib import Path

from bench.tooling.config import BENCHMARK_AFFINITY
from cui_dev.common.paths import REPOSITORY_ROOT

def git_commit() -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(REPOSITORY_ROOT), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True,
        )
        return out.stdout.strip() or "(no git)"
    except Exception:
        return "(no git)"


def source_fingerprint(repository: Path, include):
    """Hash every performance-relevant tracked or untracked source file in a repository."""
    try:
        completed = subprocess.run(
            ["git", "-C", str(repository), "ls-files", "-co", "--exclude-standard", "-z"],
            capture_output=True,
        )
        if completed.returncode != 0:
            raise RuntimeError("git ls-files failed")
        paths = sorted(path for raw in completed.stdout.split(b"\0") if raw
                       for path in [raw.decode("utf-8", errors="surrogateescape")]
                       if include(path.replace("\\", "/")))
        digest = hashlib.sha256()
        for relative in paths:
            normalized = relative.replace("\\", "/")
            digest.update(normalized.encode("utf-8", errors="surrogateescape"))
            digest.update(b"\0")
            path = repository / relative
            if path.is_file():
                digest.update(path.read_bytes())
            digest.update(b"\0")
        status = subprocess.run(
            ["git", "-C", str(repository), "status", "--porcelain=v1", "--untracked-files=all"],
            capture_output=True,
        ).stdout.decode("utf-8", errors="replace").splitlines()
        dirty = any(include(line[3:].replace("\\", "/").split(" -> ")[-1])
                    for line in status if len(line) > 3)
        commit = subprocess.run(
            ["git", "-C", str(repository), "rev-parse", "HEAD"], capture_output=True, text=True,
        ).stdout.strip()
        return {"commit": commit or "unknown", "sourceDigest": digest.hexdigest(), "dirty": dirty,
                "fileCount": len(paths)}
    except Exception as exc:
        return {"commit": "unknown", "sourceDigest": "unavailable", "dirty": True,
                "fileCount": 0, "error": str(exc)}


def source_context():
    gui = REPOSITORY_ROOT
    sdl = gui.parent / "CangjieSDL"

    def gui_include(path):
        if path == "cjpm.toml" or path.startswith("src/"):
            return True
        if path in {
                ".dev/cli.py",
                ".dev/cui_dev/common/paths.py",
                ".dev/cui_dev/common/process.py"}:
            return True
        return path.startswith(".dev/bench/") and \
            Path(path).suffix.lower() in (".py", ".cj", ".toml", ".html")

    sdl_include = lambda path: path == "cjpm.toml" or path.startswith("src/")
    return {
        "cangjieGui": source_fingerprint(gui, gui_include),
        "cangjieSdl": source_fingerprint(sdl, sdl_include),
    }


def windows_power_environment():
    if os.name != "nt":
        return {"powerSource": "unknown", "powerScheme": "unknown",
                "effectivePowerOverlay": "unknown"}

    class SystemPowerStatus(ctypes.Structure):
        _fields_ = [
            ("acLineStatus", ctypes.c_ubyte),
            ("batteryFlag", ctypes.c_ubyte),
            ("batteryLifePercent", ctypes.c_ubyte),
            ("systemStatusFlag", ctypes.c_ubyte),
            ("batteryLifeTime", ctypes.c_ulong),
            ("batteryFullLifeTime", ctypes.c_ulong),
        ]

    status = SystemPowerStatus()
    source = "unknown"
    if ctypes.windll.kernel32.GetSystemPowerStatus(ctypes.byref(status)):
        source = {0: "battery", 1: "ac"}.get(status.acLineStatus, "unknown")

    scheme = "unknown"
    overlay_ac = "unknown"
    overlay_dc = "unknown"
    try:
        import winreg
        key_path = r"SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes"
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
            scheme = str(winreg.QueryValueEx(key, "ActivePowerScheme")[0]).lower()
            overlay_ac = str(winreg.QueryValueEx(key, "ActiveOverlayAcPowerScheme")[0]).lower()
            overlay_dc = str(winreg.QueryValueEx(key, "ActiveOverlayDcPowerScheme")[0]).lower()
    except OSError:
        pass
    effective = overlay_dc if source == "battery" else overlay_ac if source == "ac" else "unknown"
    return {"powerSource": source, "powerScheme": scheme, "effectivePowerOverlay": effective,
            "acPowerOverlay": overlay_ac, "dcPowerOverlay": overlay_dc}


def linux_power_environment(power_root=Path("/sys/class/power_supply")):
    """Read kernel power-supply state without assuming a particular adapter or battery name."""
    if not power_root.is_dir():
        return {"powerSource": "unknown", "powerScheme": "unknown",
                "effectivePowerOverlay": "unknown"}
    adapters_online = False
    battery_discharging = False
    battery_on_ac = False
    try:
        for supply in power_root.iterdir():
            supply_type = (supply / "type").read_text(encoding="utf-8").strip().lower()
            if supply_type == "battery":
                status_path = supply / "status"
                status = status_path.read_text(encoding="utf-8").strip().lower() \
                    if status_path.is_file() else "unknown"
                battery_discharging = battery_discharging or status == "discharging"
                battery_on_ac = battery_on_ac or status in ("charging", "full", "not charging")
            elif supply_type in ("mains", "usb", "usb_c"):
                online_path = supply / "online"
                adapters_online = adapters_online or (
                    online_path.is_file() and online_path.read_text(encoding="utf-8").strip() == "1")
    except OSError:
        return {"powerSource": "unknown", "powerScheme": "unknown",
                "effectivePowerOverlay": "unknown"}
    source = "ac" if adapters_online or battery_on_ac \
        else "battery" if battery_discharging else "unknown"
    return {"powerSource": source, "powerScheme": "unknown", "effectivePowerOverlay": "unknown"}


def parse_macos_power_source(output):
    lowered = output.lower()
    if "ac power" in lowered:
        return "ac"
    if "battery power" in lowered:
        return "battery"
    return "unknown"


def macos_power_environment():
    try:
        completed = subprocess.run(["pmset", "-g", "batt"], capture_output=True, text=True, timeout=10)
        source = parse_macos_power_source(completed.stdout + completed.stderr) \
            if completed.returncode == 0 else "unknown"
    except (OSError, subprocess.TimeoutExpired):
        source = "unknown"
    return {"powerSource": source, "powerScheme": "unknown", "effectivePowerOverlay": "unknown"}


def power_environment():
    system = platform.system()
    if system == "Windows":
        return windows_power_environment()
    if system == "Linux":
        return linux_power_environment()
    if system == "Darwin":
        return macos_power_environment()
    return {"powerSource": "unknown", "powerScheme": "unknown", "effectivePowerOverlay": "unknown"}


def windows_video_environment():
    if os.name != "nt":
        return []
    command = (
        "$items=@(Get-CimInstance Win32_VideoController | "
        "Select-Object Name,DriverVersion,CurrentRefreshRate);"
        "$items | ConvertTo-Json -Compress"
    )
    try:
        completed = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", command],
            capture_output=True, text=True, timeout=15,
        )
        if completed.returncode != 0 or not completed.stdout.strip():
            return []
        value = json.loads(completed.stdout)
        items = value if isinstance(value, list) else [value]
        return sorted(items, key=lambda item: str(item.get("Name", "")))
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return []


def toolchain() -> str:
    try:
        out = subprocess.run(["cjc", "--version"], capture_output=True, text=True)
        line = (out.stdout or out.stderr).splitlines()
        return line[0].strip() if line else "-"
    except Exception:
        return "-"

def host_environment():
    result = {
        "system": platform.system(),
        "platform": platform.platform(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "logicalCpuCount": os.cpu_count(),
        "python": platform.python_version(),
    }
    result.update(power_environment())
    result["videoControllers"] = windows_video_environment()
    result["benchmarkAffinity"] = BENCHMARK_AFFINITY
    return result
