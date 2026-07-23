"""Extract member paths from a `.tar.xz` bin archive."""

from __future__ import annotations

import tarfile
from pathlib import Path


def extract_paths(archive: str | Path) -> list[str]:
    """Return the sorted list of member paths in a `.tar.xz` archive.

    Each path is normalised to a forward-slash, leading-slash-relative form (the path inside the
    archive, prefixed with `/`). Directories (members ending in ``/``) are kept as-is.

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
