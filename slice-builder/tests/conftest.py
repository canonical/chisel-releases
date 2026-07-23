"""Shared pytest fixtures and markers."""

import shutil

import pytest


def pytest_configure(config):
    config.addinivalue_line("markers", "slow: requires omp + LLM credentials")


def has_omp() -> bool:
    return shutil.which("omp") is not None


def has_llm_credentials() -> bool:
    import os

    # omp reads keys from env; treat any common API-key env var as "credentials present".
    return any(
        os.environ.get(k)
        for k in ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY")
    )


@pytest.fixture
def tmp_checkout(tmp_path):
    """A bare chisel-releases checkout skeleton with a chisel.yaml."""

    (tmp_path / "chisel.yaml").write_text(
        "format: v3\n"
        "archives:\n  ubuntu:\n    default: true\n    version: 26.04\n"
        "    components: [main]\n    suites: [noble]\n"
        "    public-keys: [k]\n"
        "stores:\n  bin:\n    kind: bin\n    version: 26.04\n    default-prefix: 'bin-'\n",
        encoding="utf-8",
    )
    (tmp_path / "slices").mkdir()
    (tmp_path / "bin-slices").mkdir()
    return tmp_path
