#!/usr/bin/env python3
"""
Unit tests for reject_unknown_keys.py
"""

import os
import sys
from pathlib import Path
from textwrap import dedent

import pytest

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import reject_unknown_keys as ruk


def write_release(tmp_path: Path, release_format: str, **slices: str) -> Path:
    """Lay out a minimal release checkout and return its root."""
    (tmp_path / "chisel.yaml").write_text(f"format: {release_format}\n")
    slices_dir = tmp_path / "slices"
    slices_dir.mkdir(exist_ok=True)
    for name, body in slices.items():
        (slices_dir / f"{name}.yaml").write_text(dedent(body).lstrip())
    return tmp_path


CLEAN_V3 = """
    package: example

    essential:
      example_copyright:

    slices:
      bins:
        hint: Example binaries
        essential:
          libc6_libs:
            arch: [amd64]
        contents:
          /usr/bin/example:
          /usr/bin/linked:
            symlink: /usr/bin/example
          /var/cache/example/:
            make: true
            mode: 0755
        mutate: |
          content.write("/x", "y")

      copyright:
        contents:
          /usr/share/doc/example/copyright:
    """


class TestKeySets:
    def test_the_keys_chisel_reads(self):
        assert ruk.PACKAGE_KEYS == frozenset(
            {"package", "archive", "essential", "slices", "store", "default-track", "v3-essential"}
        )
        assert ruk.SLICE_KEYS == frozenset(
            {"hint", "essential", "contents", "mutate", "v3-essential"}
        )
        assert ruk.PATH_KEYS == frozenset(
            {
                "make", "mode", "copy", "text", "symlink",
                "mutable", "until", "arch", "generate", "prefer",
            }
        )
        assert ruk.ESSENTIAL_KEYS == frozenset({"arch"})


class TestReadFormat:
    def test_reads_format(self, tmp_path):
        release = write_release(tmp_path, "v3")
        assert ruk.read_format(release) == "v3"

    def test_accepts_every_known_format(self, tmp_path):
        for fmt in ruk.KNOWN_FORMATS:
            release = write_release(tmp_path, fmt)
            assert ruk.read_format(release) == fmt

    def test_missing_file(self, tmp_path):
        with pytest.raises(ValueError, match="cannot read"):
            ruk.read_format(tmp_path)

    def test_missing_field(self, tmp_path):
        (tmp_path / "chisel.yaml").write_text("archives: {}\n")
        with pytest.raises(ValueError, match="no 'format' field"):
            ruk.read_format(tmp_path)

    def test_unparseable(self, tmp_path):
        (tmp_path / "chisel.yaml").write_text("format: [unclosed\n")
        with pytest.raises(ValueError, match="cannot parse"):
            ruk.read_format(tmp_path)

    def test_unknown_format_rejected(self, tmp_path):
        release = write_release(tmp_path, "v9")
        with pytest.raises(ValueError, match="unknown format"):
            ruk.read_format(release)


