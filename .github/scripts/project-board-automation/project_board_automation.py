#!/usr/bin/env python3
"""
Keep the chisel-releases Review board (canonical org project 161) in sync with the
PRs on it, for what the built-in project workflows cannot do:

- remove draft and closed (unmerged) PRs, and archive merged ones a week after they
  merge, so the board holds the review queue;
- set the "Release" field to the PR's base branch;
- set the status from the reviews: with no unaddressed change requests, 2+
  approvals -> "Ready For Merge", 1 -> "Pending Second Review", 0 -> back to
  "Awaiting Review". Approvals count from reviewers with push access (what the
  required reviews count) and from slice-reviewers-guild members. A reviewer the
  author has re-requested (directly, or through a team they reviewed on behalf of)
  no longer counts: their approval is stale and their change request is addressed.

Without --apply it only logs what it would change.
"""

from __future__ import annotations

import argparse
import datetime
import json
import logging
import os
import sys
import urllib.request

OWNER = "canonical"
PROJECT = 161
REVIEWER_TEAM = "slice-reviewers-guild"
ARCHIVE_AFTER = datetime.timedelta(days=7)

AWAITING, IN_PROGRESS = "Awaiting Review", "In Progress"
PENDING_SECOND, READY = "Pending Second Review", "Ready For Merge"

PROJECT_QUERY = """
query($owner: String!, $number: Int!) {
  organization(login: $owner) {
    projectV2(number: $number) {
      id
      release: field(name: "Release") { ... on ProjectV2Field { id } }
      status: field(name: "Status") { ... on ProjectV2SingleSelectField { id options { id name } } }
    }
  }
}
"""

TEAM_QUERY = """
query($owner: String!, $slug: String!, $cursor: String) {
  organization(login: $owner) {
    team(slug: $slug) {
      members(first: 100, after: $cursor) { pageInfo { hasNextPage endCursor } nodes { login } }
    }
  }
}
"""

ITEMS_QUERY = """
query($id: ID!, $cursor: String) {
  node(id: $id) {
    ... on ProjectV2 {
      items(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isArchived
          release: fieldValueByName(name: "Release") { ... on ProjectV2ItemFieldTextValue { text } }
          status: fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
          content {
            ... on PullRequest {
              number state isDraft mergedAt baseRefName
              repository { nameWithOwner }
              # last, not first: the connection is oldest first
              reviews(last: 100) {
                nodes {
                  state authorCanPushToRepository author { login }
                  onBehalfOf(first: 10) { nodes { slug } }
                }
              }
              reviewRequests(first: 50) {
                nodes { requestedReviewer { ... on User { login } ... on Team { slug } } }
              }
            }
          }
        }
      }
    }
  }
}
"""

UPDATE = """
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: ProjectV2FieldValue!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: $value
  }) { projectV2Item { id } }
}
"""
ARCHIVE = """
mutation($projectId: ID!, $itemId: ID!) {
  archiveProjectV2Item(input: { projectId: $projectId, itemId: $itemId }) { item { id } }
}
"""
REMOVE = """
mutation($projectId: ID!, $itemId: ID!) {
  deleteProjectV2Item(input: { projectId: $projectId, itemId: $itemId }) { deletedItemId }
}
"""


