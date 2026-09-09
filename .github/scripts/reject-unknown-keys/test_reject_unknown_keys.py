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
    def test_v1_and_v2_allow_v3_essential(self):
        for fmt in ("v1", "v2"):
            keys = ruk.key_sets_for(fmt)
            assert "v3-essential" in keys.package
            assert "v3-essential" in keys.slice

    def test_v1_and_v2_reject_store_keys(self):
        for fmt in ("v1", "v2"):
            keys = ruk.key_sets_for(fmt)
            assert "store" not in keys.package
            assert "default-track" not in keys.package

    def test_v3_allows_store_keys(self):
        keys = ruk.key_sets_for("v3")
        assert "store" in keys.package
        assert "default-track" in keys.package

    def test_v3_rejects_v3_essential(self):
        # Chisel calls it "obsolete since format v3".
        keys = ruk.key_sets_for("v3")
        assert "v3-essential" not in keys.package
        assert "v3-essential" not in keys.slice

    def test_shared_keys_present_in_every_format(self):
        for fmt in ruk.KNOWN_FORMATS:
            keys = ruk.key_sets_for(fmt)
            assert {"package", "archive", "essential", "slices"} <= keys.package
            assert {"hint", "essential", "contents", "mutate"} <= keys.slice
            assert {"make", "mode", "copy", "symlink", "prefer"} <= keys.path
            assert keys.essential == frozenset({"arch"})

    def test_unknown_format_rejected(self):
        with pytest.raises(ValueError, match="unknown format"):
            ruk.key_sets_for("v9")

    def test_v4_is_not_handled_yet(self):
        # Chisel accepts v4, but it relocates bin slice definitions, so it needs
        # deliberate work here rather than being waved through.
        with pytest.raises(ValueError, match="unknown format"):
            ruk.key_sets_for("v4")


class TestReadFormat:
    def test_reads_format(self, tmp_path):
        release = write_release(tmp_path, "v3")
        assert ruk.read_format(release) == "v3"

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


class TestCheckFile:
    def test_clean_file_has_no_findings(self, tmp_path):
        release = write_release(tmp_path, "v3", example=CLEAN_V3)
        keys = ruk.key_sets_for("v3")
        assert ruk.check_file(release / "slices" / "example.yaml", keys) == []

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
        keys = ruk.key_sets_for("v3")
        findings = ruk.check_file(release / "slices" / "example.yaml", keys)
        assert len(findings) == 1
        assert findings[0].key == "content"
        assert findings[0].where == "slice 'copyright'"
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
        keys = ruk.key_sets_for("v3")
        found = {f.key for f in ruk.check_file(release / "slices" / "example.yaml", keys)}
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
        keys = ruk.key_sets_for("v3")
        findings = ruk.check_file(release / "slices" / "example.yaml", keys)
        assert [f.key for f in findings] == ["symlnk"]

    def test_reports_line_and_column(self, tmp_path):
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
        keys = ruk.key_sets_for("v3")
        (finding,) = ruk.check_file(release / "slices" / "example.yaml", keys)
        assert (finding.line, finding.column) == (6, 9)
        assert "symlnk" in finding.annotation()
        assert finding.annotation().startswith("::error file=")

    def test_v3_essential_accepted_on_v1_rejected_on_v3(self, tmp_path):
        body = """
        package: example
        slices:
          bins:
            essential:
              - libc6_libs
            v3-essential:
              libc6_libs:
                arch: [amd64]
        """
        release = write_release(tmp_path, "v1", example=body)
        path = release / "slices" / "example.yaml"
        assert ruk.check_file(path, ruk.key_sets_for("v1")) == []
        (finding,) = ruk.check_file(path, ruk.key_sets_for("v3"))
        assert finding.key == "v3-essential"

    def test_store_accepted_on_v3_rejected_on_v1(self, tmp_path):
        body = """
        package: example
        store: bin
        default-track: latest
        slices:
          bins:
            contents:
              /usr/bin/example:
        """
        release = write_release(tmp_path, "v3", example=body)
        path = release / "slices" / "example.yaml"
        assert ruk.check_file(path, ruk.key_sets_for("v3")) == []
        found = {f.key for f in ruk.check_file(path, ruk.key_sets_for("v1"))}
        assert found == {"store", "default-track"}

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
        keys = ruk.key_sets_for("v1")
        assert ruk.check_file(release / "slices" / "example.yaml", keys) == []

    def test_unparseable_yaml_is_reported_not_raised(self, tmp_path):
        release = write_release(tmp_path, "v3", broken="package: [unclosed\n")
        keys = ruk.key_sets_for("v3")
        (finding,) = ruk.check_file(release / "slices" / "broken.yaml", keys)
        assert "cannot parse as YAML" in finding.reason

    def test_non_mapping_root_is_reported(self, tmp_path):
        release = write_release(tmp_path, "v3", odd="- a\n- b\n")
        keys = ruk.key_sets_for("v3")
        (finding,) = ruk.check_file(release / "slices" / "odd.yaml", keys)
        assert "top-level mapping" in finding.reason

    def test_empty_file_is_reported(self, tmp_path):
        release = write_release(tmp_path, "v3", empty="")
        keys = ruk.key_sets_for("v3")
        (finding,) = ruk.check_file(release / "slices" / "empty.yaml", keys)
        assert "top-level mapping" in finding.reason


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

    def test_bin_slices_are_not_swept(self, tmp_path):
        # bin-slices/ is deliberately out of scope for now.
        release = write_release(tmp_path, "v3", a=CLEAN_V3)
        bin_slices = release / "bin-slices"
        bin_slices.mkdir()
        (bin_slices / "b.yaml").write_text(CLEAN_V3)
        assert [p.name for p in ruk.resolve_targets(release, [])] == ["a.yaml"]


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

    def test_annotation_is_emitted_on_request(self, tmp_path, capsys):
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
        ruk.main(["--release", str(release), "--annotate"])
        assert "::error file=" in capsys.readouterr().out

    def test_no_annotation_without_the_flag(self, tmp_path, capsys):
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
        ruk.main(["--release", str(release)])
        assert "::error file=" not in capsys.readouterr().out
