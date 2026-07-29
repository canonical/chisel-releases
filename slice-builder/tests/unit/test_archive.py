"""Unit tests for archive.py."""

import tarfile
from io import BytesIO

import pytest

from slice_builder.archive import extract_archive, extract_paths


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
    with pytest.raises(ValueError, match="archive not found"):
        extract_paths(tmp_path / "nope.tar.xz")


def test_extract_paths_bad_archive_raises(tmp_path):
    archive = tmp_path / "bad.tar.xz"
    archive.write_bytes(b"not a tar")
    with pytest.raises(ValueError, match="cannot read archive"):
        extract_paths(archive)


# --- extract_archive ---


def test_extract_archive_writes_files(tmp_path):
    archive = tmp_path / "bin.tar.xz"
    archive.write_bytes(
        _make_tarxz(
            {
                "usr/bin/curl": b"#!/bin/sh\n",
                "usr/share/doc/curl/copyright": b"copyright\n",
            }
        )
    )
    dest = tmp_path / "extracted"
    extract_archive(archive, dest)
    assert (dest / "usr/bin/curl").read_bytes() == b"#!/bin/sh\n"
    assert (dest / "usr/share/doc/curl/copyright").read_bytes() == b"copyright\n"


def test_extract_archive_missing_archive_raises(tmp_path):
    with pytest.raises(ValueError, match="archive not found"):
        extract_archive(tmp_path / "nope.tar.xz", tmp_path / "out")


def test_extract_archive_bad_archive_raises(tmp_path):
    archive = tmp_path / "bad.tar.xz"
    archive.write_bytes(b"not a tar")
    with pytest.raises(ValueError, match="cannot read archive"):
        extract_archive(archive, tmp_path / "out")


def test_extract_archive_rejects_absolute_member(tmp_path):
    archive = tmp_path / "evil.tar.xz"
    buf = BytesIO()
    with tarfile.open(fileobj=buf, mode="w:xz") as tar:
        info = tarfile.TarInfo(name="/etc/passwd")
        info.size = 1
        tar.addfile(info, BytesIO(b"x"))
    archive.write_bytes(buf.getvalue())
    with pytest.raises(ValueError, match="unsafe.*absolute"):
        extract_archive(archive, tmp_path / "out")


def test_extract_archive_rejects_traversal_member(tmp_path):
    archive = tmp_path / "evil.tar.xz"
    buf = BytesIO()
    with tarfile.open(fileobj=buf, mode="w:xz") as tar:
        info = tarfile.TarInfo(name="../escape")
        info.size = 1
        tar.addfile(info, BytesIO(b"x"))
    archive.write_bytes(buf.getvalue())
    with pytest.raises(ValueError, match="escapes destination"):
        extract_archive(archive, tmp_path / "out")
