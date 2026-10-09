#!/usr/bin/env python3
"""
Unit tests for project_board_automation.py, against a mocked GraphQL board.
"""

import datetime
import logging
import os
import sys

import pytest

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import project_board_automation as pba

NOW = datetime.datetime(2026, 10, 9, 12, 0, tzinfo=datetime.timezone.utc)
WEEK = datetime.timedelta(days=7)
REPO = "canonical/chisel-releases"

OPT = {
    pba.AWAITING_REVIEW: "o-await",
    pba.IN_PROGRESS: "o-prog",
    pba.PENDING_SECOND: "o-second",
    pba.READY_FOR_MERGE: "o-ready",
    "Merged": "o-merged",
}
FIELDS = [
    {"id": "f-title", "name": "Title", "dataType": "TITLE"},
    {"id": "f-release", "name": "Release", "dataType": "TEXT"},
    {
        "id": "f-status",
        "name": "Status",
        "dataType": "SINGLE_SELECT",
        "options": [{"id": i, "name": n} for n, i in OPT.items()],
    },
]


def days_ago(n):
    return (NOW - datetime.timedelta(days=n)).isoformat().replace("+00:00", "Z")


def rev(login, state, can_push=True, teams=()):
    return {
        "state": state,
        "authorCanPushToRepository": can_push,
        "author": {"login": login},
        "onBehalfOf": {"nodes": [{"slug": t} for t in teams]},
    }


def item(
    item_id,
    number,
    *,
    state="OPEN",
    status=pba.AWAITING_REVIEW,
    release="ubuntu-26.10",
    base="ubuntu-26.10",
    repo=REPO,
    draft=False,
    merged_at=None,
    archived=False,
    reviews=(),
    requests=(),
):
    values = []
    if release is not None:
        values.append({"text": release, "field": {"id": "f-release"}})
    if status is not None:
        values.append({"optionId": OPT[status], "field": {"id": "f-status"}})
    return {
        "id": item_id,
        "isArchived": archived,
        "fieldValues": {"nodes": values},
        "content": {
            "number": number,
            "state": state,
            "isDraft": draft,
            "mergedAt": merged_at,
            "baseRefName": base,
            "repository": {"nameWithOwner": repo},
            "reviews": {"nodes": list(reviews)},
            "reviewRequests": {"nodes": [{"requestedReviewer": r} for r in requests]},
        },
    }


class FakeGitHub:
    """Serves the project and its items, records writes, and can fail chosen items."""

    def __init__(self, items, project=True, fail_items=(), page_size=6, team=("Guildie",)):
        self.items = items
        self.project = project
        self.team = team
        self.fail_items = set(fail_items)
        self.page_size = page_size
        self.writes = []

    def __call__(self, query, variables):
        if "projectV2(number" in query:
            project = {"id": "P", "fields": {"nodes": FIELDS}} if self.project else None
            return {"organization": {"projectV2": project}}
        if "team(slug" in query:
            team = None
            if self.team is not None:
                team = {
                    "members": {
                        "pageInfo": {"hasNextPage": False, "endCursor": None},
                        "nodes": [{"login": login} for login in self.team],
                    }
                }
            return {"organization": {"team": team}}
        if "items(first: 50" in query:
            start = int(variables["cursor"] or 0)
            page = self.items[start : start + self.page_size]
            end = start + len(page)
            return {
                "node": {
                    "items": {
                        "pageInfo": {"hasNextPage": end < len(self.items), "endCursor": str(end)},
                        "nodes": page,
                    }
                }
            }
        item_id = variables["itemId"]
        if item_id in self.fail_items:
            raise RuntimeError("boom")
        if "archiveProjectV2Item" in query:
            self.writes.append((item_id, "archive"))
        elif "deleteProjectV2Item" in query:
            self.writes.append((item_id, "remove"))
        elif "singleSelectOptionId" in query:
            name = {v: k for k, v in OPT.items()}[variables["optionId"]]
            self.writes.append((item_id, "status", name))
        elif "text: $value" in query:
            self.writes.append((item_id, "release", variables["value"]))
        else:
            raise AssertionError(f"unexpected query: {query}")
        return {}

    def of(self, item_id):
        return [w[1:] for w in self.writes if w[0] == item_id]


