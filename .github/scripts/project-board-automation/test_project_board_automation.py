#!/usr/bin/env python3
"""
Unit tests for project_board_automation.py.
"""

import datetime
import inspect
import json
import logging
import os
import re
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
        "id": f"PR{number}",
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


OPTIONS = sorted(pba.STATUSES)


def project_node(options=OPTIONS, release="TEXT"):
    """The project as the API returns it."""
    status = {"id": "f-status", "options": [{"id": f"o-{n}", "name": n} for n in options]}
    return {"id": "P", "release": {"id": "f-release", "dataType": release}, "status": status}


PROJECT = {**project_node(), "options": {n: f"o-{n}" for n in OPTIONS}}


def test_mutations_only_touch_the_board():
    """The script juggles board items; the repository and its PRs stay read-only."""
    mutations = re.findall(r"mutation\([^)]*\)\s*\{\s*(\w+)\(", inspect.getsource(pba))
    assert mutations and all("ProjectV2" in m for m in mutations), mutations


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
        # reviews come oldest first, so a later change request overrides an approval
        (
            [review("a", "APPROVED"), review("a", "CHANGES_REQUESTED")],
            [],
            pba.READY,
            pba.IN_PROGRESS,
        ),
        # a dismissed approval no longer counts
        ([review("a", "APPROVED"), review("a", "DISMISSED")], [], pba.PENDING_SECOND, pba.AWAITING),
        # an unaddressed change request wins over approvals
        (
            [review("a", "APPROVED"), review("b", "CHANGES_REQUESTED")],
            [],
            pba.READY,
            pba.IN_PROGRESS,
        ),
        # unless it comes from someone whose reviews do not count, e.g. a reviewer who
        # has left: that would park the PR with nobody to clear it
        (
            [review("a", "APPROVED"), review("x", "CHANGES_REQUESTED", push=False)],
            [],
            pba.READY,
            pba.PENDING_SECOND,
        ),
        ([review("Guildie", "CHANGES_REQUESTED", push=False)], [], pba.AWAITING, pba.IN_PROGRESS),
        # once re-requested, it is addressed; no approvals left -> back to awaiting
        ([review("b", "CHANGES_REQUESTED")], [{"login": "b"}], pba.IN_PROGRESS, pba.AWAITING),
        (
            [review("b", "CHANGES_REQUESTED", teams=["t"])],
            [{"slug": "t"}],
            pba.IN_PROGRESS,
            pba.AWAITING,
        ),
        # Merged on an open PR can only be a mistake
        ([], [], pba.MERGED, pba.AWAITING),
        ([], [], pba.AWAITING, None),
        # a status set by hand stays
        ([], [], "Blocked", None),
        # a new item gets a status from its reviews
        ([], [], None, pba.AWAITING),
        ([review("a", "APPROVED")], [], None, pba.PENDING_SECOND),
        ([review("a", "APPROVED"), review("b", "APPROVED")], [], None, pba.READY),
        ([review("b", "CHANGES_REQUESTED")], [], None, pba.IN_PROGRESS),
    ],
)
def test_target_status(reviews, requested, current, expected):
    assert pba.target_status(pr(reviews=reviews, requested=requested), current, TEAM) == expected


@pytest.mark.parametrize(
    "board_item, expected",
    [
        (item(pr(state="CLOSED")), ["remove (closed)"]),
        (item(pr(draft=True)), ["remove (draft)"]),
        (item(pr(state="MERGED", merged_days_ago=30)), ["status -> Merged", "archive"]),
        (item(pr(state="MERGED", merged_days_ago=30), status=pba.MERGED), ["archive"]),
        (item(pr(state="MERGED", merged_days_ago=2)), ["status -> Merged"]),
        (item(pr(state="MERGED", merged_days_ago=2), status=pba.MERGED), []),
        (item(pr(state="MERGED", merged_days_ago=30), archived=True), []),
        # as GitHub writes the timestamp
        (
            item({**pr(state="MERGED"), "mergedAt": "2026-10-01T00:00:00Z"}),
            ["status -> Merged", "archive"],
        ),
        # archived by hand: left alone
        (item(pr(), archived=True, release=None, status=None), []),
        (item(pr(base="ubuntu-24.04"), release=None), ["release -> ubuntu-24.04"]),
        (item(pr(reviews=[review("a", "APPROVED")]), status=pba.PENDING_SECOND), []),
        # a freshly added item gets both fields in one go
        (
            item(pr(reviews=[review("a", "APPROVED")]), release=None, status=None),
            ["release -> ubuntu-26.10", "status -> Pending Second Review"],
        ),
    ],
)
def test_plan(board_item, expected):
    descriptions = [d for d, _, _ in pba.plan(board_item, PROJECT, TEAM, NOW)]
    assert [re.sub(r" \((was|merged) .*\)$", "", d) for d in descriptions] == expected