def graphql(query: str, variables: dict) -> dict:
    request = urllib.request.Request(
        "https://api.github.com/graphql",
        data=json.dumps({"query": query, "variables": variables}).encode(),
        headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:  # raises on non-2xx
        body = json.load(response)
    if body.get("errors"):
        raise RuntimeError(f"GraphQL errors: {body['errors']}")
    return body["data"]


def paged(query: str, variables: dict, connection) -> list[dict]:
    """All nodes of a paginated connection; `connection` picks it out of a response."""
    nodes, cursor = [], None
    while True:
        conn = connection(graphql(query, {**variables, "cursor": cursor}))
        nodes += conn["nodes"]
        if not conn["pageInfo"]["hasNextPage"]:
            return nodes
        cursor = conn["pageInfo"]["endCursor"]


def load_project() -> dict:
    data = graphql(PROJECT_QUERY, {"owner": OWNER, "number": PROJECT})
    project = data["organization"]["projectV2"]
    if not project:
        raise RuntimeError(f"Project {OWNER}/{PROJECT} not found, or no access to it")
    if not project["release"] or not project["status"]:
        raise RuntimeError('The project needs a "Release" text field and a "Status" field')
    options = {o["name"]: o["id"] for o in project["status"]["options"]}
    missing = {AWAITING, IN_PROGRESS, PENDING_SECOND, READY} - options.keys()
    if missing:
        raise RuntimeError(f"Status options missing: {sorted(missing)}")
    return {**project, "options": options}


def load_team(slug: str) -> set[str]:
    def members(data):
        if not data["organization"]["team"]:
            raise RuntimeError(f"Team {OWNER}/{slug} not found, or no access to it")
        return data["organization"]["team"]["members"]

    nodes = paged(TEAM_QUERY, {"owner": OWNER, "slug": slug}, members)
    return {m["login"].lower() for m in nodes}


def target_status(pr: dict, current: str | None, team: set[str]) -> str | None:
    """The status the PR should have, or None to leave it as it is."""
    # the latest decision per reviewer; a comment does not replace one, as on GitHub
    latest = {
        r["author"]["login"]: r
        for r in pr["reviews"]["nodes"]
        if r["author"] and r["state"] in ("APPROVED", "CHANGES_REQUESTED", "DISMISSED")
    }
    requested = {
        rr["requestedReviewer"].get("login") or rr["requestedReviewer"].get("slug")
        for rr in pr["reviewRequests"]["nodes"]
        if rr["requestedReviewer"]
    }

    def counts(login: str, review: dict) -> bool:
        teams = {t["slug"] for t in review["onBehalfOf"]["nodes"]}
        return login not in requested and not teams & requested

    if any(r["state"] == "CHANGES_REQUESTED" and counts(u, r) for u, r in latest.items()):
        return None  # "In Progress" belongs to the built-in "Code changes requested" workflow
    approvals = sum(
        r["state"] == "APPROVED"
        and (r["authorCanPushToRepository"] or u.lower() in team)
        and counts(u, r)
        for u, r in latest.items()
    )
    if approvals:
        return READY if approvals >= 2 else PENDING_SECOND
    return AWAITING if current in (IN_PROGRESS, PENDING_SECOND, READY) else None


def plan(item: dict, project: dict, team: set[str], now: datetime.datetime) -> list[tuple]:
    """The changes for one PR item, as (description, query, variables)."""
    pr, ids = item["content"], {"projectId": project["id"], "itemId": item["id"]}
    if pr["state"] == "CLOSED":
        return [("remove (closed)", REMOVE, ids)]
    if pr["state"] == "MERGED":
        # the built-in workflow owns the "Merged" status; we only archive old ones
        merged = datetime.datetime.fromisoformat(pr["mergedAt"])
        if item["isArchived"] or now - merged <= ARCHIVE_AFTER:
            return []
        return [(f"archive (merged {pr['mergedAt']})", ARCHIVE, ids)]
    if pr["isDraft"]:
        # the built-in auto-add brings it back when it is marked ready for review
        return [("remove (draft)", REMOVE, ids)]

    def update(field: str, value: dict) -> dict:
        return {**ids, "fieldId": project[field]["id"], "value": value}

    changes = []
    if (item["release"] or {}).get("text") != pr["baseRefName"]:
        value = {"text": pr["baseRefName"]}
        changes.append((f"release -> {pr['baseRefName']}", UPDATE, update("release", value)))
    current = (item["status"] or {}).get("name")
    target = target_status(pr, current, team)
    if target and target != current:
        value = {"singleSelectOptionId": project["options"][target]}
        changes.append((f"status -> {target} (was {current})", UPDATE, update("status", value)))
    return changes


def sync(repo: str, apply: bool, now: datetime.datetime | None = None) -> int:
    """Sync the board; returns the number of items that failed."""
    now = now or datetime.datetime.now(datetime.timezone.utc)
    project, team = load_project(), load_team(REVIEWER_TEAM)
    items = paged(ITEMS_QUERY, {"id": project["id"]}, lambda d: d["node"]["items"])
    open_prs = failed = 0
    for item in items:
        pr = item["content"]
        if not pr or pr["repository"]["nameWithOwner"] != repo:
            continue  # not a PR, or another repository's
        open_prs += pr["state"] == "OPEN"
        try:
            for description, query, variables in plan(item, project, team, now):
                logging.info("PR #%d: %s", pr["number"], description)
                if apply:
                    graphql(query, variables)
        except Exception as e:  # one bad item must not stop the rest
            failed += 1
            logging.error("PR #%d: failed: %s", pr["number"], e)
    logging.info("Processed %d open PR(s)%s.", open_prs, "" if apply else " (dry run)")
    return failed


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--apply", action="store_true", help="write the changes, not just log them")
    args = parser.parse_args()
    failed = sync(os.environ.get("GH_REPO", "canonical/chisel-releases"), args.apply)
    if failed:
        sys.exit(f"{failed} item(s) failed, see the log above.")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    main()
