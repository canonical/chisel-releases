"""Extract a `.tar.xz` bin archive to a directory and enumerate its paths.

The agent needs access to the actual extracted files (not just their names) to classify paths
correctly — file type (shared lib vs data), symlinks, and occasionally file content (e.g. a
copyright file) inform slice grouping. The builder extracts the archive to a directory and hands
that directory to the agent.
"""

from __future__ import annotations

import os
import tarfile
from pathlib import Path


def extract_archive(archive: str | Path, dest: str | Path) -> Path:
    """Safely extract a `.tar.xz` archive into ``dest`` and return the destination path.

    Extraction is guarded against path traversal (members resolving outside ``dest``) and
    absolute member paths, which are unsafe in a tar. Member paths are extracted as-is (relative
    to ``dest``); the leading-slash normalisation used for Chisel content paths is applied only
    by :func:`extract_paths` for display.

    Raises ``ValueError`` if the archive cannot be opened, is missing, or contains an unsafe
    member path.
    """

    archive = Path(archive)
    if not archive.is_file():
        raise ValueError(f"archive not found: {archive}")

    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    dest_resolved = dest.resolve()

    try:
        with tarfile.open(archive, "r:xz") as tar:
            for member in tar.getmembers():
                _ensure_safe_member(member, dest_resolved)
            tar.extractall(dest, filter="data")
    except (tarfile.TarError, OSError) as exc:
        raise ValueError(f"cannot read archive {archive}: {exc}") from exc
    return dest


def _ensure_safe_member(member: tarfile.TarInfo, dest_resolved: Path) -> None:
    """Reject members that would escape ``dest`` (path traversal / absolute paths)."""

    name = member.name
    if not name or name.startswith("/"):
        raise ValueError(f"archive contains an unsafe (absolute) member path: {name!r}")
    # Resolve the target and confirm it stays under dest. linkname is checked for symlinks by
    # the 'data' filter at extraction time; this guards against '..' in the member name itself.
    target = (dest_resolved / name).resolve()
    if not str(target).startswith(str(dest_resolved) + os.sep) and target != dest_resolved:
        raise ValueError(f"archive member escapes destination: {name!r}")


def extract_paths(archive: str | Path) -> list[str]:
    """Return the sorted list of member paths in a `.tar.xz` archive.

    Each path is normalised to a forward-slash, leading-slash-relative form (the path inside the
    archive, prefixed with `/`). Directories (members ending in ``/``) are kept as-is. This is a
    convenience for callers that only need the path list; for full file inspection use
    :func:`extract_archive`.

    Raises ``ValueError`` if the archive cannot be opened or read.
    """

    archive = Path(archive)
    if not archive.is_file():
        raise ValueError(f"archive not found: {archive}")

    paths: list[str] = []
    try:
        with tarfile.open(archive, "r:xz") as tar:
            for member in tar.getmembers():
                name = member.name
                if not name:
                    continue
                # Normalise to an absolute-looking path (Chisel content paths are absolute).
                if not name.startswith("/"):
                    name = "/" + name
                paths.append(name)
    except (tarfile.TarError, OSError) as exc:
        raise ValueError(f"cannot read archive {archive}: {exc}") from exc

    return sorted(set(paths))
