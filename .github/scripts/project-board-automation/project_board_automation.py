#!/usr/bin/env python3
"""
Keep the chisel-releases Review board (an organization Projects board) in sync with
the PRs on it, for what the built-in project workflows cannot do:

- remove draft and closed (unmerged) PRs from the board, and archive merged ones a
  few days after they merge, so the board holds the review queue;
- set the "Release" text field to the PR's base branch;
- set the status from the reviews: with no unaddressed change requests, 2+
  approvals -> "Ready For Merge", 1 -> "Pending Second Review", 0 -> back to
  "Awaiting Review". Only approvals from reviewers with push access count, as for
  the branch protection's required reviews. A reviewer the author has re-requested
  (directly, or through a team they reviewed on behalf of) no longer counts: their
  approval is stale and their change request is addressed.

Without --apply the script only logs what it would change.
"""

from __future__ import annotations

import argparse
import datetime
import logging
import os
import sys
from dataclasses import dataclass, field

import requests

GRAPHQL_URL = "https://api.github.com/graphql"

RELEASE_FIELD = "Release"
STATUS_FIELD = "Status"
AWAITING_REVIEW = "Awaiting Review"
IN_PROGRESS = "In Progress"
PENDING_SECOND = "Pending Second Review"
READY_FOR_MERGE = "Ready For Merge"

PROJECT_QUERY = """
query($owner: String!, $number: Int!) {
  organization(login: $owner) {
    projectV2(number: $number) {
      id
      fields(first: 50) {
        nodes {
          ... on ProjectV2FieldCommon { id name dataType }
          ... on ProjectV2SingleSelectField { id name options { id name } }
        }
      }
    }
  }
}
"""

ITEMS_QUERY = """
query($projectId: ID!, $cursor: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isArchived
          fieldValues(first: 50) {
            nodes {
              ... on ProjectV2ItemFieldTextValue {
                text field { ... on ProjectV2FieldCommon { id } }
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                optionId field { ... on ProjectV2FieldCommon { id } }
              }
            }
          }
          content {
            ... on PullRequest {
              number
              state
              isDraft
              mergedAt
              baseRefName
              repository { nameWithOwner }
              # last, not first: the connection is oldest first.
              reviews(last: 100) {
                nodes {
                  state
                  authorCanPushToRepository
                  author { login }
                  onBehalfOf(first: 10) { nodes { slug } }
                }
              }
              reviewRequests(first: 50) {
                nodes {
                  requestedReviewer {
                    ... on User { login }
                    ... on Team { slug }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
"""

SET_TEXT = """
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: { text: $value }
  }) { projectV2Item { id } }
}
"""

SET_SELECT = """
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
    value: { singleSelectOptionId: $optionId }
  }) { projectV2Item { id } }
}
"""

ARCHIVE_ITEM = """
mutation($projectId: ID!, $itemId: ID!) {
  archiveProjectV2Item(input: { projectId: $projectId, itemId: $itemId }) { item { id } }
}
"""

DELETE_ITEM = """
mutation($projectId: ID!, $itemId: ID!) {
  deleteProjectV2Item(input: { projectId: $projectId, itemId: $itemId }) { deletedItemId }
}
"""


def graphql(query: str, variables: dict) -> dict:
    """Run a GitHub GraphQL query with the token from GITHUB_TOKEN."""
    response = requests.post(
        GRAPHQL_URL,
        json={"query": query, "variables": variables},
        headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"},
        timeout=60,
    )
    response.raise_for_status()
    body = response.json()
    if body.get("errors"):
        raise RuntimeError(f"GraphQL errors: {body['errors']}")
    return body["data"]


@dataclass(frozen=True)
class Board:
    project_id: str
    release_field_id: str
    status_field_id: str
    status_ids: dict[str, str]  # status name -> option id


