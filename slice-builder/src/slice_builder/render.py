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
    """Sort and render an SDF to a canonical YAML string."""

    sort_sdf(sdf)
    text = dump_sdf(sdf)
    lines = text.splitlines()
    out: list[str] = []
    in_slices = False
    first_slice_seen = False
    for i, line in enumerate(lines):
        if line == "slices:":
            in_slices = True
            first_slice_seen = False
        is_top_level = bool(line) and not line[0].isspace()
        is_slice_name = (
            in_slices
            and line.startswith("  ")
            and not line.startswith("   ")
            and line.endswith(":")
        )
        insert_blank = False
        if i > 0 and is_top_level:
            insert_blank = True
        elif is_slice_name and first_slice_seen:
            insert_blank = True
        if is_slice_name:
            first_slice_seen = True
        if insert_blank and out and out[-1] != "":
            out.append("")
        out.append(line)
    return "\n".join(out) + "\n"
