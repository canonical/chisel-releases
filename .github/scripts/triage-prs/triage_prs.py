#!/usr/bin/env python3
"""
Request reviews on the open PRs into the release branches of chisel-releases.

The reviewers of each entry in the config file, users or teams, are requested
on the PRs which touch slices/<package>.yaml or tests/spread/integration/<package>/
of a package the entry lists, or on every PR if it lists "*". Draft PRs are
skipped until they are ready for review.

A reviewer is only ever requested once per PR: anyone who has been requested
before, or has already reviewed, is left alone. That makes the script safe to
rerun on every push and on a schedule, it does not re-ping people after they
review, and a reviewer removed by hand stays removed.
"""

from __future__ import annotations

import argparse
import fnmatch
import logging
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

import requests
import yaml

API_URL = "https://api.github.com"
DEFAULT_REPO = "canonical/chisel-releases"
DEFAULT_CONFIG = Path(__file__).resolve().parents[2] / "codeowners.yaml"

EVERY_PR = "*"

_LOGIN_RE = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?")
# <org>/<team slug>
_TEAM_RE = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[a-z0-9][a-z0-9_-]*")
# Debian package names, plus "*" to stand in for versions.
_PACKAGE_RE = re.compile(r"[a-z0-9][a-z0-9+.*-]*")

_SLICE_PATH_RE = re.compile(r"slices/([^/]+)\.yaml")
_TEST_PATH_RE = re.compile(r"tests/spread/integration/([^/]+)/.+")


class ConfigError(Exception):
    pass


class _Loader(yaml.SafeLoader):
    """A SafeLoader which rejects duplicate keys instead of keeping the last one."""

    def construct_mapping(self, node, deep=False):
        self.flatten_mapping(node)
        seen = set()
        for key_node, _ in node.value:
            key = self.construct_object(key_node, deep=deep)
            if key in seen:
                line = key_node.start_mark.line + 1
                raise ConfigError(f"line {line}: duplicate key {key!r}")
            seen.add(key)
        return super().construct_mapping(node, deep=deep)


@dataclass(frozen=True)
class Entry:
    reviewers: tuple[str, ...]  # user logins and <org>/<team> slugs
    packages: tuple[str, ...]  # package names and globs


@dataclass(frozen=True)
class Config:
    entries: tuple[Entry, ...]

    @classmethod
    def load(cls, path: Path) -> Config:
        try:
            data = yaml.load(path.read_text(), Loader=_Loader)
        except (yaml.YAMLError, ConfigError) as e:
            raise ConfigError(f"{path}: {e}") from e
        errors = validate(data)
        if errors:
            raise ConfigError("\n".join(f"{path}: {e}" for e in errors))
        return cls(
            tuple(Entry(tuple(e["reviewers"]), tuple(e["packages"])) for e in data)
        )


def validate(data: object) -> list[str]:
    """Check the shape of a parsed config file. Returns a list of errors."""
    if not isinstance(data, list) or not data:
        return ["must be a non-empty list of entries"]
    errors: list[str] = []
    for i, entry in enumerate(data, 1):
        if not isinstance(entry, dict):
            errors.append(f"entry {i}: must be a mapping")
            continue
        reviewers = entry.get("reviewers")
        if not isinstance(reviewers, list) or not reviewers:
            errors.append(f"entry {i}: reviewers: must be a non-empty list")
            reviewers = []
        where = f"entry {i} ({', '.join(map(str, reviewers))})"

        errors += [f"{where}: unknown key {k!r}" for k in entry if k not in ("reviewers", "packages")]
        for r in reviewers:
            if not isinstance(r, str) or not (_LOGIN_RE.fullmatch(r) or _TEAM_RE.fullmatch(r)):
                errors.append(f"{where}: {r!r} is not a GitHub login or <org>/<team>")
        names = [str(r) for r in reviewers]
        if names != sorted(names, key=str.lower):
            errors.append(f"{where}: reviewers not sorted (case-insensitive)")
        if len({n.lower() for n in names}) != len(names):
            errors.append(f"{where}: duplicate reviewers (case-insensitive)")

        packages = entry.get("packages")
        if not isinstance(packages, dict) or not packages:
            errors.append(f"{where}: packages: must be a non-empty mapping")
            continue
        if [str(p) for p in packages] != sorted(str(p) for p in packages):
            errors.append(f"{where}: packages not sorted")
        if EVERY_PR in packages and len(packages) > 1:
            errors.append(f"{where}: {EVERY_PR!r} must be the only package")
        for package, value in packages.items():
            if not isinstance(package, str) or not (
                package == EVERY_PR or _PACKAGE_RE.fullmatch(package)
            ):
                errors.append(f"{where}: {package!r} is not a package name or glob")
            if value is not None:
                errors.append(f"{where}: {package}: values are not supported yet")
    return errors


