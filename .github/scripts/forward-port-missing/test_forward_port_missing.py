#!/usr/bin/env python3
"""
Unit tests for forward_port_missing.py
"""

import gzip
import os
import sys
from copy import deepcopy
from dataclasses import replace
from textwrap import dedent
from unittest.mock import MagicMock, patch

import pytest

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import forward_port_missing


def _mock_session_get(mock_session_class: MagicMock) -> MagicMock:
    """Extract the `get` mock from a patched requests.Session class."""
    return mock_session_class.return_value.__enter__.return_value.get


class TestFetchPRs:
    json_response = [
        {
            "number": 1,
            "base": {"ref": "ubuntu-20.04"},
            "labels": [{"name": "bug"}],
            "diff_url": "http://example.com/diff1",
            "draft": False,
        }
    ]

    diff_text = dedent("""
    diff --git a/slices/foo.yaml b/slices/foo.yaml
    new file mode 100644
    index 0000000..1111111
    --- /dev/null
    +++ b/slices/foo.yaml
    @@ -0,0 +1,2 @@
    +name: foo
    +hint: A test slice
    """).strip()

    @staticmethod
    def make_side_effects(json_response: list[dict], diff_text: str) -> list[MagicMock]:
        return [
            MagicMock(json=MagicMock(return_value=json_response)),  # PR list response
            MagicMock(text=diff_text),  # Diff response
        ]

    @patch("forward_port_missing.requests.Session")
    def test_basic(self, mock_session: MagicMock) -> None:

        side_effects: list[MagicMock] = self.make_side_effects(
            self.json_response, self.diff_text
        )

        get = _mock_session_get(mock_session)
        get.side_effect = side_effects
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 1
        pr = next(iter(prs))
        assert pr.number == 1
        assert pr.branch == "ubuntu-20.04"
        assert pr.new_slices == frozenset(["foo"])

        # check that supported_branches filtering works
        get.side_effect = side_effects
        prs = forward_port_missing.fetch_prs({"ubuntu-20.04"})
        assert len(prs) == 1
        assert next(iter(prs)) == pr

        get.side_effect = side_effects
        prs = forward_port_missing.fetch_prs({"ubuntu-22.04"})
        assert len(prs) == 0

    @patch("forward_port_missing.requests.Session")
    def test_draft(self, mock_session: MagicMock) -> None:
        json_response = self.json_response.copy()
        json_response[0]["draft"] = True

        side_effects: list[MagicMock] = self.make_side_effects(
            json_response, self.diff_text
        )

        get = _mock_session_get(mock_session)
        get.side_effect = side_effects
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 0, "Draft PRs should be ignored"

    @patch("forward_port_missing.requests.Session")
    def test_no_new_slices(self, mock_session: MagicMock) -> None:
        diff_text = dedent("""
        diff --git a/slices/foo.yaml b/slices/foo.yaml
        index 1111111..2222222
        --- a/slices/foo.yaml
        +++ b/slices/foo.yaml
        @@ -1,2 +1,2 @@
         name: foo
         hint: A test slice
        """).strip()

        side_effects: list[MagicMock] = self.make_side_effects(
            self.json_response, diff_text
        )

        get = _mock_session_get(mock_session)
        get.side_effect = side_effects
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 0, "PRs that don't add new slices should be ignored"


class TestFetchPackagesInRelease:
    @patch("forward_port_missing.requests.Session")
    def test_fetch_packages_in_release(self, mock_session_class):
        get = _mock_session_get(mock_session_class)

        mock_response = MagicMock()
        mock_response.content = gzip.compress(b"Package: foo\n\nPackage: bar\n")
        get.return_value = mock_response

        result = forward_port_missing.fetch_packages_in_release(
            {"ubuntu-22.04": "jammy"}
        )

        assert "ubuntu-22.04" in result
        assert "foo" in result["ubuntu-22.04"]


