"""Build the real Flutter UI, not the unused React scaffold."""

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
subprocess.run([
    sys.executable, str(ROOT / "scripts" / "pwa" / "build.py"),
    "--base-href", "/", "--output", str(HERE / "dist" / "public"),
], check=True)