def match(config: Config, packages: frozenset[str]) -> dict[str, tuple[str, ...]]:
    """The reviewers of the entries which match a PR, each with the packages they
    matched. An entry which lists "*" matches every PR, with no packages in particular."""
    matched: dict[str, set[str]] = {}
    for entry in config.entries:
        if EVERY_PR in entry.packages:
            pkgs = set()
        else:
            pkgs = {p for p in packages if any(fnmatch.fnmatchcase(p, g) for g in entry.packages)}
            if not pkgs:
                continue
        for reviewer in entry.reviewers:
            matched.setdefault(reviewer, set()).update(pkgs)
    return {r: tuple(sorted(matched[r])) for r in sorted(matched, key=str.lower)}


def package_of(path: str) -> str | None:
    """The package a changed file belongs to, if it is a slice or a spread test."""
    m = _SLICE_PATH_RE.fullmatch(path) or _TEST_PATH_RE.fullmatch(path)
    return m.group(1) if m else None


class GitHub:
    """Minimal GitHub REST client. Requests are stateless so it is thread safe."""

    def __init__(self, repo: str, token: str | None) -> None:
        self.repo = repo
        self.headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if token:
            self.headers["Authorization"] = f"Bearer {token}"

    def _url(self, path: str) -> str:
        return f"{API_URL}/repos/{self.repo}/{path}"

    def get(self, path: str) -> dict:
        response = requests.get(self._url(path), headers=self.headers, timeout=30)
        response.raise_for_status()
        return response.json()

    def get_all(self, path: str, params: dict | None = None) -> list[dict]:
        """GET every page of a list endpoint."""
        url: str | None = self._url(path)
        params = {"per_page": 100, **(params or {})}
        results: list[dict] = []
        while url:
            response = requests.get(url, headers=self.headers, params=params, timeout=30)
            response.raise_for_status()
            results.extend(response.json())
            url = response.links.get("next", {}).get("url")
            params = None  # the next link carries the query
        return results

    def post(self, path: str, body: dict) -> requests.Response:
        return requests.post(self._url(path), headers=self.headers, json=body, timeout=30)


@dataclass(frozen=True)
class PR:
    number: int
    author: str
    branch: str
    packages: frozenset[str]
    # Everyone who was ever requested on the PR or reviewed it. Logins are
    # lowercased, since GitHub treats them case-insensitively.
    seen_users: frozenset[str]
    seen_teams: frozenset[str]


@dataclass(frozen=True)
class Request:
    number: int
    # user login / team slug -> the PR's packages they matched
    users: dict[str, tuple[str, ...]]
    teams: dict[str, tuple[str, ...]]


def is_triageable(data: dict) -> bool:
    return (
        data.get("state") == "open"
        and not data.get("draft", False)
        and data["base"]["ref"].startswith("ubuntu-")
    )


def seen_reviewers(pr: dict, timeline: list[dict]) -> tuple[set[str], set[str]]:
    """Users and teams that were requested on the PR, or reviewed it, at any point."""
    users = {u["login"].lower() for u in pr.get("requested_reviewers", [])}
    teams = {t["slug"] for t in pr.get("requested_teams", [])}
    for event in timeline:
        kind = event.get("event")
        if kind in ("review_requested", "review_request_removed"):
            if reviewer := event.get("requested_reviewer"):
                users.add(reviewer["login"].lower())
            if team := event.get("requested_team"):
                teams.add(team["slug"])
        elif kind == "reviewed" and event.get("user"):
            users.add(event["user"]["login"].lower())
    return users, teams


