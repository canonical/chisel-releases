"""Integration tests for the full generate-sdf pipeline.

Gated behind @slow: require omp on PATH and LLM credentials. These hit the network (git clone)
and a real LLM, so they are skipped by default.
"""

import tarfile
from io import BytesIO

import pytest

from slice_builder.cli import main
from tests.conftest import has_llm_credentials, has_omp

slow = pytest.mark.skipif(
    not (has_omp() and has_llm_credentials()),
    reason="requires omp on PATH and LLM credentials",
)


def _make_bin_archive(path, members):
    buf = BytesIO()
    with tarfile.open(fileobj=buf, mode="w:xz") as tar:
        for name, content in members.items():
            data = content.encode()
            info = tarfile.TarInfo(name=name)
            info.size = len(data)
            tar.addfile(info, BytesIO(data))
    path.write_bytes(buf.getvalue())


@slow
@pytest.mark.slow
def test_generate_sdf_end_to_end(tmp_path):
    archive = tmp_path / "curl.tar.xz"
    _make_bin_archive(
        archive,
        {
            "usr/bin/curl-bin": "#!/bin/sh\n",
            "usr/share/doc/curl-bin/copyright": "copyright\n",
        },
    )
    output = tmp_path / "out" / "curl.yaml"
    rc = main(
        [
            "generate-sdf",
            "--bin-archive",
            str(archive),
            "--base",
            "26.04",
            "--package",
            "curl",
            "--track",
            "0.1",
            "--dependencies",
            "",
            "--sdf-lookup-dir",
            str(tmp_path / "lookup"),
            "--output",
            str(output),
        ]
    )
    assert rc == 0
    assert output.is_file()
    text = output.read_text()
    assert "package: curl" in text
    assert "store: bin" in text
    assert 'default-track: "0.1"' in text
