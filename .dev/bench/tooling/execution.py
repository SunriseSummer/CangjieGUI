"""Benchmark process isolation, affinity, and package execution."""

import ctypes
import os
import struct
import sys
import time
from ctypes import wintypes
from pathlib import Path

from bench.tooling.config import (
    BASELINE_CANDIDATE,
    BASELINE_CANDIDATE_META,
    BUILT_WINDOWS_PACKAGES,
    CLEANED_BENCHMARK_PACKAGES,
    LAST_WINDOWS_BENCHMARK_END,
    WINDOWS_BENCHMARK_COOLDOWN_SECONDS,
)
from cui_dev.common.paths import REPOSITORY_ROOT, benchmark_build_root
from cui_dev.common.process import run_command

def baseline_capture_destination(save_alias, explicit_candidate):
    """Resolve every capture spelling to staging; active baselines only change by promotion."""
    if not (save_alias or explicit_candidate):
        return None
    return "candidate", BASELINE_CANDIDATE, BASELINE_CANDIDATE_META


def select_performance_affinity(cpu_sets):
    """Return a group-0 mask for the highest Windows CPU efficiency class, or None if uniform."""
    available = [item for item in cpu_sets if item.get("group") == 0]
    classes = {item.get("efficiencyClass") for item in available}
    if len(classes) <= 1:
        return None
    fastest = max(classes)
    mask = 0
    for item in available:
        if item.get("efficiencyClass") == fastest:
            mask |= 1 << int(item["logicalProcessorIndex"])
    return mask or None


def windows_cpu_sets():
    """Read logical CPU efficiency classes without optional packages; unavailable APIs yield []."""
    if os.name != "nt":
        return []
    try:
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        query = kernel32.GetSystemCpuSetInformation
        query.argtypes = [ctypes.c_void_p, wintypes.ULONG, ctypes.POINTER(wintypes.ULONG),
                          wintypes.HANDLE, wintypes.ULONG]
        query.restype = wintypes.BOOL
        required = wintypes.ULONG()
        process = kernel32.GetCurrentProcess()
        query(None, 0, ctypes.byref(required), process, 0)
        if required.value == 0:
            return []
        buffer = ctypes.create_string_buffer(required.value)
        if not query(buffer, required.value, ctypes.byref(required), process, 0):
            return []
        result = []
        offset = 0
        while offset < required.value:
            size, info_type = struct.unpack_from("<II", buffer, offset)
            if size <= 0 or offset + size > required.value:
                return []
            if info_type == 0 and size >= 20:
                group = struct.unpack_from("<H", buffer, offset + 12)[0]
                logical, _, _, _, efficiency, flags = struct.unpack_from("<BBBBBB", buffer, offset + 14)
                result.append({
                    "group": group,
                    "logicalProcessorIndex": logical,
                    "efficiencyClass": efficiency,
                    "parked": bool(flags & 1),
                })
            offset += size
        return result
    except (AttributeError, OSError, ValueError, struct.error):
        return []


def apply_benchmark_affinity():
    """Pin hybrid Windows captures to the fastest CPU class so child processes share one domain."""
    if os.name != "nt":
        return {"policy": "os-default"}
    cpu_sets = windows_cpu_sets()
    mask = select_performance_affinity(cpu_sets)
    if mask is None:
        return {"policy": "windows-uniform", "cpuSetCount": len(cpu_sets)}
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    get_current_process = kernel32.GetCurrentProcess
    get_current_process.argtypes = []
    get_current_process.restype = wintypes.HANDLE
    get_affinity = kernel32.GetProcessAffinityMask
    get_affinity.argtypes = [wintypes.HANDLE, ctypes.POINTER(ctypes.c_size_t),
                             ctypes.POINTER(ctypes.c_size_t)]
    get_affinity.restype = wintypes.BOOL
    set_affinity = kernel32.SetProcessAffinityMask
    set_affinity.argtypes = [wintypes.HANDLE, ctypes.c_size_t]
    set_affinity.restype = wintypes.BOOL
    process = get_current_process()
    process_mask = ctypes.c_size_t()
    system_mask = ctypes.c_size_t()
    if not get_affinity(process, ctypes.byref(process_mask), ctypes.byref(system_mask)):
        raise RuntimeError(f"GetProcessAffinityMask failed: {ctypes.get_last_error()}")
    selected = mask & process_mask.value
    if selected == 0 or not set_affinity(process, ctypes.c_size_t(selected)):
        raise RuntimeError(f"SetProcessAffinityMask failed: {ctypes.get_last_error()}")
    selected_sets = [item for item in cpu_sets
                     if item["group"] == 0 and selected & (1 << item["logicalProcessorIndex"])]
    return {
        "policy": "windows-highest-efficiency-class",
        "mask": f"0x{selected:X}",
        "logicalProcessors": [item["logicalProcessorIndex"] for item in selected_sets],
        "efficiencyClass": max(item["efficiencyClass"] for item in selected_sets),
    }