@pytest.fixture
def run(monkeypatch):
    """Sync a mocked board; returns the fake (with its writes) and the failure count."""

    def _run(items, apply=True, **kw):
        gh = FakeGitHub(items, **kw)
        monkeypatch.setattr(pba, "graphql", gh)
        failed = pba.sync("canonical", 161, REPO, apply, WEEK, teams=["guild"], now=NOW)
        return gh, failed

    return _run


class TestStatus:
    def test_two_push_approvals_ready_for_merge(self, run):
        gh, _ = run([item("i", 1, reviews=[rev("a", "APPROVED"), rev("b", "APPROVED")])])
        assert ("status", pba.READY_FOR_MERGE) in gh.of("i")

    def test_approval_without_push_access_does_not_count(self, run):
        gh, _ = run(
            [item("i", 1, reviews=[rev("a", "APPROVED"), rev("m", "APPROVED", can_push=False)])]
        )
        assert ("status", pba.PENDING_SECOND) in gh.of("i")

    def test_reviewer_team_member_approval_counts(self, run):
        # no push access, but in the reviewer team (login case differs on purpose)
        gh, _ = run(
            [
                item(
                    "i",
                    1,
                    reviews=[rev("a", "APPROVED"), rev("guildie", "APPROVED", can_push=False)],
                )
            ]
        )
        assert ("status", pba.READY_FOR_MERGE) in gh.of("i")

    def test_re_requested_approver_is_stale(self, run):
        gh, _ = run(
            [
                item(
                    "i",
                    1,
                    status=pba.READY_FOR_MERGE,
                    reviews=[rev("a", "APPROVED"), rev("b", "APPROVED")],
                    requests=[{"login": "b"}],
                )
            ]
        )
        assert ("status", pba.PENDING_SECOND) in gh.of("i")

    def test_team_re_request_clears_a_review_on_behalf_of_it(self, run):
        gh, _ = run(
            [
                item(
                    "i",
                    1,
                    status=pba.READY_FOR_MERGE,
                    reviews=[rev("a", "APPROVED"), rev("b", "APPROVED", teams=["guild"])],
                    requests=[{"slug": "guild"}],
                )
            ]
        )
        assert ("status", pba.PENDING_SECOND) in gh.of("i")

    def test_unaddressed_change_request_leaves_status_alone(self, run):
        gh, _ = run(
            [
                item(
                    "i",
                    1,
                    status=pba.IN_PROGRESS,
                    reviews=[rev("a", "APPROVED"), rev("b", "CHANGES_REQUESTED")],
                )
            ]
        )
        assert gh.of("i") == []

    def test_addressed_change_request_without_approvals_back_to_awaiting(self, run):
        gh, _ = run(
            [
                item(
                    "i",
                    1,
                    status=pba.IN_PROGRESS,
                    reviews=[rev("b", "CHANGES_REQUESTED")],
                    requests=[{"login": "b"}],
                )
            ]
        )
        assert gh.of("i") == [("status", pba.AWAITING_REVIEW)]

    def test_latest_decisive_review_wins_and_comments_do_not_override(self, run):
        reviews = [
            rev("a", "APPROVED"),
            rev("a", "CHANGES_REQUESTED"),
            rev("a", "APPROVED"),
            rev("a", "COMMENTED"),
        ]
        gh, _ = run([item("i", 1, status=pba.IN_PROGRESS, reviews=reviews)])
        assert gh.of("i") == [("status", pba.PENDING_SECOND)]

    def test_no_reviews_and_awaiting_is_left_alone(self, run):
        gh, _ = run([item("i", 1)])
        assert gh.of("i") == []

    def test_status_already_right_is_not_rewritten(self, run):
        gh, _ = run(
            [
                item(
                    "i",
                    1,
                    status=pba.READY_FOR_MERGE,
                    reviews=[rev("a", "APPROVED"), rev("b", "APPROVED")],
                )
            ]
        )
        assert gh.of("i") == []


