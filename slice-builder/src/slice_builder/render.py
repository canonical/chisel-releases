"""Sort and render an SDF to canonical YAML.

Sorting is byte order (``LC_COLLATE=C``, lexicographic by UTF-8 bytes) for ``contents`` paths
and ``essential`` entries, matching the validation rule. Slice order is preserved as the agent
emitted it (the spec only mandates path/essential key order).
"""

from __future__ import annotations

from slice_builder.sdf import SDF, byte_sorted, dump_sdf


def sort_sdf(sdf: SDF) -> None:
    """Sort ``contents`` paths and ``essential`` entries in byte order, in place."""

    sdf.essential = {k: sdf.essential[k] for k in byte_sorted(sdf.essential)}
    for sl in sdf.slices.values():
        sl.essential = {k: sl.essential[k] for k in byte_sorted(sl.essential)}
        sl.contents = {k: sl.contents[k] for k in byte_sorted(sl.contents)}


def render(sdf: SDF) -> str:
    """Sort and render an SDF to a canonical YAML string.

    A blank line is inserted between top-level sections and between slices to match the
    existing repo SDF style (e.g. ``slices/bins/curl.yaml``).
    """

    sort_sdf(sdf)
    text = dump_sdf(sdf)
    # Insert a blank line before each top-level key that starts at column 0 (no leading space),
    # except the very first line. This mirrors the repo's section spacing.
    lines = text.splitlines()
    out: list[str] = []
    for i, line in enumerate(lines):
        if i > 0 and line and not line[0].isspace() and not line.startswith("-"):
            if out and out[-1] != "":
                out.append("")
        out.append(line)
    return "\n".join(out) + "\n"
