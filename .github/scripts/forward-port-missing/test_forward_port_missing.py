#!/usr/bin/env python3
"""
Unit tests for forward_port_missing.py
"""

import pytest
import requests

import sys
import os
import gzip
from unittest.mock import patch, MagicMock
from textwrap import dedent
from dataclasses import replace
from copy import deepcopy

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
            "draft": False,
        }
    ]

    files = [{"filename": "slices/foo.yaml", "status": "added"}]

    @staticmethod
    def make_side_effects(json_response: list[dict], *file_pages: list[dict]) -> list[MagicMock]:
        return [
            MagicMock(json=MagicMock(return_value=json_response)),  # PR list response
            *(MagicMock(json=MagicMock(return_value=page)) for page in file_pages),  # PR files
        ]

    @patch("forward_port_missing.requests.Session")
    def test_basic(self, mock_session: MagicMock) -> None:

        side_effects: list[MagicMock] = self.make_side_effects(
            self.json_response, self.files
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
        json_response = deepcopy(self.json_response)
        json_response[0]["draft"] = True

        side_effects: list[MagicMock] = self.make_side_effects(
            json_response, self.files
        )

        get = _mock_session_get(mock_session)
        get.side_effect = side_effects
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 0, "Draft PRs should be ignored"

    @patch("forward_port_missing.requests.Session")
    def test_no_new_slices(self, mock_session: MagicMock) -> None:
        files = [{"filename": "slices/foo.yaml", "status": "modified"}]

        side_effects: list[MagicMock] = self.make_side_effects(
            self.json_response, files
        )

        get = _mock_session_get(mock_session)
        get.side_effect = side_effects
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 0, "PRs that don't add new slices should be ignored"

    @patch("forward_port_missing.requests.Session")
    def test_only_added_slice_definitions(self, mock_session: MagicMock) -> None:
        files = [
            {"filename": "slices/foo.yaml", "status": "added"},
            {"filename": "slices/bar.yaml", "status": "renamed"},
            {"filename": "slices/baz.yaml", "status": "removed"},
            {"filename": "slices/sub/qux.yaml", "status": "added"},
            {"filename": "slices/notes.txt", "status": "added"},
            {"filename": "tests/spread/integration/foo/task.yaml", "status": "added"},
        ]

        get = _mock_session_get(mock_session)
        get.side_effect = self.make_side_effects(self.json_response, files)
        prs = forward_port_missing.fetch_prs()

        assert len(prs) == 1
        assert next(iter(prs)).new_slices == frozenset(["foo"])

    @patch("forward_port_missing.requests.Session")
    def test_files_pagination(self, mock_session: MagicMock) -> None:
        first_page = [{"filename": f"tests/file{i}", "status": "added"} for i in range(100)]
        second_page = [{"filename": "slices/foo.yaml", "status": "added"}]

        get = _mock_session_get(mock_session)
        get.side_effect = self.make_side_effects(self.json_response, first_page, second_page)
        prs = forward_port_missing.fetch_prs()

        assert next(iter(prs)).new_slices == frozenset(["foo"])
        assert get.call_count == 3, "PR list, then two pages of files"

    @patch("forward_port_missing.requests.Session")
    def test_files_error_fails(self, mock_session: MagicMock) -> None:
        failing = MagicMock(
            raise_for_status=MagicMock(side_effect=requests.HTTPError("429 Too Many Requests"))
        )

        get = _mock_session_get(mock_session)
        get.side_effect = [MagicMock(json=MagicMock(return_value=self.json_response)), failing]

        with pytest.raises(requests.HTTPError):
            forward_port_missing.fetch_prs()


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
