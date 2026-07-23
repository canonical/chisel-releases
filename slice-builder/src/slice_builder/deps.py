"""Locate and load dependency SDFs (bin vs deb detection).

For each dependency ``sd_name``:

1. Search the SDF lookup dir (already-generated bin SDFs), then the checkout's bin SDF dir, then
   the checkout's regular ``slices/`` dir (deb SDFs).
2. Load the SDF; determine bin vs deb by the presence of ``store: bin``.
3. Build a :class:`DepRef` with the appropriate prefix (release bin prefix for bin deps, empty
   for deb deps).
"""

from __future__ import annotations

from pathlib import Path

from slice_builder.config import DepRef
from slice_builder.sdf import load_sdf_dict


def _find_sdf(sd_name: str, lookup_dir: str | Path | None, checkout: str | Path) -> Path | None:
    """Locate ``<sd_name>.yaml`` in lookup dir, then checkout bin dir, then checkout slices."""

    candidates: list[Path] = []
    if lookup_dir is not None:
        candidates.append(Path(lookup_dir) / f"{sd_name}.yaml")
    # Checkout bin SDF dir (v3: bin-slices/, v4: slices/) and regular slices/ both covered.
    for sub in ("bin-slices", "slices"):
        candidates.append(Path(checkout) / sub / f"{sd_name}.yaml")
    for c in candidates:
        if c.is_file():
            return c
    return None


def resolve_deps(
    dependencies: list[str],
    lookup_dir: str | Path | None,
    checkout: str | Path,
    bin_prefix: str,
) -> list[DepRef]:
    """Resolve all dependency SDFs.

    Raises ``ValueError`` listing every dependency whose SDF could not be found.
    """

    missing: list[str] = []
    refs: list[DepRef] = []
    for sd_name in dependencies:
        path = _find_sdf(sd_name, lookup_dir, checkout)
        if path is None:
            missing.append(sd_name)
            continue
        sdf = load_sdf_dict(path)
        is_bin = sdf.get("store") == "bin"
        refs.append(
            DepRef(
                sd_name=sd_name,
                is_bin=is_bin,
                prefix=bin_prefix if is_bin else "",
                sdf=sdf,
            )
        )
    if missing:
        raise ValueError(f"dependency SDF(s) not found: {', '.join(missing)}")
    return refs


def slice_ref(dep: DepRef, slice_name: str) -> str:
    """Build a full slice reference for a dependency slice.

    Bin deps use the prefixed identifier (``bin-<dep>_<slice>``); deb deps use the bare name
    (``<dep>_<slice>``).
    """

    return f"{dep.prefix}{dep.sd_name}_{slice_name}"
