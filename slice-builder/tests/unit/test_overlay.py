"""Unit tests for overlay.py."""

from slice_builder.overlay import overlay


def test_overlay_copies_yaml_files(tmp_path):
    lookup = tmp_path / "lookup"
    lookup.mkdir()
    (lookup / "a.yaml").write_text("package: a\n", encoding="utf-8")
    (lookup / "b.yaml").write_text("package: b\n", encoding="utf-8")
    (lookup / "ignore.txt").write_text("nope", encoding="utf-8")
    checkout = tmp_path / "checkout"
    checkout.mkdir()
    overlay(lookup, checkout, "bin-slices")
    assert (checkout / "bin-slices" / "a.yaml").is_file()
    assert (checkout / "bin-slices" / "b.yaml").is_file()
    assert not (checkout / "bin-slices" / "ignore.txt").exists()


def test_overlay_missing_dir_is_noop(tmp_path):
    checkout = tmp_path / "checkout"
    checkout.mkdir()
    overlay(tmp_path / "nope", checkout, "bin-slices")
    assert not (checkout / "bin-slices").exists()


def test_overlay_none_is_noop(tmp_path):
    checkout = tmp_path / "checkout"
    checkout.mkdir()
    overlay(None, checkout, "bin-slices")
    assert not (checkout / "bin-slices").exists()


def test_overlay_overwrites_existing(tmp_path):
    lookup = tmp_path / "lookup"
    lookup.mkdir()
    (lookup / "a.yaml").write_text("package: new\n", encoding="utf-8")
    checkout = tmp_path / "checkout"
    (checkout / "bin-slices").mkdir(parents=True)
    (checkout / "bin-slices" / "a.yaml").write_text("package: old\n", encoding="utf-8")
    overlay(lookup, checkout, "bin-slices")
    assert (checkout / "bin-slices" / "a.yaml").read_text() == "package: new\n"
