"""Parse `chisel.yaml` from a chisel-releases checkout.

The schema is verified against the Chisel documentation (format v1-v4). Only the fields the
slice-builder needs are extracted: ``format``, the bin store's ``default-prefix``, and the bin
SDF directory implied by the format (``bin-slices/`` for v3, ``slices/`` for v4).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

# The store name for bin packages. Hardcoded per the plan's "Open / future" item #3.
BIN_STORE = "bin"


@dataclass
class ReleaseInfo:
    """The subset of `chisel.yaml` the slice-builder consumes."""

    format: str
    bin_prefix: str
    bin_sdf_dir: str


def parse_chisel_yaml(checkout: str | Path) -> ReleaseInfo:
    """Parse `chisel.yaml` from the root of a checkout.

    Raises ``ValueError`` if the file is missing, malformed, or lacks the bin store.
    """

    checkout = Path(checkout)
    path = checkout / "chisel.yaml"
    if not path.is_file():
        raise ValueError(f"chisel.yaml not found at {path}")

    with open(path, encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"{path} is not a YAML mapping")

    fmt = str(data.get("format", "")).strip()
    if fmt not in ("v1", "v2", "v3", "v4"):
        raise ValueError(f"{path}: unsupported or missing format: {fmt!r}")

    stores = data.get("stores")
    if not isinstance(stores, dict) or BIN_STORE not in stores:
        raise ValueError(f"{path}: missing stores.{BIN_STORE}")

    bin_store = stores[BIN_STORE]
    if not isinstance(bin_store, dict):
        raise ValueError(f"{path}: stores.{BIN_STORE} is not a mapping")

    prefix = bin_store.get("default-prefix")
    if not isinstance(prefix, str) or not prefix:
        raise ValueError(f"{path}: stores.{BIN_STORE}.default-prefix missing or invalid")

    # v3: bin SDFs live in bin-slices/; v4+: bin SDFs live in slices/ alongside regular ones.
    bin_sdf_dir = "bin-slices" if fmt == "v3" else "slices"

    return ReleaseInfo(format=fmt, bin_prefix=prefix, bin_sdf_dir=bin_sdf_dir)
