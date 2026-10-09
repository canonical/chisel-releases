#!/usr/bin/env python3
"""
Unit tests for project_board_automation.py.
"""

import datetime
import logging
import os
import sys

import pytest

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import project_board_automation as pba

NOW = datetime.datetime(2026, 10, 9, tzinfo=datetime.timezone.utc)
REPO = "canonical/chisel-releases"
TEAM = {"guildie"}


def review(login, state, push=True, teams=()):
    return {
        "state": state,
        "authorCanPushToRepository": push,
        "author": {"login": login},
        "onBehalfOf": {"nodes": [{"slug": t} for t in teams]},
    }


def pr(
    number=1,
    state="OPEN",
    draft=False,
    merged_days_ago=None,
    base="ubuntu-26.10",
    repo=REPO,
    reviews=(),
    requested=(),
):
    merged = NOW - datetime.timedelta(days=merged_days_ago) if merged_days_ago else None
    return {
        "number": number,
        "state": state,
        "isDraft": draft,
        "mergedAt": merged and merged.isoformat(),
        "baseRefName": base,
        "repository": {"nameWithOwner": repo},
        "reviews": {"nodes": list(reviews)},
        "reviewRequests": {"nodes": [{"requestedReviewer": r} for r in requested]},
    }


def item(content, release="ubuntu-26.10", status=pba.AWAITING, archived=False, id="item"):
    return {
        "id": id,
        "isArchived": archived,
        "release": release and {"text": release},
        "status": status and {"name": status},
        "content": content,
    }


OPTIONS = [pba.AWAITING, pba.IN_PROGRESS, pba.PENDING_SECOND, pba.READY]


def project_node(options=OPTIONS):
    """The project as the API returns it."""
    status = {"id": "f-status", "options": [{"id": f"o-{n}", "name": n} for n in options]}
    return {"id": "P", "release": {"id": "f-release"}, "status": status}


PROJECT = {**project_node(), "options": {n: f"o-{n}" for n in OPTIONS}}


@pytest.mark.parametrize(
    "reviews, requested, current, expected",
    [
        ([review("a", "APPROVED"), review("b", "APPROVED")], [], pba.AWAITING, pba.READY),
        # no push access and not in the reviewer team: does not count
        (
            [review("a", "APPROVED"), review("x", "APPROVED", push=False)],
            [],
            pba.AWAITING,
            pba.PENDING_SECOND,
        ),
        # reviewer team member without push access counts, whatever the login case
        (
            [review("a", "APPROVED"), review("Guildie", "APPROVED", push=False)],
            [],
            pba.AWAITING,
            pba.READY,
        ),
        # a re-requested approver is stale, by user or by the team they reviewed for
        (
            [review("a", "APPROVED"), review("b", "APPROVED")],
            [{"login": "b"}],
            pba.READY,
            pba.PENDING_SECOND,
        ),
        (
            [review("a", "APPROVED"), review("b", "APPROVED", teams=["t"])],
            [{"slug": "t"}],
            pba.READY,
            pba.PENDING_SECOND,
        ),
        # the latest decision wins and a later comment does not replace it
        (
            [review("a", "CHANGES_REQUESTED"), review("a", "APPROVED"), review("a", "COMMENTED")],
            [],
            pba.IN_PROGRESS,
            pba.PENDING_SECOND,
        ),
        # a dismissed approval no longer counts
        ([review("a", "APPROVED"), review("a", "DISMISSED")], [], pba.PENDING_SECOND, pba.AWAITING),
        # an unaddressed change request leaves the status to the built-in workflow
        ([review("a", "APPROVED"), review("b", "CHANGES_REQUESTED")], [], pba.IN_PROGRESS, None),
        # once re-requested, it is addressed; no approvals left -> back to awaiting
        ([review("b", "CHANGES_REQUESTED")], [{"login": "b"}], pba.IN_PROGRESS, pba.AWAITING),
        ([], [], pba.AWAITING, None),
    ],
)
def test_target_status(reviews, requested, current, expected):
    assert pba.target_status(pr(reviews=reviews, requested=requested), current, TEAM) == expected


