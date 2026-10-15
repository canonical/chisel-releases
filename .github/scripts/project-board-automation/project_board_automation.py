#!/usr/bin/env python3
"""
Keep the "chisel-releases review" board (canonical org project 161) in sync with this
repository's PRs. It replaces the built-in project workflows (auto-add, default
status, "Merged", "Changes requested -> In Progress"), so the board has one owner:

- add every open, non-draft PR; remove draft and closed (unmerged) ones; set merged
  ones to "Merged" and archive them a week after they merge, so the board holds the
  review queue. Archived items are left alone, whoever archived them;
- set the "Release" field to the PR's base branch;
- set the status from the reviews: an unaddressed change request -> "In Progress";
  otherwise 2+ approvals -> "Ready For Merge", 1 -> "Pending Second Review", 0 ->
  "Awaiting Review". The script owns those four statuses and "Merged"; any other
  status set by hand stays until the reviews give an approval or a change request.
  Reviews count from reviewers with push access (what
  GitHub's required reviews and merge blocking count) and from slice-reviewers-guild
  members, so a change request from someone who has since left does not park a PR.
  A reviewer's opinion is their latest review; once the author re-requests them
  (directly, or through the team they reviewed on behalf of) they have none: the
  approval is stale and the change request is addressed.

The board is the only thing it writes to: every mutation is a ProjectV2 one, and the
repository, its PRs, labels and comments are read-only to it (the token has no write
scope on them either). Without --apply it only logs what it would change. It runs
hourly, so the board lags events by up to an hour where the built-in workflows
reacted at once.
"""

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
PENDING_SECOND, READY, MERGED = "Pending Second Review", "Ready For Merge", "Merged"
STATUSES = {AWAITING, IN_PROGRESS, PENDING_SECOND, READY, MERGED}

PROJECT_QUERY = """
query($owner: String!, $number: Int!) {
  organization(login: $owner) {
    projectV2(number: $number) {
      id
      release: field(name: "Release") { ... on ProjectV2Field { id dataType } }
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

PR_FIELDS = """
fragment prFields on PullRequest {
  id number state isDraft mergedAt baseRefName
  repository { nameWithOwner }
  # last, not first: the connection is oldest first. A PR with over 100 reviews loses
  # its oldest ones, which only matters for a reviewer whose last decision is that old.
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
          content { ...prFields }
        }
      }
    }
  }
}
""" + PR_FIELDS

OPEN_PRS_QUERY = """
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: OPEN, first: 50, after: $cursor) {
      pageInfo { hasNextPage endCursor }
      nodes { ...prFields }
    }
  }
}
""" + PR_FIELDS

UPDATE = """
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: ProjectV2FieldValue!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: $value
  }) { projectV2Item { id } }
}
"""
ADD = """
mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
    item {
      id isArchived
      release: fieldValueByName(name: "Release") { ... on ProjectV2ItemFieldTextValue { text } }
      status: fieldValueByName(name: "Status") {
        ... on ProjectV2ItemFieldSingleSelectValue { name }
      }
    }
  }
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
        # a query can fail on one node (e.g. content the token cannot read) and still
        # return the rest, with that node null; a mutation that failed has nothing to keep
        if body.get("data") is None or query.lstrip().startswith("mutation"):
            raise RuntimeError(f"GraphQL errors: {body['errors']}")
        logging.warning("GraphQL errors alongside the data: %s", body["errors"])
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
    if (project["release"] or {}).get("dataType") != "TEXT" or not project["status"]:
        raise RuntimeError('The project needs a "Release" text field and a "Status" field')
    options = {o["name"]: o["id"] for o in project["status"]["options"]}
    missing = STATUSES - options.keys()
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
        if login in requested or teams & requested:
            return False
        return review["authorCanPushToRepository"] or login.lower() in team

    decisions = [r["state"] for u, r in latest.items() if counts(u, r)]
    if "CHANGES_REQUESTED" in decisions:
        return IN_PROGRESS
    approvals = decisions.count("APPROVED")
    if approvals:
        return READY if approvals >= 2 else PENDING_SECOND
    return AWAITING if current in (None, IN_PROGRESS, PENDING_SECOND, READY, MERGED) else None


def plan(item: dict, project: dict, team: set[str], now: datetime.datetime) -> list[tuple]:
    """The changes for one PR item, as (description, query, variables)."""
    pr, ids = item["content"], {"projectId": project["id"], "itemId": item["id"]}
    current = (item["status"] or {}).get("name")

    def update(field: str, value: dict) -> dict:
        return {**ids, "fieldId": project[field]["id"], "value": value}

    def status(target: str) -> tuple:
        value = {"singleSelectOptionId": project["options"][target]}
        return (f"status -> {target} (was {current})", UPDATE, update("status", value))

    if item["isArchived"]:
        return []
    if pr["state"] == "CLOSED":
        return [("remove (closed)", REMOVE, ids)]
    if pr["state"] == "MERGED":
        changes = [status(MERGED)] if current != MERGED else []
        if now - datetime.datetime.fromisoformat(pr["mergedAt"]) > ARCHIVE_AFTER:
            changes.append((f"archive (merged {pr['mergedAt']})", ARCHIVE, ids))
        return changes
    if pr["isDraft"]:
        # sync() adds it back once it is marked ready for review
        return [("remove (draft)", REMOVE, ids)]

    changes = []
    if (item["release"] or {}).get("text") != pr["baseRefName"]:
        value = {"text": pr["baseRefName"]}
        changes.append((f"release -> {pr['baseRefName']}", UPDATE, update("release", value)))
    target = target_status(pr, current, team)
    if target and target != current:
        changes.append(status(target))
    return changes


def sync(repo: str, apply: bool, now: datetime.datetime | None = None) -> int:
    """Sync the board; returns the number of items that failed."""
    now = now or datetime.datetime.now(datetime.timezone.utc)
    project, team = load_project(), load_team(REVIEWER_TEAM)
    items = paged(ITEMS_QUERY, {"id": project["id"]}, lambda d: d["node"]["items"])
    # this repository's PRs only; the board may hold other content
    items = [
        i
        for i in items
        if ((i["content"] or {}).get("repository") or {}).get("nameWithOwner", "").lower()
        == repo.lower()
    ]
    on_board = {i["content"]["number"] for i in items}
    owner, name = repo.split("/")
    pulls = paged(
        OPEN_PRS_QUERY, {"owner": owner, "name": name}, lambda d: d["repository"]["pullRequests"]
    )
    open_prs = failed = 0
    for pr in pulls:
        if pr["isDraft"] or pr["number"] in on_board:
            continue
        # added and configured in the same run; without --apply the item id stays unknown
        new = {"id": None, "isArchived": False, "release": None, "status": None, "content": pr}
        logging.info("PR #%d: add to the board", pr["number"])
        try:
            if apply:
                added = graphql(ADD, {"projectId": project["id"], "contentId": pr["id"]})
                # an item someone added since the board was read comes back as it is
                new.update(added["addProjectV2ItemById"]["item"])
        except Exception as e:
            failed += 1
            logging.error("PR #%d: failed: %s", pr["number"], e)
            continue
        items.append(new)
    for item in items:
        pr = item["content"]
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