def fetch_pr(gh: GitHub, data: dict) -> PR:
    number = data["number"]
    files = gh.get_all(f"pulls/{number}/files")
    paths = {f["filename"] for f in files}
    paths |= {f["previous_filename"] for f in files if f.get("previous_filename")}
    timeline = gh.get_all(f"issues/{number}/timeline")
    users, teams = seen_reviewers(data, timeline)
    return PR(
        number=number,
        author=data["user"]["login"],
        branch=data["base"]["ref"],
        packages=frozenset(filter(None, map(package_of, paths))),
        seen_users=frozenset(users),
        seen_teams=frozenset(teams),
    )


def plan(config: Config, pr: PR) -> Request | None:
    """The reviewers still to be requested on a PR, if any."""
    skip = pr.seen_users | {pr.author.lower()}
    users: dict[str, tuple[str, ...]] = {}
    teams: dict[str, tuple[str, ...]] = {}
    for reviewer, pkgs in match(config, pr.packages).items():
        if "/" in reviewer:
            # the API takes the slug alone, the org is the repo's
            slug = reviewer.split("/", 1)[1]
            if slug not in pr.seen_teams:
                teams[slug] = pkgs
        elif reviewer.lower() not in skip:
            users[reviewer] = pkgs
    if not users and not teams:
        return None
    return Request(number=pr.number, users=users, teams=teams)


def apply(gh: GitHub, request: Request) -> bool:
    """Request the reviews. One invalid reviewer fails the whole call, so on a
    rejection each reviewer is retried on their own. Returns False if any failed."""
    path = f"pulls/{request.number}/requested_reviewers"
    body = {"reviewers": list(request.users), "team_reviewers": list(request.teams)}
    response = gh.post(path, body)
    if response.ok:
        return True
    if response.status_code != 422:
        logging.error("#%d: %d %s", request.number, response.status_code, response.text)
        return False

    ok = True
    singles = [{"reviewers": [u]} for u in request.users]
    singles += [{"team_reviewers": [t]} for t in request.teams]
    for single in singles:
        response = gh.post(path, single)
        if not response.ok:
            ok = False
            who = (single.get("reviewers") or single.get("team_reviewers"))[0]
            logging.error("#%d: cannot request %s: %s", request.number, who, response.text)
    return ok


def describe(pr: PR, request: Request) -> str:
    def who(name: str, packages: tuple[str, ...]) -> str:
        return f"{name} ({', '.join(packages)})" if packages else name

    parts = [who(u, pkgs) for u, pkgs in request.users.items()]
    parts += [who(f"team {t}", pkgs) for t, pkgs in request.teams.items()]
    return f"#{pr.number} ({pr.branch}): request " + "; ".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.getenv("GH_REPO", DEFAULT_REPO))
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    target = parser.add_mutually_exclusive_group()
    target.add_argument(
        "--pr", type=int, action="append", help="triage only this PR (repeatable)"
    )
    target.add_argument(
        "--head", help="triage only the open PRs from this head, as <owner>:<branch>"
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="request the reviews. Without this flag, only print what would be requested.",
    )
    args = parser.parse_args()

    try:
        config = Config.load(args.config)
    except ConfigError as e:
        logging.error("%s", e)
        return 1

    gh = GitHub(args.repo, os.getenv("GITHUB_TOKEN"))
    if args.pr:
        candidates = [gh.get(f"pulls/{n}") for n in args.pr]
    elif args.head:
        candidates = gh.get_all("pulls", {"state": "open", "head": args.head})
    else:
        candidates = gh.get_all("pulls", {"state": "open"})
    candidates = [c for c in candidates if is_triageable(c)]
    logging.info("triaging %d PRs", len(candidates))

    def _fetch(data: dict) -> PR | None:
        try:
            return fetch_pr(gh, data)
        except requests.RequestException as e:
            logging.error("#%d: cannot fetch: %s", data["number"], e)
            return None

    with ThreadPoolExecutor(max_workers=5) as executor:
        fetched = list(executor.map(_fetch, candidates))

    ok = None not in fetched
    for pr in sorted(filter(None, fetched), key=lambda p: p.number):
        request = plan(config, pr)
        if request is None:
            continue
        logging.info("%s", describe(pr, request))
        if args.apply:
            ok &= apply(gh, request)
    return 0 if ok else 1


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    sys.exit(main())
