"""Unit tests for deps.py."""

import pytest

from slice_builder.config import DepRef
from slice_builder.deps import resolve_deps, slice_ref


def _write_sdf(path, store=None, package="x", slices=None):
    lines = [f"package: {package}"]
    if store:
        lines.append(f"store: {store}")
    lines.append("slices:")
    for name, paths in (slices or {}).items():
        lines.append(f"  {name}:")
        lines.append("    contents:")
        for p in paths:
            lines.append(f"      {p}:")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def test_resolve_deps_finds_bin_in_lookup(tmp_path):
    lookup = tmp_path / "lookup"
    lookup.mkdir()
    _write_sdf(
        lookup / "dep1.yaml",
        store="bin",
        package="dep1",
        slices={"bins": ["/usr/bin/dep1"]},
    )
    refs = resolve_deps(["dep1"], lookup, tmp_path, "bin-")
    assert len(refs) == 1
    assert refs[0].is_bin is True
    assert refs[0].prefix == "bin-"


def test_resolve_deps_finds_deb_in_checkout_slices(tmp_checkout):
    _write_sdf(
        tmp_checkout / "slices" / "libc6.yaml",
        package="libc6",
        slices={"libs": ["/usr/lib/libc.so"]},
    )
    refs = resolve_deps(["libc6"], None, tmp_checkout, "bin-")
    assert refs[0].is_bin is False
    assert refs[0].prefix == ""


def test_resolve_deps_missing_raises(tmp_checkout):
    with pytest.raises(ValueError, match="dependency SDF.*not found"):
        resolve_deps(["nope"], None, tmp_checkout, "bin-")


def test_slice_ref_bin_uses_prefix():
    dep = DepRef(sd_name="dep", is_bin=True, prefix="bin-", sdf={})
    assert slice_ref(dep, "bins") == "bin-dep_bins"


def test_slice_ref_deb_bare():
    dep = DepRef(sd_name="libc6", is_bin=False, prefix="", sdf={})
    assert slice_ref(dep, "libs") == "libc6_libs"
