"""Deterministic artifact I/O helpers."""

def write_text_lf(path, text):
    """Write deterministic UTF-8/LF artifacts on every host, including checked-in baselines."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(text)
