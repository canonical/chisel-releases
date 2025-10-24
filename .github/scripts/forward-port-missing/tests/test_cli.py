from __future__ import annotations

import subprocess as sub
import sys

import pytest
from conftest import __project_root__


def call(*args: str) -> tuple[str, int]:
    PYTHON = sys.executable
    cmd: list[str] = [PYTHON, str(__project_root__ / "src" / "chisel_releases_data.py"), *args]
    output = sub.run(cmd, check=False, capture_output=True, text=True)
    res = output.stdout.strip()
    code = output.returncode
    return res, code


def test_help() -> None:
    result, code = call("--help")
    assert code == 0
    assert "usage: chisel_releases_data.py" in result


def test_version() -> None:
    try:
        from chisel_releases_data import __version__
    except ImportError:
        pytest.fail("Could not import __version__ from chisel_releases_data", pytrace=False)
    result, code = call("--version")
    assert code == 0

    assert __version__ in result
