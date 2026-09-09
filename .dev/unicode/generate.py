"""Regenerate shared SDL Unicode data and synchronize the GUI conformance fixture."""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
sdk = root.parent / 'CangjieSDL'
result = subprocess.run([sys.executable, str(sdk / '.dev/unicode/generate.py'), *sys.argv[1:]], check=False)
if result.returncode == 0:
    for name in ['GraphemeBreakTest.txt', 'sources.json', 'LICENSE.txt']:
        shutil.copy2(sdk / '.dev/unicode' / name, root / '.dev/unicode' / name)
sys.exit(result.returncode)
