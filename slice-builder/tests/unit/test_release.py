"""Unit tests for release.py."""

import pytest

from slice_builder.release import parse_chisel_yaml


def test_parse_v3_bin_prefix_and_dir(tmp_checkout):
    info = parse_chisel_yaml(tmp_checkout)
    assert info.format == "v3"
    assert info.bin_prefix == "bin-"
    assert info.bin_sdf_dir == "bin-slices"


def test_parse_v4_uses_slices_dir(tmp_path):
    (tmp_path / "chisel.yaml").write_text(
        "format: v4\n"
        "archives:\n  ubuntu:\n    default: true\n    version: 26.10\n"
        "    components: [main]\n    suites: [noble]\n    public-keys: [k]\n"
        "stores:\n  bin:\n    kind: bin\n    version: 26.10\n    default-prefix: 'bin-'\n",
        encoding="utf-8",
    )
    info = parse_chisel_yaml(tmp_path)
    assert info.format == "v4"
    assert info.bin_sdf_dir == "slices"


def test_parse_missing_file_raises(tmp_path):
    with pytest.raises(ValueError, match="chisel.yaml not found"):
        parse_chisel_yaml(tmp_path)


def test_parse_missing_bin_store_raises(tmp_path):
    (tmp_path / "chisel.yaml").write_text(
        "format: v3\narchives:\n  ubuntu:\n    default: true\n",
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="missing stores.bin"):
        parse_chisel_yaml(tmp_path)


def test_parse_bad_format_raises(tmp_path):
    (tmp_path / "chisel.yaml").write_text(
        "format: v9\nstores:\n  bin:\n    kind: bin\n    default-prefix: 'bin-'\n",
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="unsupported or missing format"):
        parse_chisel_yaml(tmp_path)


def test_parse_missing_prefix_raises(tmp_path):
    (tmp_path / "chisel.yaml").write_text(
        "format: v3\nstores:\n  bin:\n    kind: bin\n",
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="default-prefix"):
        parse_chisel_yaml(tmp_path)