def load_board(owner: str, number: int) -> Board:
    data = graphql(PROJECT_QUERY, {"owner": owner, "number": number})
    project = (data.get("organization") or {}).get("projectV2")
    if not project:
        raise RuntimeError(f"Project {owner}/{number} not found, or no access to it")

    fields = {f["name"].lower(): f for f in project["fields"]["nodes"] if f and f.get("name")}
    release = fields.get(RELEASE_FIELD.lower())
    status = fields.get(STATUS_FIELD.lower())
    if not release:
        raise RuntimeError(f'Could not find field "{RELEASE_FIELD}" in the project')
    if not status or "options" not in status:
        raise RuntimeError(f'Could not find single-select field "{STATUS_FIELD}"')

    options = {o["name"].lower(): o["id"] for o in status["options"]}
    status_ids = {}
    for name in (AWAITING_REVIEW, IN_PROGRESS, PENDING_SECOND, READY_FOR_MERGE):
        if name.lower() not in options:
            raise RuntimeError(f'Status option "{name}" not found in field "{STATUS_FIELD}"')
        status_ids[name] = options[name.lower()]

    return Board(project["id"], release["id"], status["id"], status_ids)


def iter_items(project_id: str):
    cursor = None
    while True:
        items = graphql(ITEMS_QUERY, {"projectId": project_id, "cursor": cursor})["node"]["items"]
        yield from items["nodes"]
        if not items["pageInfo"]["hasNextPage"]:
            return
        cursor = items["pageInfo"]["endCursor"]


@dataclass
class Review:
    state: str
    can_push: bool
    teams: list[str] = field(default_factory=list)


def latest_reviews(pr: dict) -> dict[str, Review]:
    """The latest approve / changes-requested review per reviewer. Comments do not
    replace a decision, as on GitHub."""
    latest: dict[str, Review] = {}
    for r in pr["reviews"]["nodes"]:
        if not r or not (r.get("author") or {}).get("login"):
            continue
        if r["state"] in ("COMMENTED", "PENDING"):
            continue
        teams = [t["slug"] for t in ((r.get("onBehalfOf") or {}).get("nodes") or []) if t]
        latest[r["author"]["login"]] = Review(
            r["state"], bool(r.get("authorCanPushToRepository")), teams
        )
    return latest


def pending_requests(pr: dict) -> tuple[set[str], set[str]]:
    """Pending review requests, as (user logins, team slugs)."""
    users, teams = set(), set()
    for rr in (pr.get("reviewRequests") or {}).get("nodes") or []:
        req = (rr or {}).get("requestedReviewer") or {}
        if req.get("login"):
            users.add(req["login"])
        elif req.get("slug"):
            teams.add(req["slug"])
    return users, teams


def target_status(pr: dict, current: str | None) -> str | None:
    """The status the PR should have, or None to leave it as it is."""
    reviews = latest_reviews(pr)
    users, teams = pending_requests(pr)

    def re_requested(login: str, review: Review) -> bool:
        return login in users or any(t in teams for t in review.teams)

    unaddressed = any(
        r.state == "CHANGES_REQUESTED" and not re_requested(login, r)
        for login, r in reviews.items()
    )
    if unaddressed:
        # "In Progress" belongs to the built-in "Code changes requested" workflow.
        return None

    approvals = sum(
        1
        for login, r in reviews.items()
        if r.state == "APPROVED" and r.can_push and not re_requested(login, r)
    )
    if approvals >= 2:
        return READY_FOR_MERGE
    if approvals == 1:
        return PENDING_SECOND
    if current in (IN_PROGRESS, PENDING_SECOND, READY_FOR_MERGE):
        return AWAITING_REVIEW
    return None


@dataclass(frozen=True)
class Action:
    kind: str  # "remove", "archive", "release" or "status"
    value: str | None = None
    reason: str = ""