@pytest.mark.parametrize(
    "board_item, expected",
    [
        (item(pr(state="CLOSED")), ["remove (closed)"]),
        (item(pr(draft=True)), ["remove (draft)"]),
        (item(pr(state="MERGED", merged_days_ago=30)), ["archive"]),
        (item(pr(state="MERGED", merged_days_ago=2)), []),
        (item(pr(state="MERGED", merged_days_ago=30), archived=True), []),
        (item(pr(base="ubuntu-24.04"), release=None), ["release -> ubuntu-24.04"]),
        (item(pr(reviews=[review("a", "APPROVED")]), status=pba.PENDING_SECOND), []),
    ],
)
def test_plan(board_item, expected):
    descriptions = [d for d, _, _ in pba.plan(board_item, PROJECT, TEAM, NOW)]
    assert [d.split(" (merged")[0] for d in descriptions] == expected


class FakeGitHub:
    """Serves the project, the team and the items in pages of 2; records mutations."""

    def __init__(self, items, project=project_node(), team=("Guildie",), fail=()):
        self.items, self.project, self.team, self.fail = items, project, team, set(fail)
        self.mutations = []

    def __call__(self, query, variables):
        if query is pba.PROJECT_QUERY:
            return {"organization": {"projectV2": self.project}}
        if query is pba.TEAM_QUERY:
            members = self.team is not None and {
                "pageInfo": {"hasNextPage": False, "endCursor": None},
                "nodes": [{"login": login} for login in self.team],
            }
            return {"organization": {"team": members and {"members": members}}}
        if query is pba.ITEMS_QUERY:
            start = int(variables["cursor"] or 0)
            end = start + 2
            return {
                "node": {
                    "items": {
                        "pageInfo": {"hasNextPage": end < len(self.items), "endCursor": str(end)},
                        "nodes": self.items[start:end],
                    }
                }
            }
        if variables["itemId"] in self.fail:
            raise RuntimeError("boom")
        self.mutations.append((variables["itemId"], variables.get("value")))
        return {}


@pytest.fixture
def github(monkeypatch):
    def install(*args, **kwargs):
        fake = FakeGitHub(*args, **kwargs)
        monkeypatch.setattr(pba, "graphql", fake)
        return fake

    return install


def test_sync_applies_only_this_repository_across_pages(github):
    fake = github(
        [
            item(
                pr(1, reviews=[review("a", "APPROVED"), review("b", "APPROVED")]),
                release=None,
                id="mine",
            ),
            item(pr(2, repo="canonical/other", state="CLOSED"), id="theirs"),
            item({}, id="not-a-pr"),
            item(pr(3, state="CLOSED"), id="closed"),
        ]
    )
    assert pba.sync(REPO, apply=True, now=NOW) == 0
    assert fake.mutations == [
        ("mine", {"text": "ubuntu-26.10"}),
        ("mine", {"singleSelectOptionId": f"o-{pba.READY}"}),
        ("closed", None),
    ]


def test_sync_dry_run_writes_nothing(github, caplog):
    caplog.set_level(logging.INFO)
    fake = github([item(pr(state="CLOSED"))])
    assert pba.sync(REPO, apply=False, now=NOW) == 0
    assert fake.mutations == []
    assert "PR #1: remove (closed)" in caplog.text and "(dry run)" in caplog.text


def test_sync_failed_item_does_not_stop_the_rest(github, caplog):
    fake = github([item(pr(n, state="CLOSED"), id=f"i{n}") for n in (1, 2, 3)], fail={"i2"})
    assert pba.sync(REPO, apply=True, now=NOW) == 1
    assert [i for i, _ in fake.mutations] == ["i1", "i3"]
    assert "PR #2: failed: boom" in caplog.text


@pytest.mark.parametrize(
    "setup, error",
    [
        ({"project": None}, "Project canonical/161 not found"),
        ({"team": None}, "Team canonical/slice-reviewers-guild not found"),
        ({"project": project_node(options=[pba.AWAITING])}, "Status options missing"),
    ],
)
def test_sync_setup_errors(github, setup, error):
    github([], **setup)
    with pytest.raises(RuntimeError, match=error):
        pba.sync(REPO, apply=True, now=NOW)