class TestBoardHousekeeping:
    def test_release_field_set_from_base_branch(self, run):
        gh, _ = run([item("i", 1, base="ubuntu-24.04", release=None)])
        assert gh.of("i") == [("release", "ubuntu-24.04")]

    def test_draft_is_removed_and_not_updated(self, run):
        gh, _ = run([item("i", 1, draft=True, release=None)])
        assert gh.of("i") == [("remove",)]

    def test_closed_unmerged_is_removed(self, run):
        gh, _ = run([item("i", 1, state="CLOSED")])
        assert gh.of("i") == [("remove",)]

    def test_merged_long_ago_is_archived(self, run):
        gh, _ = run([item("i", 1, state="MERGED", status="Merged", merged_at=days_ago(30))])
        assert gh.of("i") == [("archive",)]

    def test_recently_merged_is_left_alone(self, run):
        gh, _ = run([item("i", 1, state="MERGED", status="Merged", merged_at=days_ago(2))])
        assert gh.of("i") == []

    def test_already_archived_is_left_alone(self, run):
        gh, _ = run(
            [item("i", 1, state="MERGED", status="Merged", merged_at=days_ago(30), archived=True)]
        )
        assert gh.of("i") == []

    def test_other_repository_is_left_alone(self, run):
        gh, _ = run(
            [
                item(
                    "o1",
                    1,
                    repo="canonical/other",
                    reviews=[rev("a", "APPROVED"), rev("b", "APPROVED")],
                ),
                item("o2", 2, repo="canonical/other", state="CLOSED"),
            ]
        )
        assert gh.writes == []

    def test_non_pr_items_are_skipped(self, run):
        gh, _ = run([{"id": "n", "isArchived": False, "fieldValues": {"nodes": []}, "content": {}}])
        assert gh.writes == []


class TestRun:
    def test_failed_item_is_counted_and_the_rest_still_run(self, run, caplog):
        caplog.set_level(logging.INFO)
        items = [
            item(f"i{n}", n, reviews=[rev("a", "APPROVED"), rev("b", "APPROVED")])
            for n in range(1, 10)
        ]
        gh, failed = run(items, fail_items={"i3"})
        assert failed == 1
        assert "PR #3: failed: boom" in caplog.text
        # later pages (page size 6) are still processed
        assert ("status", pba.READY_FOR_MERGE) in gh.of("i9")
        assert "Processed 9 open PR item(s)." in caplog.text

    def test_dry_run_writes_nothing_but_logs(self, run, caplog):
        caplog.set_level(logging.INFO)
        gh, failed = run(
            [
                item("i", 1, reviews=[rev("a", "APPROVED"), rev("b", "APPROVED")]),
                item("c", 2, state="CLOSED"),
            ],
            apply=False,
        )
        assert gh.writes == [] and failed == 0
        assert f"PR #1: status -> {pba.READY_FOR_MERGE}" in caplog.text
        assert "PR #2: remove (closed)" in caplog.text
        assert "(dry run)" in caplog.text

    def test_missing_team_is_a_clear_error(self, run):
        with pytest.raises(RuntimeError, match="Team canonical/guild not found"):
            run([], team=None)

    def test_missing_project_is_a_clear_error(self, run):
        with pytest.raises(RuntimeError, match="not found, or no access to it"):
            run([], project=False)


class TestHelpers:
    def test_latest_reviews_keeps_the_last_decision(self):
        pr = {
            "reviews": {
                "nodes": [rev("a", "APPROVED"), rev("a", "DISMISSED"), rev("b", "COMMENTED")]
            }
        }
        reviews = pba.latest_reviews(pr)
        assert set(reviews) == {"a"} and reviews["a"].state == "DISMISSED"

    def test_pending_requests_split_users_and_teams(self):
        pr = {
            "reviewRequests": {
                "nodes": [
                    {"requestedReviewer": {"login": "u"}},
                    {"requestedReviewer": {"slug": "t"}},
                    {"requestedReviewer": None},
                ]
            }
        }
        assert pba.pending_requests(pr) == ({"u"}, {"t"})
