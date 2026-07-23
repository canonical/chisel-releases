"""Shallow-clone a chisel-releases `ubuntu-<base>` branch to a temp directory."""

from __future__ import annotations

import subprocess
from pathlib import Path

REMOTE = "https://github.com/canonical/chisel-releases.git"


def branch_for_base(base: str) -> str:
    """Return the chisel-releases branch name for an Ubuntu base (e.g. ``26.04``)."""

    return f"ubuntu-{base}"


def shallow_clone(base: str, dest: str | Path) -> Path:
    """Shallow-clone the `ubuntu-<base>` branch into ``dest`` and return the path.

    Raises ``RuntimeError`` on git failure.
    """

    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    branch = branch_for_base(base)
    cmd = [
        "git",
        "clone",
        "--depth",
        "1",
        "--branch",
        branch,
        REMOTE,
        str(dest),
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(
            f"git clone failed (exit {exc.returncode}): {exc.stderr.strip()}"
        ) from exc
    return dest
