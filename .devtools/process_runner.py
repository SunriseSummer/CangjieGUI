"""Cross-platform subprocess capture with process-tree timeout cleanup."""

import os
import locale
import signal
import subprocess


def terminate_process_tree(proc):
    """Terminate an exact timed-out process group, including compiler/window descendants."""
    try:
        if os.name == "nt":
            killed = subprocess.run(
                ["taskkill", "/PID", str(proc.pid), "/T", "/F"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=10,
            )
            if killed.returncode != 0:
                proc.kill()
        else:
            os.killpg(proc.pid, signal.SIGKILL)
    except (OSError, subprocess.SubprocessError):
        # The process may have exited between the timeout and termination request.
        try:
            proc.kill()
        except OSError:
            pass


def decode_process_output(data, fallback_encoding=None):
    """Decode child output losslessly across UTF-8 and the Windows ANSI console code page."""
    if not data:
        return ""
    if isinstance(data, str):
        return data
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        fallback = fallback_encoding or locale.getpreferredencoding(False)
        if fallback.lower().replace("_", "-") not in {"utf-8", "utf8"}:
            try:
                return data.decode(fallback)
            except (LookupError, UnicodeDecodeError):
                pass
        return data.decode("utf-8", errors="replace")


def run_command(command, cwd, timeout, env=None):
    """Return (code, stdout, stderr, timed_out) with lossless cross-platform text capture."""
    kwargs = {
        "cwd": cwd,
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE,
    }
    if env is not None:
        kwargs["env"] = env
    if os.name == "nt":
        kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["start_new_session"] = True
    try:
        proc = subprocess.Popen(command, **kwargs)
    except OSError as exc:
        return 127, "", str(exc), False
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
        return proc.returncode, decode_process_output(stdout), decode_process_output(stderr), False
    except subprocess.TimeoutExpired:
        terminate_process_tree(proc)
        stdout, stderr = proc.communicate()
        return 124, decode_process_output(stdout), decode_process_output(stderr), True
