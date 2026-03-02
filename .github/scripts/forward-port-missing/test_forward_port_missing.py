#!/usr/bin/env python3
"""
Unit tests for forward_port_missing.py
"""

import pytest

import sys
import os
import gzip
from unittest.mock import patch, MagicMock
from textwrap import dedent
from dataclasses import replace
from copy import deepcopy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import forward_port_missing


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

        get = mock_session.return_value.__enter__.return_value.get

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

        get = mock_session.return_value.__enter__.return_value.get
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

        get = mock_session.return_value.__enter__.return_value.get
        get.side_effect = side_effects
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 0, "PRs that don't add new slices should be ignored"

class TestFetchPackagesInRelease:
    @patch("forward_port_missing.requests.Session")
    def test_fetch_packages_in_release(self, mock_session_class):
        mock_session = MagicMock()
        mock_session_class.return_value.__enter__.return_value = mock_session

        mock_response = MagicMock()
        mock_response.content = gzip.compress(b"Package: foo\n\nPackage: bar\n")
        mock_session.get.return_value = mock_response

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
