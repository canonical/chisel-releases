"""Unit tests for prefer.py."""

from slice_builder.prefer import apply_prefer, is_glob, scan_prefer
from slice_builder.sdf import SDF, Slice


def _make_sdf_with_paths(paths) -> SDF:
    sdf = SDF(package="curl", store="bin", default_track="0.1")
    sdf.slices["bins"] = Slice(name="bins", contents={p: None for p in paths})
    return sdf


def _write_other(path, package, store, contents):
    lines = [f"package: {package}"]
    if store:
        lines.append(f"store: {store}")
    lines.append("slices:")
    lines.append("  bins:")
    lines.append("    contents:")
    for p in contents:
        lines.append(f"      {p}:")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def test_is_glob_detects_wildcards():
    assert is_glob("/usr/bin/*")
    assert is_glob("/usr/lib/**")
    assert is_glob("/usr/?")
    assert not is_glob("/usr/bin/curl")


def test_scan_prefer_bin_vs_deb_prefers_deb(tmp_checkout):
    sdf = _make_sdf_with_paths(["/usr/bin/curl"])
    _write_other(
        tmp_checkout / "slices" / "libc6.yaml",
        "libc6",
        None,
        ["/usr/bin/curl"],
    )
    result = scan_prefer(sdf, tmp_checkout, "bin-", "bin-curl")
    assert result.prefers == {"/usr/bin/curl": "libc6"}
    assert result.bin_vs_bin_conflicts == {}


def test_scan_prefer_bin_vs_bin_flags_conflict(tmp_checkout):
    sdf = _make_sdf_with_paths(["/usr/bin/curl"])
    _write_other(
        tmp_checkout / "bin-slices" / "other.yaml",
        "other",
        "bin",
        ["/usr/bin/curl"],
    )
    result = scan_prefer(sdf, tmp_checkout, "bin-", "bin-curl")
    assert result.prefers == {}
    assert "/usr/bin/curl" in result.bin_vs_bin_conflicts
    assert "bin-other" in result.bin_vs_bin_conflicts["/usr/bin/curl"]


def test_scan_prefer_ignores_glob_paths(tmp_checkout):
    sdf = _make_sdf_with_paths(["/usr/bin/*"])
    _write_other(
        tmp_checkout / "slices" / "libc6.yaml",
        "libc6",
        None,
        ["/usr/bin/*"],
    )
    result = scan_prefer(sdf, tmp_checkout, "bin-", "bin-curl")
    assert result.prefers == {}


def test_scan_prefer_skips_self(tmp_checkout):
    sdf = _make_sdf_with_paths(["/usr/bin/curl"])
    _write_other(
        tmp_checkout / "bin-slices" / "curl.yaml",
        "curl",
        "bin",
        ["/usr/bin/curl"],
    )
    result = scan_prefer(sdf, tmp_checkout, "bin-", "bin-curl")
    assert result.prefers == {}
    assert result.bin_vs_bin_conflicts == {}


def test_apply_prefer_adds_prefer_to_literal_path():
    sdf = _make_sdf_with_paths(["/usr/bin/curl", "/usr/bin/*"])
    from slice_builder.prefer import PreferResult

    result = PreferResult(prefers={"/usr/bin/curl": "libc6"})
    apply_prefer(sdf, result)
    assert sdf.slices["bins"].contents["/usr/bin/curl"] == {"prefer": "libc6"}
    # Glob path untouched.
    assert sdf.slices["bins"].contents["/usr/bin/*"] is None


def test_apply_prefer_preserves_existing_entry():
    sdf = _make_sdf_with_paths(["/usr/bin/curl"])
    sdf.slices["bins"].contents["/usr/bin/curl"] = {"mode": 0o755}
    from slice_builder.prefer import PreferResult

    result = PreferResult(prefers={"/usr/bin/curl": "libc6"})
    apply_prefer(sdf, result)
    assert sdf.slices["bins"].contents["/usr/bin/curl"] == {"mode": 0o755, "prefer": "libc6"}
