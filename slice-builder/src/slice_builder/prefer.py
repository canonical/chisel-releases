"""Literal-path conflict scan across checkout SDFs -> ``prefer``.

The agent does not compute ``prefer``; the builder does it deterministically after the agent
produces a draft SDF. For each LITERAL (non-glob) path in the generated bin SDF's contents that
also appears in another package's SDF in the checkout:

- Bin vs deb conflict: emit ``prefer: <deb-package-name>`` on the bin's path (deb wins).
- Bin vs bin conflict: flag for human review (no default resolution).

``prefer`` is forbidden on glob paths.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from slice_builder.sdf import SDF, load_sdf_dict

GLOB_CHARS = ("*", "?", "**")


def is_glob(path: str) -> bool:
    """Return True if ``path`` contains any glob character."""

    return any(ch in path for ch in GLOB_CHARS)


@dataclass
class PreferResult:
    """Outcome of a prefer scan."""

    # path -> prefer value (the package identifier to prefer).
    prefers: dict[str, str] = field(default_factory=dict)
    # path -> list of conflicting package identifiers (for human review).
    bin_vs_bin_conflicts: dict[str, list[str]] = field(default_factory=dict)


def _collect_literal_paths(sdf_dict: dict) -> set[str]:
    """Return the set of literal (non-glob) content paths in an SDF dict."""

    paths: set[str] = set()
    for sl in (sdf_dict.get("slices") or {}).values():
        if not isinstance(sl, dict):
            continue
        contents = sl.get("contents")
        if not isinstance(contents, dict):
            continue
        for p in contents:
            if isinstance(p, str) and not is_glob(p):
                paths.add(p)
    return paths


def _package_identifier(sdf_dict: dict, bin_prefix: str) -> str:
    """Return the unique package identifier for an SDF (prefixed for bins, bare for debs)."""

    pkg = str(sdf_dict.get("package", ""))
    if sdf_dict.get("store") == "bin":
        return f"{bin_prefix}{pkg}"
    return pkg


def scan_prefer(
    generated: SDF,
    checkout: str | Path,
    bin_prefix: str,
    own_identifier: str,
) -> PreferResult:
    """Scan checkout SDFs for literal-path conflicts with ``generated``.

    ``own_identifier`` is the generated package's unique identifier (e.g. ``bin-curl``), used to
    skip self-conflicts.
    """

    result = PreferResult()
    checkout = Path(checkout)

    # Literal paths in the generated SDF, grouped by slice for later application.
    own_literals: set[str] = set()
    for sl in generated.slices.values():
        for p in sl.contents:
            if not is_glob(p):
                own_literals.add(p)

    if not own_literals:
        return result

    # Map: literal path -> list of (other_identifier, is_bin) that also declare it.
    conflicts: dict[str, list[tuple[str, bool]]] = {}
    for sdf_dir in ("bin-slices", "slices"):
        d = checkout / sdf_dir
        if not d.is_dir():
            continue
        for yaml_file in sorted(d.glob("*.yaml")):
            try:
                other = load_sdf_dict(yaml_file)
            except (OSError, ValueError):
                continue
            other_id = _package_identifier(other, bin_prefix)
            if other_id == own_identifier:
                continue
            other_is_bin = other.get("store") == "bin"
            for p in _collect_literal_paths(other):
                if p in own_literals:
                    conflicts.setdefault(p, []).append((other_id, other_is_bin))

    for path, others in conflicts.items():
        deb_winners = [oid for oid, is_bin in others if not is_bin]
        bin_winners = [oid for oid, is_bin in others if is_bin]
        if deb_winners:
            # Deb wins by default; prefer the first deb (deterministic).
            result.prefers[path] = deb_winners[0]
        elif bin_winners:
            # Bin vs bin: no default; flag for human review.
            result.bin_vs_bin_conflicts[path] = sorted(bin_winners)
    return result


def apply_prefer(sdf: SDF, result: PreferResult) -> None:
    """Apply ``prefer`` values to the generated SDF's literal content paths in place.

    Glob paths are never touched. Existing path properties are preserved; ``prefer`` is added.
    """

    for sl in sdf.slices.values():
        for path, entry in list(sl.contents.items()):
            if is_glob(path):
                continue
            if path in result.prefers:
                new_entry: dict = dict(entry) if entry else {}
                new_entry["prefer"] = result.prefers[path]
                sl.contents[path] = new_entry