class TestCheckFile:
    def test_clean_file_has_no_findings(self, tmp_path):
        release = write_release(tmp_path, "v3", example=CLEAN_V3)
        assert ruk.check_file(release / "slices" / "example.yaml") == []

    def test_the_real_world_content_typo(self, tmp_path):
        # The defect this check exists to catch: `content:` for `contents:`.
        release = write_release(
            tmp_path,
            "v3",
            example="""
            package: example
            slices:
              copyright:
                content:
                  /usr/share/doc/example/copyright:
            """,
        )
        findings = ruk.check_file(release / "slices" / "example.yaml")
        assert len(findings) == 1
        assert findings[0].key == "content"
        assert findings[0].line == 4

    def test_catches_a_typo_at_every_level(self, tmp_path):
        release = write_release(
            tmp_path,
            "v3",
            example="""
            package: example
            packge: typo
            essential:
              other_copyright:
                arhc: [amd64]
            slices:
              bins:
                mutat: "typo"
                contents:
                  /usr/bin/example:
                    symlnk: /usr/bin/other
            """,
        )
        found = {f.key for f in ruk.check_file(release / "slices" / "example.yaml")}
        assert found == {"packge", "arhc", "mutat", "symlnk"}

    def test_does_not_flag_the_valid_neighbour(self, tmp_path):
        release = write_release(
            tmp_path,
            "v3",
            example="""
            package: example
            slices:
              bins:
                contents:
                  /usr/bin/a:
                    symlnk: /usr/bin/b
                  /usr/bin/c:
                    symlink: /usr/bin/d
            """,
        )
        findings = ruk.check_file(release / "slices" / "example.yaml")
        assert [f.key for f in findings] == ["symlnk"]

    def test_reports_the_line(self, tmp_path):
        release = write_release(
            tmp_path,
            "v3",
            example="""
            package: example
            slices:
              bins:
                contents:
                  /usr/bin/a:
                    symlnk: /usr/bin/b
            """,
        )
        (finding,) = ruk.check_file(release / "slices" / "example.yaml")
        assert finding.line == 6
        assert "symlnk" in str(finding)

    def test_essential_as_list_is_not_walked_for_options(self, tmp_path):
        # A v1-style list has no per-entry options to check; it must not crash.
        release = write_release(
            tmp_path,
            "v1",
            example="""
            package: example
            essential:
              - other_copyright
            slices:
              bins:
                essential:
                  - libc6_libs
            """,
        )
        assert ruk.check_file(release / "slices" / "example.yaml") == []

    def test_unparseable_yaml_is_an_error(self, tmp_path):
        release = write_release(tmp_path, "v3", broken="package: [unclosed\n")
        with pytest.raises(ValueError, match="cannot parse as YAML"):
            ruk.check_file(release / "slices" / "broken.yaml")

    def test_non_mapping_root_is_an_error(self, tmp_path):
        release = write_release(tmp_path, "v3", odd="- a\n- b\n")
        with pytest.raises(ValueError, match="top-level mapping"):
            ruk.check_file(release / "slices" / "odd.yaml")

    def test_empty_file_is_an_error(self, tmp_path):
        release = write_release(tmp_path, "v3", empty="")
        with pytest.raises(ValueError, match="top-level mapping"):
            ruk.check_file(release / "slices" / "empty.yaml")


class TestResolveTargets:
    def test_no_files_means_every_slice(self, tmp_path):
        release = write_release(tmp_path, "v3", a=CLEAN_V3, b=CLEAN_V3)
        assert [p.name for p in ruk.resolve_targets(release, [])] == ["a.yaml", "b.yaml"]

    def test_named_files_are_used(self, tmp_path):
        release = write_release(tmp_path, "v3", a=CLEAN_V3, b=CLEAN_V3)
        targets = ruk.resolve_targets(release, [str(release / "slices" / "a.yaml")])
        assert [p.name for p in targets] == ["a.yaml"]

    def test_paths_outside_slices_are_dropped(self, tmp_path):
        release = write_release(tmp_path, "v3", a=CLEAN_V3)
        (release / "README.md").write_text("hi\n")
        targets = ruk.resolve_targets(
            release,
            [str(release / "slices" / "a.yaml"), str(release / "README.md"), "chisel.yaml"],
        )
        assert [p.name for p in targets] == ["a.yaml"]

    def test_deleted_files_are_dropped(self, tmp_path):
        # A changed-file list from a PR can name files the branch removed.
        release = write_release(tmp_path, "v3", a=CLEAN_V3)
        targets = ruk.resolve_targets(
            release,
            [str(release / "slices" / "a.yaml"), str(release / "slices" / "gone.yaml")],
        )
        assert [p.name for p in targets] == ["a.yaml"]


class TestMain:
    def test_clean_release_exits_zero(self, tmp_path):
        release = write_release(tmp_path, "v3", example=CLEAN_V3)
        assert ruk.main(["--release", str(release)]) == 0

    def test_bad_key_exits_one(self, tmp_path):
        release = write_release(
            tmp_path,
            "v3",
            example="""
            package: example
            slices:
              copyright:
                content:
                  /usr/share/doc/example/copyright:
            """,
        )
        assert ruk.main(["--release", str(release)]) == 1

    def test_unknown_format_exits_two(self, tmp_path):
        release = write_release(tmp_path, "v9", example=CLEAN_V3)
        assert ruk.main(["--release", str(release)]) == 2

    def test_missing_chisel_yaml_exits_two(self, tmp_path):
        (tmp_path / "slices").mkdir()
        assert ruk.main(["--release", str(tmp_path)]) == 2

    def test_no_matching_files_exits_zero(self, tmp_path):
        release = write_release(tmp_path, "v3", example=CLEAN_V3)
        assert ruk.main(["--release", str(release), str(release / "README.md")]) == 0
