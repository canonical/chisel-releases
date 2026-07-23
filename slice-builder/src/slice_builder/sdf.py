"""SDF data model plus YAML load/dump helpers.

The model is intentionally small: it represents the subset of the Chisel slice definition
format (v3/v4) that the generator produces and re-emits. Dependency SDFs are loaded as plain
dicts (``load_sdf_dict``) for analysis; the generator's own output is round-tripped through the
``SDF``/``Slice`` dataclasses and ``dump_sdf``.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml

# A content entry is either ``None`` (a bare path, emitted as ``/path:``) or a dict of path
# properties (e.g. ``{"prefer": "libc6"}``).
ContentEntry = dict | None


@dataclass
class Slice:
    """A single slice within an SDF."""

    name: str
    contents: dict[str, ContentEntry] = field(default_factory=dict)
    essential: dict[str, dict] = field(default_factory=dict)
    # Preserves unrecognised slice-level fields (mutate, hint, ...) when round-tripping.
    extra: dict = field(default_factory=dict)


@dataclass
class SDF:
    """A slice definition file."""

    package: str
    store: str | None = None
    default_track: str | None = None
    essential: dict[str, dict] = field(default_factory=dict)
    slices: dict[str, Slice] = field(default_factory=dict)
    # Preserves unrecognised top-level fields (archive, ...) when round-tripping.
    extra: dict = field(default_factory=dict)


def byte_sorted(items):
    """Return ``items`` sorted in byte order (``LC_COLLATE=C``), lexicographic by UTF-8 bytes.

    UTF-8 is designed so that byte-wise comparison preserves code-point order, so this matches
    a C-locale sort for valid UTF-8 strings.
    """

    return sorted(items, key=lambda x: x.encode("utf-8"))


def load_sdf_dict(path: str | Path) -> dict:
    """Load an SDF file as a plain dict (for dependency analysis)."""

    with open(path, encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"SDF {path} is not a YAML mapping")
    return data


def _coerce_essential(value) -> dict[str, dict]:
    """Normalise an ``essential`` value (v3/v4 map or v1/v2 list) to a map of dicts."""

    if isinstance(value, dict):
        return {str(k): (v if isinstance(v, dict) else {}) for k, v in value.items()}
    if isinstance(value, list):
        return {str(k): {} for k in value}
    return {}


def _coerce_contents(value) -> dict[str, ContentEntry]:
    """Normalise a ``contents`` value to a map of path -> entry."""

    if not isinstance(value, dict):
        return {}
    return {str(k): (v if isinstance(v, dict) else None) for k, v in value.items()}


def parse_sdf(data: dict) -> SDF:
    """Parse and validate a plain dict into an :class:`SDF`.

    Raises ``ValueError`` if required fields (``package``, ``slices``) are missing.
    """

    errors: list[str] = []
    if "package" not in data:
        errors.append("missing required field: package")
    if not isinstance(data.get("slices"), dict):
        errors.append("missing required field: slices")
    if errors:
        raise ValueError("; ".join(errors))

    sdf = SDF(package=str(data["package"]))
    sdf.store = data.get("store")
    sdf.default_track = data.get("default-track")
    if sdf.default_track is not None:
        sdf.default_track = str(sdf.default_track)
    sdf.essential = _coerce_essential(data.get("essential"))

    for name, sdata in data["slices"].items():
        if not isinstance(sdata, dict):
            continue
        sl = Slice(name=str(name))
        sl.contents = _coerce_contents(sdata.get("contents"))
        sl.essential = _coerce_essential(sdata.get("essential"))
        sl.extra = {k: v for k, v in sdata.items() if k not in ("contents", "essential")}
        sdf.slices[str(name)] = sl

    sdf.extra = {
        k: v
        for k, v in data.items()
        if k not in ("package", "store", "default-track", "essential", "slices")
    }
    return sdf


class _QuotedStr(str):
    """A string subclass that is always emitted with double-quote style."""


class SDFDumper(yaml.SafeDumper):
    """Custom dumper forcing the repo SDF style: block style, null-valued bare keys."""


def _represent_none(dumper, _):
    # Emit ``None`` as an empty scalar so dict values render as ``key:`` (not ``key: null``).
    return dumper.represent_scalar("tag:yaml.org,2002:null", "")


def _represent_quoted_str(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:str", str(data), style='"')


SDFDumper.add_representer(type(None), _represent_none)
SDFDumper.add_representer(_QuotedStr, _represent_quoted_str)


def _sdf_to_dict(sdf: SDF) -> dict:
    out: dict = {"package": sdf.package}
    if sdf.store is not None:
        out["store"] = sdf.store
    if sdf.default_track is not None:
        out["default-track"] = _QuotedStr(sdf.default_track)
    if sdf.essential:
        out["essential"] = {k: (v if v else None) for k, v in sdf.essential.items()}
    slices_out: dict = {}
    for name, sl in sdf.slices.items():
        sd: dict = {}
        if sl.essential:
            sd["essential"] = {k: (v if v else None) for k, v in sl.essential.items()}
        if sl.contents:
            sd["contents"] = dict(sl.contents)
        sd.update(sl.extra)
        slices_out[name] = sd
    out["slices"] = slices_out
    out.update(sdf.extra)
    return out


def dump_sdf(sdf: SDF) -> str:
    """Render an :class:`SDF` to a canonical YAML string (block style, sorted by caller).."""

    data = _sdf_to_dict(sdf)
    return yaml.dump(
        data,
        Dumper=SDFDumper,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=100,
    )