def cjpm_command(action, run_args=None):
    command = ["cjpm", action]
    if run_args:
        command.extend(["--run-args", run_args])
    return command


def ensure_fresh_benchmark_package(pkg_dir: Path, timeout: int):
    """Clean one package once so coverage/profile caches cannot masquerade as benchmark binaries."""
    package_key = str(pkg_dir.resolve())
    if package_key in CLEANED_BENCHMARK_PACKAGES:
        return
    code, stdout, stderr, timed_out = run_command(cjpm_command("clean"), pkg_dir, timeout)
    if code != 0:
        suffix = f"; timed out after {timeout}s" if timed_out else ""
        raise RuntimeError(f"cjpm clean failed in {pkg_dir} (exit {code}{suffix})\n{stdout}{stderr}")
    CLEANED_BENCHMARK_PACKAGES.add(package_key)


def run_cjpm(pkg_dir: Path, action: str = "run", timeout: int = 600, run_args=None) -> list:
    """Run `cjpm <action>` in pkg_dir and return its stdout as a list of lines."""
    global LAST_WINDOWS_BENCHMARK_END
    if action == "run":
        ensure_fresh_benchmark_package(pkg_dir, timeout)
    if action == "run" and os.name == "nt":
        # On Windows an optimized benchmark can emit its complete machine log in under two seconds.
        # `cjpm run` intermittently stalls while forwarding that fast child output into another
        # captured process, even though the same executable is stable when launched directly. Build
        # first, then bypass only cjpm's forwarding layer; the benchmark process itself keeps the
        # shared timeout/process-tree capture and the SDL runtime directory is explicit.
        package_key = str(pkg_dir.resolve())
        if package_key not in BUILT_WINDOWS_PACKAGES:
            build_code, build_stdout, build_stderr, build_timed_out = run_command(
                cjpm_command("build"), pkg_dir, timeout)
            if build_code != 0:
                suffix = f"; timed out after {timeout}s" if build_timed_out else ""
                raise RuntimeError(
                    f"cjpm build failed in {pkg_dir} (exit {build_code}{suffix})\n{build_stdout}{build_stderr}")
            BUILT_WINDOWS_PACKAGES.add(package_key)
        executable = benchmark_build_root(pkg_dir) / "release" / "bin" / "main.exe"
        if not executable.is_file():
            raise RuntimeError(f"built benchmark executable is missing: {executable}")
        environment = os.environ.copy()
        sdl_runtime = REPOSITORY_ROOT.parent / "CangjieSDL" / ".sdl3"
        environment["PATH"] = str(sdl_runtime) + os.pathsep + environment.get("PATH", "")
        command = [str(executable)]
        if run_args:
            command.extend(run_args.split())
        if LAST_WINDOWS_BENCHMARK_END is None:
            time.sleep(WINDOWS_BENCHMARK_COOLDOWN_SECONDS)
        else:
            remaining = WINDOWS_BENCHMARK_COOLDOWN_SECONDS - (time.monotonic() - LAST_WINDOWS_BENCHMARK_END)
            if remaining > 0.0:
                time.sleep(remaining)
        # CREATE_NEW_PROCESS_GROUP intermittently stalls optimized Cangjie executables on Windows.
        # taskkill /PID /T still provides exact timeout tree cleanup without that creation flag.
        returncode, stdout, stderr, timed_out = run_command(
            command, pkg_dir, timeout, env=environment, new_process_group=False)
        LAST_WINDOWS_BENCHMARK_END = time.monotonic()
    else:
        returncode, stdout, stderr, timed_out = run_command(cjpm_command(action, run_args), pkg_dir, timeout)
    if returncode != 0:
        sys.stderr.write(stdout)
        sys.stderr.write(stderr)
        suffix = f"; timed out after {timeout}s" if timed_out else ""
        raise RuntimeError(f"cjpm {action} failed in {pkg_dir} (exit {returncode}{suffix})")
    return stdout.splitlines()
