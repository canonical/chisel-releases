"""Overlay a read-only SDF lookup directory onto a checkout's bin SDF directory."""

from __future__ import annotations

import shutil
from pathlib import Path


def overlay(lookup_dir: str | Path | None, checkout: str | Path, bin_sdf_dir: str) -> None:
    """Copy ``*.yaml`` files from ``lookup_dir`` into ``checkout/bin_sdf_dir``.

    The lookup dir is read-only (populated by sd-tools, never overwritten). Existing files in
    the checkout's bin SDF dir with the same name are overwritten by the overlay, mirroring the
    "unified tree" intent: previously-generated bin SDFs take precedence over the checkout's
    versions.

    A missing or empty ``lookup_dir`` is a no-op.
    """

    if lookup_dir is None:
        return
    src = Path(lookup_dir)
    if not src.is_dir():
        return

    dst = Path(checkout) / bin_sdf_dir
    dst.mkdir(parents=True, exist_ok=True)

    for yaml_file in sorted(src.glob("*.yaml")):
        shutil.copy2(yaml_file, dst / yaml_file.name)