def plan_item(
    item: dict,
    board: Board,
    repo: str,
    now: datetime.datetime,
    archive_after: datetime.timedelta,
) -> list[Action]:
    """What to change for one board item."""
    pr = item.get("content") or {}
    if not pr.get("number") or (pr.get("repository") or {}).get("nameWithOwner") != repo:
        return []

    if pr["state"] == "CLOSED":
        return [Action("remove", reason="closed")]
    if pr["state"] == "MERGED":
        # the built-in workflow owns the "Merged" status; only archive old ones
        merged_at = datetime.datetime.fromisoformat(pr["mergedAt"])
        if not item.get("isArchived") and now - merged_at > archive_after:
            return [Action("archive", reason=f"merged {pr['mergedAt']}")]
        return []
    if pr.get("isDraft"):
        # the built-in auto-add workflow adds it back when it is marked ready
        return [Action("remove", reason="draft")]

    text, select = {}, {}
    for fv in item["fieldValues"]["nodes"]:
        if not fv or not fv.get("field"):
            continue
        if isinstance(fv.get("text"), str):
            text[fv["field"]["id"]] = fv["text"]
        elif isinstance(fv.get("optionId"), str):
            select[fv["field"]["id"]] = fv["optionId"]

    actions = []
    if text.get(board.release_field_id) != pr["baseRefName"]:
        actions.append(Action("release", pr["baseRefName"]))

    names = {v: k for k, v in board.status_ids.items()}
    current = names.get(select.get(board.status_field_id))
    target = target_status(pr, current)
    if target and target != current:
        actions.append(Action("status", target, reason=f"was {current}"))
    return actions


def apply_action(board: Board, item_id: str, action: Action) -> None:
    ids = {"projectId": board.project_id, "itemId": item_id}
    if action.kind == "remove":
        graphql(DELETE_ITEM, ids)
    elif action.kind == "archive":
        graphql(ARCHIVE_ITEM, ids)
    elif action.kind == "release":
        graphql(SET_TEXT, {**ids, "fieldId": board.release_field_id, "value": action.value})
    elif action.kind == "status":
        option = board.status_ids[action.value]
        graphql(SET_SELECT, {**ids, "fieldId": board.status_field_id, "optionId": option})


def sync(
    owner: str,
    number: int,
    repo: str,
    apply: bool,
    archive_after: datetime.timedelta,
    now: datetime.datetime | None = None,
) -> int:
    """Sync the board. Returns the number of items that failed."""
    now = now or datetime.datetime.now(datetime.timezone.utc)
    board = load_board(owner, number)
    seen = failed = 0
    for item in iter_items(board.project_id):
        pr = item.get("content") or {}
        try:
            actions = plan_item(item, board, repo, now, archive_after)
            if (
                pr.get("state") == "OPEN"
                and (pr.get("repository") or {}).get("nameWithOwner") == repo
            ):
                seen += 1
            for action in actions:
                logging.info(
                    "PR #%s: %s%s%s",
                    pr.get("number"),
                    action.kind,
                    f" -> {action.value}" if action.value else "",
                    f" ({action.reason})" if action.reason else "",
                )
                if apply:
                    apply_action(board, item["id"], action)
        except Exception as e:  # one bad item must not stop the rest
            failed += 1
            logging.error("PR #%s: failed: %s", pr.get("number"), e)
    logging.info("Processed %d open PR item(s)%s.", seen, "" if apply else " (dry run)")
    return failed


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--apply", action="store_true", help="Write the changes. Without it, only log them."
    )
    parser.add_argument("--owner", default="canonical", help="Organization that owns the project")
    parser.add_argument("--project", type=int, default=161, help="Project number")
    parser.add_argument(
        "--repo",
        default=os.environ.get("GH_REPO", "canonical/chisel-releases"),
        help="Only touch PRs from this repository",
    )
    parser.add_argument(
        "--archive-after-days", type=int, default=7, help="Archive merged PRs after this many days"
    )
    args = parser.parse_args()

    failed = sync(
        args.owner,
        args.project,
        args.repo,
        args.apply,
        datetime.timedelta(days=args.archive_after_days),
    )
    if failed:
        logging.error("%d item(s) failed, see the log above.", failed)
        sys.exit(1)


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    main()