class TestDetermineForwardPortingStatus:
    pr: forward_port_missing.PR = forward_port_missing.PR(
        number=1,
        labels=frozenset(),
        new_slices=frozenset(["foo"]),
        branch="ubuntu-20.04",
    )

    slices_per_branch: dict[str, set[str]] = {
        "ubuntu-20.04": {"existing"},
        "ubuntu-22.04": {"existing"},
        "ubuntu-24.04": {"existing"},
    }

    with_and_without_labels = pytest.mark.parametrize(
        "labels",
        [
            frozenset(),
            frozenset([forward_port_missing.FORWARD_PORT_MISSING_LABEL]),
        ],
    )

    @with_and_without_labels
    def test_slices_already_exists(self, labels: frozenset[str]) -> None:
        """Slices for that package already exist in the future branches"""
        prs = {replace(self.pr, labels=labels)}
        slices_per_branch = deepcopy(self.slices_per_branch)
        slices_per_branch["ubuntu-22.04"].add("foo")
        slices_per_branch["ubuntu-24.04"].add("foo")

        to_add, to_remove = forward_port_missing.determine_forward_porting_status(
            prs=prs, slices_per_branch=slices_per_branch
        )

        assert to_add == set()
        assert to_remove == ({1} if labels else set())

    @with_and_without_labels
    def test_slices_missing(self, labels: frozenset[str]) -> None:
        """Slices for that package are missing in the future branches"""
        prs = {replace(self.pr, labels=labels)}
        slices_per_branch = deepcopy(self.slices_per_branch)

        to_add, to_remove = forward_port_missing.determine_forward_porting_status(
            prs=prs,
            slices_per_branch=slices_per_branch,
        )

        assert to_add == (set() if labels else {1})
        assert to_remove == set()

    @with_and_without_labels
    def test_slices_partially_exists(self, labels: frozenset[str]) -> None:
        """Slices for that package exist in some future branches but not all"""
        prs = {replace(self.pr, labels=labels)}
        slices_per_branch = deepcopy(self.slices_per_branch)
        slices_per_branch["ubuntu-22.04"].add("foo")

        to_add, to_remove = forward_port_missing.determine_forward_porting_status(
            prs=prs,
            slices_per_branch=slices_per_branch,
        )

        assert to_add == (set() if labels else {1})
        assert to_remove == set()

    @with_and_without_labels
    def test_slices_partially_exists_gap(self, labels: frozenset[str]) -> None:
        """Slices for that package exist in a later branch but are missing in an intermediate one"""
        prs = {replace(self.pr, labels=labels)}
        slices_per_branch = deepcopy(self.slices_per_branch)
        slices_per_branch["ubuntu-24.04"].add("foo")

        to_add, to_remove = forward_port_missing.determine_forward_porting_status(
            prs=prs,
            slices_per_branch=slices_per_branch,
        )

        assert to_add == (set() if labels else {1})
        assert to_remove == set()

    @with_and_without_labels
    def test_slices_missing_but_other_prs_exist(self, labels: frozenset[str]) -> None:
        """Slices for that package do not exist, but there are other PRs which add slices to the future branches"""
        prs = {
            replace(self.pr, labels=labels),
            replace(self.pr, number=2, branch="ubuntu-22.04"),
            replace(self.pr, number=3, branch="ubuntu-24.04"),
        }
        slices_per_branch = deepcopy(self.slices_per_branch)

        to_add, to_remove = forward_port_missing.determine_forward_porting_status(
            prs=prs,
            slices_per_branch=slices_per_branch,
        )

        assert to_add == set()
        assert to_remove == ({1} if labels else set())

    @with_and_without_labels
    def test_slices_missing_but_other_prs_exist_but_different_slices(
        self, labels: frozenset[str]
    ) -> None:
        """Slices for that package do not exist, but there are other PRs which add different slices to the future branches"""
        prs = {
            replace(self.pr, labels=labels),
            replace(
                self.pr,
                number=2,
                branch="ubuntu-22.04",
                new_slices=frozenset(["bar"]),
            ),
            replace(
                self.pr,
                number=3,
                branch="ubuntu-24.04",
                new_slices=frozenset(["bar"]),
            ),
        }
        slices_per_branch = deepcopy(self.slices_per_branch)

        to_add, to_remove = forward_port_missing.determine_forward_porting_status(
            prs=prs,
            slices_per_branch=slices_per_branch,
        )

        assert to_add == (set() if labels else {1})
        assert to_remove == set()

    @with_and_without_labels
    def test_slices_missing_but_discontinued_in_all(
        self, labels: frozenset[str]
    ) -> None:
        """Slices for that package do not exist, but the package is discontinued in all future branches"""
        prs = {replace(self.pr, labels=labels)}
        slices_per_branch = deepcopy(self.slices_per_branch)
        packages_by_release = {
            "ubuntu-20.04": {"foo", "bar", "baz"},
            "ubuntu-22.04": {"bar", "baz"},  # foo discontinued
            "ubuntu-24.04": {"bar", "baz"},  # foo discontinued
        }

        to_add, to_remove = forward_port_missing.determine_forward_porting_status(
            prs=prs,
            slices_per_branch=slices_per_branch,
            packages_by_release=packages_by_release,
        )

        assert to_add == set()
        assert to_remove == ({1} if labels else set())

    @with_and_without_labels
    def test_slices_missing_but_discontinued_only_in_some(
        self, labels: frozenset[str]
    ) -> None:
        """Slices for that package do not exist, but the package is discontinued in some future branches but not all"""
        prs = {replace(self.pr, labels=labels)}
        slices_per_branch = deepcopy(self.slices_per_branch)
        packages_by_release = {
            "ubuntu-20.04": {"foo", "bar", "baz"},
            "ubuntu-22.04": {"foo", "bar", "baz"},  # foo not yet discontinued
            "ubuntu-24.04": {"bar", "baz"},  # foo discontinued
        }

        to_add, to_remove = forward_port_missing.determine_forward_porting_status(
            prs=prs,
            slices_per_branch=slices_per_branch,
            packages_by_release=packages_by_release,
        )

        assert to_add == (set() if labels else {1})
        assert to_remove == set()


