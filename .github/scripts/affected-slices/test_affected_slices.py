#!/usr/bin/env python3
"""
Unit tests for affected_slices.py
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from textwrap import dedent

import pytest

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import affected_slices


def parse(text: str) -> dict[str, dict]:
    return affected_slices.parse_sdf(dedent(text))[1]


LIB_SDF = """
    package: lib
    essential:
      - lib_copyright
    slices:
      libs:
        essential:
          - base_files
        contents:
          /usr/lib/liblib.so.1:
      copyright:
        contents:
          /usr/share/doc/lib/copyright:
"""


class TestParseSDF:
    def test_package_and_slice_keys(self):
        package, slices = affected_slices.parse_sdf(dedent(LIB_SDF))
        assert package == "lib"
        assert set(slices) == {"lib_libs", "lib_copyright"}

    def test_no_slices(self):
        assert parse("package: lib\n") == {}

    def test_essential_list_and_map_are_equal(self):
        as_list = parse("""
            package: lib
            slices:
              libs:
                essential:
                  - base_files
        """)
        as_map = parse("""
            package: lib
            slices:
              libs:
                essential:
                  base_files:
        """)
        assert as_list == as_map

    def test_hint_is_ignored(self):
        with_hint = parse("""
            package: lib
            slices:
              libs:
                hint: Shared library
                contents:
                  /usr/lib/liblib.so.1:
        """)
        without_hint = parse("""
            package: lib
            slices:
              libs:
                contents:
                  /usr/lib/liblib.so.1:
        """)
        assert with_hint == without_hint

    def test_formatting_is_ignored(self):
        reformatted = parse("""
            # a comment
            package: lib
            slices:
              copyright:
                contents:
                  /usr/share/doc/lib/copyright:
              libs:
                contents: {/usr/lib/liblib.so.1: }
                essential: [base_files]
            essential: [lib_copyright]
        """)
        assert reformatted == parse(LIB_SDF)

    def test_dependencies(self):
        slices = parse("""
            package: lib
            essential:
              - lib_copyright
            v3-essential:
              base_passwd: {arch: amd64}
            slices:
              libs:
                essential:
                  base_files:
                v3-essential:
                  libc6_libs: {arch: [amd64, arm64]}
              copyright:
        """)
        assert affected_slices.dependencies(slices["lib_libs"]) == {
            "lib_copyright",
            "base_passwd",
            "base_files",
            "libc6_libs",
        }
        assert affected_slices.dependencies(slices["lib_copyright"]) == {
            "lib_copyright",
            "base_passwd",
        }


class TestChangedSlices:
    def test_added_removed_and_modified(self):
        base = {"a_x": {"v": 1}, "b_x": {"v": 1}, "c_x": {"v": 1}}
        head = {"a_x": {"v": 1}, "b_x": {"v": 2}, "d_x": {"v": 1}}
        assert affected_slices.changed_slices(base, head) == {"b_x", "c_x", "d_x"}

    def test_package_field_changes_every_slice(self):
        base = parse(LIB_SDF)
        head = parse(LIB_SDF.replace("package: lib", "package: lib\n    archive: pro"))
        assert affected_slices.changed_slices(base, head) == {
            "lib_libs",
            "lib_copyright",
        }


def slice_with(*essential: str) -> dict:
    return {"package": {}, "slice": {"essential": dict.fromkeys(essential)}}


class TestAffectedSlices:
    head = {
        "a_libs": slice_with(),
        "b_libs": slice_with("a_libs"),
        "c_bins": slice_with("b_libs"),
        "d_bins": slice_with(),
    }

    def test_transitive_dependents(self):
        affected = affected_slices.affected_slices(self.head, {"a_libs"})
        assert affected == {"a_libs", "b_libs", "c_bins"}

    def test_leaf(self):
        assert affected_slices.affected_slices(self.head, {"c_bins"}) == {"c_bins"}

    def test_removed_slice_with_dangling_dependent(self):
        head = {**self.head, "e_bins": slice_with("gone_libs")}
        assert affected_slices.affected_slices(head, {"gone_libs"}) == {"e_bins"}

    def test_removed_leaf(self):
        assert affected_slices.affected_slices(self.head, {"gone_libs"}) == set()


def git(repo: Path, *args: str) -> str:
    return affected_slices.git(repo, *args).strip()


@pytest.fixture
def repo(tmp_path: Path) -> tuple[Path, str]:
    """A release with the base revision committed, returning the path and the
    base commit."""
    files = {
        "chisel.yaml": "format: v3\n",
        ".github/workflows/ci.yaml": "name: CI\n",
        "slices/lib.yaml": LIB_SDF,
        "slices/app.yaml": """
            package: app
            slices:
              bins:
                essential:
                  - lib_libs
                contents:
                  /usr/bin/app:
        """,
        "slices/nested/other.yaml": """
            package: other
            slices:
              bins:
                contents:
                  /usr/bin/other:
        """,
    }
    for path, content in files.items():
        write(tmp_path, path, content)

    git(tmp_path, "init", "--quiet")
    git(tmp_path, "add", "--all")
    tree = git(tmp_path, "write-tree")
    # commit-tree doesn't run hooks or need a checked-out branch.
    base = git(
        tmp_path,
        "-c", "user.name=test",
        "-c", "user.email=test@example.com",
        "commit-tree", "--no-gpg-sign", tree, "-m", "base",
    )
    return tmp_path, base


def write(repo: Path, path: str, content: str) -> None:
    (repo / path).parent.mkdir(parents=True, exist_ok=True)
    (repo / path).write_text(dedent(content))


def stage(repo: Path) -> None:
    git(repo, "add", "--all")


class TestFindAffected:
    def test_no_changes(self, repo):
        release, base = repo
        assert affected_slices.find_affected(release, base) == {
            "all": False,
            "changed_slices": [],
            "affected_slices": [],
            "packages": [],
            "files": [],
        }

    def test_modified_slice_affects_dependents(self, repo):
        release, base = repo
        write(release, "slices/lib.yaml", LIB_SDF.replace("so.1", "so.2"))
        stage(release)
        result = affected_slices.find_affected(release, base)
        assert result["changed_slices"] == ["lib_libs"]
        assert result["affected_slices"] == ["app_bins", "lib_libs"]
        assert result["packages"] == ["app", "lib"]
        assert result["files"] == ["slices/app.yaml", "slices/lib.yaml"]
        assert result["all"] is False

    def test_hint_only_change(self, repo):
        release, base = repo
        sdf = LIB_SDF.replace("libs:\n", "libs:\n        hint: Shared library\n")
        write(release, "slices/lib.yaml", sdf)
        stage(release)
        assert affected_slices.find_affected(release, base)["changed_slices"] == []

    def test_removed_sdf_with_dangling_dependent(self, repo):
        release, base = repo
        (release / "slices/lib.yaml").unlink()
        stage(release)
        result = affected_slices.find_affected(release, base)
        assert result["changed_slices"] == ["lib_copyright", "lib_libs"]
        assert result["affected_slices"] == ["app_bins"]
        assert result["files"] == ["slices/app.yaml"]

    def test_removed_sdf_and_dependency(self, repo):
        release, base = repo
        (release / "slices/lib.yaml").unlink()
        write(release, "slices/app.yaml", """
            package: app
            slices:
              bins:
                contents:
                  /usr/bin/app:
        """)
        stage(release)
        result = affected_slices.find_affected(release, base)
        assert result["changed_slices"] == ["app_bins", "lib_copyright", "lib_libs"]
        assert result["files"] == ["slices/app.yaml"]

    def test_added_nested_sdf(self, repo):
        release, base = repo
        write(release, "slices/nested/new.yaml", """
            package: new
            slices:
              bins:
                essential:
                  - other_bins
        """)
        stage(release)
        result = affected_slices.find_affected(release, base)
        assert result["changed_slices"] == ["new_bins"]
        assert result["files"] == ["slices/nested/new.yaml"]

    def test_moved_sdf(self, repo):
        release, base = repo
        (release / "slices/nested/other.yaml").rename(release / "slices/other.yaml")
        stage(release)
        assert affected_slices.find_affected(release, base)["changed_slices"] == []

    all_files = ["slices/app.yaml", "slices/lib.yaml", "slices/nested/other.yaml"]

    @pytest.mark.parametrize("path", ["chisel.yaml", ".github/workflows/ci.yaml"])
    def test_all(self, repo, path):
        release, base = repo
        write(release, path, "changed: true\n")
        stage(release)
        result = affected_slices.find_affected(release, base)
        assert result["all"] is True
        assert result["changed_slices"] == []
        assert result["packages"] == ["app", "lib", "other"]
        assert result["files"] == self.all_files

    def test_no_base(self, repo):
        release, _ = repo
        write(release, "slices/lib.yaml", LIB_SDF.replace("so.1", "so.2"))
        result = affected_slices.find_affected(release, None)
        assert result["all"] is True
        assert result["changed_slices"] == []
        assert result["files"] == self.all_files

    @pytest.mark.parametrize(
        "extra_args, files",
        [
            ([], ["slices/app.yaml", "slices/lib.yaml"]),
            (["--all="], ["slices/app.yaml", "slices/lib.yaml"]),
            (["--all=false"], ["slices/app.yaml", "slices/lib.yaml"]),
            (["--all=true"], all_files),
        ],
    )
    def test_cli(self, repo, extra_args, files):
        release, base = repo
        write(release, "slices/lib.yaml", LIB_SDF.replace("so.1", "so.2"))
        stage(release)
        script = Path(affected_slices.__file__)
        out = subprocess.run(
            [sys.executable, script, "--release", release, "--base", base, *extra_args],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        assert json.loads(out)["files"] == files
