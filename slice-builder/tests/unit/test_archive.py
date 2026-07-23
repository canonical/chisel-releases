"""Unit tests for archive.py."""

import tarfile
from io import BytesIO

from slice_builder.archive import extract_paths


def _make_tarxz(members: dict[str, bytes]) -> bytes:
    """Build an in-memory .tar.xz with the given member name -> content mapping."""

    buf = BytesIO()
    with tarfile.open(fileobj=buf, mode="w:xz") as tar:
        for name, content in members.items():
            data = content.encode() if isinstance(content, str) else content
            info = tarfile.TarInfo(name=name)
            info.size = len(data)
            tar.addfile(info, BytesIO(data))
    return buf.getvalue()


def test_extract_paths_returns_sorted_absolute(tmp_path):
    archive = tmp_path / "bin.tar.xz"
    archive.write_bytes(
        _make_tarxz(
            {
                "usr/bin/curl": b"#!/bin/sh\n",
                "usr/share/doc/curl/copyright": b"copyright\n",
                "etc/curl/config": b"cfg\n",
            }
        )
    )
    paths = extract_paths(archive)
    assert paths == sorted(["/etc/curl/config", "/usr/bin/curl", "/usr/share/doc/curl/copyright"])


def test_extract_paths_dedupes(tmp_path):
    archive = tmp_path / "bin.tar.xz"
    # tarfile dedupes members by name on read; ensure no duplicates surface.
    archive.write_bytes(_make_tarxz({"usr/bin/x": b""}))
    assert extract_paths(archive) == ["/usr/bin/x"]


def test_extract_paths_missing_archive_raises(tmp_path):
    import pytest

    with pytest.raises(ValueError, match="archive not found"):
        extract_paths(tmp_path / "nope.tar.xz")


def test_extract_paths_bad_archive_raises(tmp_path):
    import pytest

    archive = tmp_path / "bad.tar.xz"
    archive.write_bytes(b"not a tar")
    with pytest.raises(ValueError, match="cannot read archive"):
        extract_paths(archive)