class TestBinSlices:
    """Bin SDFs ("store: bin") are excluded from forward port tracking;
    regular SDFs are not."""

    @staticmethod
    def _make_diff(filepath: str, content: str) -> str:
        return dedent(f"""
        diff --git a/{filepath} b/{filepath}
        new file mode 100644
        index 0000000..1111111
        --- /dev/null
        +++ b/{filepath}
        @@ -0,0 +1,2 @@
        {content}
        """).strip()

    json_response = [
        {
            "number": 1,
            "base": {"ref": "ubuntu-26.04"},
            "labels": [{"name": "bug"}],
            "diff_url": "http://example.com/diff1",
            "draft": False,
        }
    ]

    @patch("forward_port_missing.requests.Session")
    def test_bin_sdf_in_slices_ignored(self, mock_session: MagicMock) -> None:
        """PRs adding bin SDFs (store: bin) in slices/ must not be tracked"""
        diff_text = self._make_diff("slices/foo.yaml", "+package: foo\n+store: bin")

        get = _mock_session_get(mock_session)
        get.side_effect = TestFetchPRs.make_side_effects(self.json_response, diff_text)
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 0, "bin SDFs in slices/ should be ignored"

    @patch("forward_port_missing.requests.Session")
    def test_bin_sdf_in_bin_slices_dir_ignored(self, mock_session: MagicMock) -> None:
        """PRs adding SDFs under bin-slices/ must not be tracked"""
        diff_text = self._make_diff("bin-slices/foo.yaml", "+package: foo\n+store: bin")

        get = _mock_session_get(mock_session)
        get.side_effect = TestFetchPRs.make_side_effects(self.json_response, diff_text)
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 0, "bin-slices/ SDFs should be ignored"

    @patch("forward_port_missing.requests.Session")
    def test_deb_sdf_in_slices_tracked(self, mock_session: MagicMock) -> None:
        """PRs adding regular deb SDFs under slices/ must still be tracked"""
        diff_text = self._make_diff("slices/foo.yaml", "+package: foo")

        get = _mock_session_get(mock_session)
        get.side_effect = TestFetchPRs.make_side_effects(self.json_response, diff_text)
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 1
        pr = next(iter(prs))
        assert pr.new_slices == frozenset(["foo"])

    @patch("forward_port_missing.requests.Session")
    def test_deb_sdf_misplaced_in_bin_slices_not_tracked(
        self, mock_session: MagicMock
    ) -> None:
        """A deb SDF under bin-slices/ is not tracked (the directory is not
        scanned for forward porting)."""
        diff_text = self._make_diff("bin-slices/foo.yaml", "+package: foo")

        get = _mock_session_get(mock_session)
        get.side_effect = TestFetchPRs.make_side_effects(self.json_response, diff_text)
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 0, "bin-slices/ is not scanned for forward porting"

    def test_diff_adds_bin_store(self) -> None:
        """Test the _diff_adds_bin_store() helper directly"""
        diff_text = self._make_diff("slices/foo.yaml", "+package: foo\n+store: bin")
        assert forward_port_missing._diff_adds_bin_store(diff_text, "slices/foo.yaml")

        # deb SDF (no store key)
        diff_text = self._make_diff("slices/foo.yaml", "+package: foo")
        assert not forward_port_missing._diff_adds_bin_store(
            diff_text, "slices/foo.yaml"
        )

        # nested "store" key must not match (only top-level counts)
        diff_text = self._make_diff("slices/foo.yaml", "+package: foo\n+  store: bin")
        assert not forward_port_missing._diff_adds_bin_store(
            diff_text, "slices/foo.yaml"
        )

        # file not in the diff
        assert not forward_port_missing._diff_adds_bin_store(
            diff_text, "slices/bar.yaml"
        )