class FakeGitHub:
    """Serves the project, the team, the items and the open PRs in pages of 2; records
    mutations as (item id, value), with "add:<pr id>" for additions."""

    def __init__(
        self, items, pulls=(), project=project_node(), team=("Guildie",), fail=(), existing=None
    ):
        self.items, self.pulls, self.project = items, list(pulls), project
        self.team, self.fail = team, set(fail)
        self.existing = existing or {}  # PR id -> the item the add call finds there already
        self.mutations = []

    @staticmethod
    def page(nodes, variables):
        start = int(variables["cursor"] or 0)
        end = start + 2
        return {
            "pageInfo": {"hasNextPage": end < len(nodes), "endCursor": str(end)},
            "nodes": nodes[start:end],
        }

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
            return {"node": {"items": self.page(self.items, variables)}}
        if query is pba.OPEN_PRS_QUERY:
            return {"repository": {"pullRequests": self.page(self.pulls, variables)}}
        if query is pba.ADD:
            cid = variables["contentId"]
            if cid in self.fail:
                raise RuntimeError("boom")
            self.mutations.append((f"add:{cid}", None))
            new = {"id": f"new-{cid}", "isArchived": False, "release": None, "status": None}
            return {"addProjectV2ItemById": {"item": self.existing.get(cid, new)}}
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


def test_sync_adds_open_prs_and_configures_them_in_one_run(github):
    on_board = pr(1, reviews=[review("a", "APPROVED")])
    fake = github(
        [item(on_board, status=pba.PENDING_SECOND)],
        pulls=[on_board, pr(2, draft=True), pr(3, reviews=[review("a", "APPROVED")])],
    )
    assert pba.sync(REPO, apply=True, now=NOW) == 0
    assert fake.mutations == [
        ("add:PR3", None),
        ("new-PR3", {"text": "ubuntu-26.10"}),
        ("new-PR3", {"singleSelectOptionId": f"o-{pba.PENDING_SECOND}"}),
    ]


def test_sync_add_failure_does_not_stop_the_rest(github, caplog):
    fake = github([], pulls=[pr(3), pr(4)], fail={"PR3"})
    assert pba.sync(REPO, apply=True, now=NOW) == 1
    assert [i for i, _ in fake.mutations] == ["add:PR4", "new-PR4", "new-PR4"]
    assert "PR #3: failed: boom" in caplog.text


def test_sync_keeps_the_fields_of_an_item_added_since_the_board_was_read(github):
    on_board = {"id": "old", "isArchived": False, "release": {"text": "ubuntu-26.10"}}
    fake = github([], pulls=[pr(3)], existing={"PR3": {**on_board, "status": {"name": "Blocked"}}})
    assert pba.sync(REPO, apply=True, now=NOW) == 0
    assert fake.mutations == [("add:PR3", None)]


def test_sync_draft_round_trip_resets_a_hand_set_status(github):
    """ready -> draft removes the item; draft -> ready adds a new one with a status from
    the reviews, so a status set by hand does not survive the round trip."""
    fake = github([item(pr(draft=True), status="Blocked")], pulls=[pr(draft=True)])
    assert pba.sync(REPO, apply=True, now=NOW) == 0
    assert fake.mutations == [("item", None)]
    fake = github([], pulls=[pr()])
    assert pba.sync(REPO, apply=True, now=NOW) == 0
    assert fake.mutations == [
        ("add:PR1", None),
        ("new-PR1", {"text": "ubuntu-26.10"}),
        ("new-PR1", {"singleSelectOptionId": f"o-{pba.AWAITING}"}),
    ]


def test_sync_dry_run_writes_nothing(github, caplog):
    caplog.set_level(logging.INFO)
    fake = github([item(pr(state="CLOSED"))], pulls=[pr(2)])
    assert pba.sync(REPO, apply=False, now=NOW) == 0
    assert fake.mutations == []
    assert "PR #1: remove (closed)" in caplog.text and "(dry run)" in caplog.text
    assert "PR #2: add to the board" in caplog.text
    assert "PR #2: release -> ubuntu-26.10" in caplog.text


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
        ({"project": project_node(release="NUMBER")}, 'needs a "Release" text field'),
    ],
)
def test_sync_setup_errors(github, setup, error):
    github([], **setup)
    with pytest.raises(RuntimeError, match=error):
        pba.sync(REPO, apply=True, now=NOW)


class FakeResponse:
    def __init__(self, body):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        pass

    def read(self):
        return json.dumps(self.body).encode()


@pytest.mark.parametrize(
    "query, body, error",
    [
        # a query that lost one node still returns the rest
        ("query { x }", {"data": {"x": 1}, "errors": [{"type": "NOT_FOUND"}]}, None),
        ("query { x }", {"data": None, "errors": [{"type": "FORBIDDEN"}]}, "GraphQL errors"),
        # a failed mutation has nothing to keep
        (
            "mutation { x }",
            {"data": {"x": None}, "errors": [{"type": "FORBIDDEN"}]},
            "GraphQL errors",
        ),
    ],
)
def test_graphql_tolerates_a_lost_node_only_in_a_query(monkeypatch, caplog, query, body, error):
    monkeypatch.setenv("GITHUB_TOKEN", "t")
    monkeypatch.setattr(pba.urllib.request, "urlopen", lambda req, timeout: FakeResponse(body))
    if error:
        with pytest.raises(RuntimeError, match=error):
            pba.graphql(query, {})
    else:
        assert pba.graphql(query, {}) == body["data"]
        assert "GraphQL errors alongside the data" in caplog.text
