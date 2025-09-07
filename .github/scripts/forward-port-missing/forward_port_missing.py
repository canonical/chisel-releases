#!/usr/bin/env python3
"""
Check labels on PRs and forward-port if needed.

This the read-only part of the forward porting check.
It pulls the data form relevant places, executes the logic and outputs
the results in text/json format.

This script will use the `GITHUB_TOKEN` variable if set.
"""
# spell-checker: ignore Marcin Konowalczyk lczyk
# spell-checker: words levelname
# mypy: disable-error-code="unused-ignore"

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
from collections.abc import Iterable, Iterator, Mapping
from contextlib import contextmanager
from dataclasses import dataclass, field
from functools import total_ordering
from html.parser import HTMLParser
from itertools import product
from typing import TYPE_CHECKING, Any, Callable

__version__ = "0.0.12"
__author__ = "Marcin Konowalczyk"

__changelog__ = [
    ("0.0.12", "fix more grouping bugs", "@lczyk"),
    ("0.0.11", "grouping bug + handle non-ascii in titles", "@lczyk"),
    ("0.0.10", "print the fp label status", "@lczyk"),
    ("0.0.9", "fix crash on prs with no new slices", "@lczyk"),
    ("0.0.8", "output formatting + bugfixes", "@lczyk"),
    ("0.0.7", "fetching package lists for FP missing releases", "@lczyk"),
    ("0.0.6", "main forward-porting logic implemented", "@lczyk"),
    ("0.0.5", "slice diff from the merge base, not the branch head", "@lczyk"),
    ("0.0.4", "--jobs for parallel slice fetching", "@lczyk"),
    ("0.0.3", "get_slices_in_pr implemented", "@lczyk"),
    ("0.0.2", "currently_supported_ubuntu_releases implemented", "@lczyk"),
    ("0.0.1", "initial testing", "@lczyk"),
    ("0.0.0", "boilerplate", "@lczyk"),
]

################################################################################


@total_ordering
@dataclass(frozen=True, order=False)
class UbuntuRelease:
    version: str
    codename: str

    def __str__(self) -> str:
        return f"ubuntu-{self.version} ({self.codename})"

    @property
    def version_tuple(self) -> tuple[int, int]:
        return self.version_to_tuple(self.version)

    @staticmethod
    def version_to_tuple(version: str) -> tuple[int, int]:
        year, month = version.split(".")
        return int(year), int(month)

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, UbuntuRelease):
            return NotImplemented
        return self.version_tuple < other.version_tuple

    @classmethod
    def from_branch_name(cls, branch: str) -> UbuntuRelease:
        """Create an UbuntuRelease from a branch name like 'ubuntu-20.04'."""
        assert branch.startswith("ubuntu-"), "Branch name must start with 'ubuntu-'"
        version = branch.split("-", 1)[1]
        try:
            _ = cls.version_to_tuple(version)
        except Exception as e:
            raise ValueError(f"Invalid Ubuntu version '{version}' for branch '{branch}': {e}") from None
        codename = _VERSION_TO_CODENAME.get(version)
        if codename is None:
            raise ValueError(f"Unknown Ubuntu version '{version}' for branch '{branch}'")
        return cls(version=version, codename=codename)


## CONSTANTS ###################################################################

# List of ubuntu versions so we don't have to fetch them all the time.
# spell-checker: ignore dists utopic yakkety eoan
KNOWN_RELEASES = {
    UbuntuRelease("14.04", "trusty"),
    UbuntuRelease("14.10", "utopic"),
    UbuntuRelease("15.04", "vivid"),
    UbuntuRelease("15.10", "wily"),
    UbuntuRelease("16.04", "xenial"),
    UbuntuRelease("16.10", "yakkety"),
    UbuntuRelease("17.04", "zesty"),
    UbuntuRelease("17.10", "artful"),
    UbuntuRelease("18.04", "bionic"),
    UbuntuRelease("18.10", "cosmic"),
    UbuntuRelease("19.04", "disco"),
    UbuntuRelease("19.10", "eoan"),
    UbuntuRelease("20.04", "focal"),
    UbuntuRelease("20.10", "groovy"),
    UbuntuRelease("21.04", "hirsute"),
    UbuntuRelease("21.10", "impish"),
    UbuntuRelease("22.04", "jammy"),
    UbuntuRelease("22.10", "kinetic"),
    UbuntuRelease("23.04", "lunar"),
    UbuntuRelease("23.10", "mantic"),
    UbuntuRelease("24.04", "noble"),
    UbuntuRelease("24.10", "oracular"),
    UbuntuRelease("25.04", "plucky"),
    UbuntuRelease("25.10", "questing"),
}


ADDITIONAL_VERSIONS_TO_SKIP: set[UbuntuRelease] = {
    UbuntuRelease("24.10", "oracular"),  # EOL
}

_CODENAME_TO_VERSION = {r.codename: r.version for r in KNOWN_RELEASES}
_VERSION_TO_CODENAME = {r.version: r.codename for r in KNOWN_RELEASES}

DISTS_URL = "https://archive.ubuntu.com/ubuntu/dists"

CHISEL_RELEASES_URL = os.environ.get("CHISEL_RELEASES_URL", "https://github.com/canonical/chisel-releases")


FORWARD_PORT_MISSING_LABEL = "forward port missing"

## LIB #########################################################################


# geturl from https://github.com/lczyk/geturl 0.4.5
def geturl(
    url: str,
    params: dict[str, object] | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[int, bytes]:
    """Make a GET request to a URL and return the response and status code."""

    import urllib
    import urllib.error
    import urllib.parse
    import urllib.request

    if params is not None:
        if "?" in url:
            params = dict(params)  # make a modifiable copy
            existing_params = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
            params = {**existing_params, **params}  # params take precedence
            url = url.split("?")[0]
        url = url + "?" + urllib.parse.urlencode(params)

    request = urllib.request.Request(url)
    if headers is not None:
        for h_key, h_value in headers.items():
            request.add_header(h_key, h_value)

    try:
        with urllib.request.urlopen(request) as r:
            code = r.getcode()
            res = r.read()

    except urllib.error.HTTPError as e:
        code = e.code
        res = e.read()

    assert isinstance(code, int), "Expected code to be int."
    assert isinstance(res, bytes), "Expected response to be bytes."

    return code, res

def handle_code(code: int, url: str) -> None:
    if code == 200:
        return
    if code == 404:
        raise Exception(f"Resource not found at '{url}'.")
    if code == 403:
        if "github.com" in url:
            raise Exception(f"Rate limit exceeded for '{url}'. Are you using the GITHUB_TOKEN?")
        else:
            raise Exception(f"Access forbidden to '{url}'.")
    if code == 401:
        if "github.com" in url:
            raise Exception(f"Unauthorized access to '{url}'. Maybe bad credentials? Check GITHUB_TOKEN.")
        else:
            raise Exception(f"Unauthorized access to '{url}'.")
    raise Exception(f"Failed to fetch '{url}'. HTTP status code: {code}")


@contextmanager
def CatchTime() -> Iterator[Callable[[], float]]:
    """measure elapsed time of a code block
    Adapted from: https://stackoverflow.com/a/69156219/2531987
    CC BY-SA 4.0 https://creativecommons.org/licenses/by-sa/4.0/
    """
    t1 = t2 = time.perf_counter()
    yield lambda: t2 - t1
    t2 = time.perf_counter()


## IMPL ########################################################################


# spell-checker: ignore devel
class DistsParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.dists: set[str] = set()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "a":
            href = dict(attrs).get("href", "")
            if not href or not href.endswith("/") or href.startswith("/"):
                return
            dist = href.strip("/")
            # change, for example "bionic-updates" to just "bionic"
            dist = dist.split("-")[0] if "-" in dist else dist
            if dist == "devel":
                return
            self.dists.add(dist)


def _fallback_get_version(codename: str) -> str:
    """Fetch version and codename from the web as a fallback."""
    logging.warning("Unknown codename %s, trying to fetch version from the web.", codename)
    url = f"{DISTS_URL}/{codename}/Release"
    code, res = geturl(url)
    handle_code(code, url)
    content = res.decode("utf-8")
    for line in content.splitlines():
        if line.startswith("Version:"):
            version = line.split(":", 1)[1].strip()
            return version
    raise Exception(f"Could not find version for codename '{codename}'.")


def get_version(codename: str) -> str:
    if codename in _CODENAME_TO_VERSION:
        return _CODENAME_TO_VERSION[codename]
    return _fallback_get_version(codename)


def currently_supported_ubuntu_releases() -> list[UbuntuRelease]:
    code, res = geturl(DISTS_URL)
    handle_code(code, DISTS_URL)
    parser = DistsParser()
    parser.feed(res.decode("utf-8"))
    out = [(get_version(codename), codename) for codename in parser.dists]
    out.sort()  # sort by version
    return [UbuntuRelease(version=v, codename=c) for v, c in out]


################################################################################


@dataclass(frozen=True, unsafe_hash=True)
class Commit:
    ref: str  # Branch name
    repo_name: str  # Name of the repository
    repo_owner: str  # Owner of the repository
    repo_url: str = field(repr=False)  # URL of the repository
    commit: str = field(repr=False)  # SHA of the commit

    @classmethod
    def from_json(cls, data: dict) -> Commit:
        return cls(
            commit=data["sha"],
            ref=data["ref"],
            repo_name=data["repo"]["name"],
            repo_url=data["repo"]["html_url"],
            repo_owner=data["repo"]["owner"]["login"],
        )


@total_ordering
@dataclass(frozen=True, unsafe_hash=True, order=False)
class PR:
    number: int  # number of the PR, e.g #601
    title: str  # title of the PR

    user: str  # user who created the PR (usually, but not necessarily, the author)

    head: Commit
    base: Commit

    label: bool  # whether the PR has the forward-port-missing label

    url: str = field(repr=False)  # URL of the PR

    def __post_init__(self) -> None:
        # Check that head and base are from the same repository
        _ = UbuntuRelease.from_branch_name(self.base.ref)

    @property
    def ubuntu_release(self) -> UbuntuRelease:
        return UbuntuRelease.from_branch_name(self.base.ref)

    @classmethod
    def from_json(cls, data: dict) -> PR:
        head = Commit.from_json(data["head"])
        base = Commit.from_json(data["base"])

        labels = data.get("labels", [])
        label = any(label.get("name") == FORWARD_PORT_MISSING_LABEL for label in labels)
        return cls(
            url=data["html_url"],
            number=data["number"],
            title=data["title"],
            user=data["user"]["login"],
            head=head,
            base=base,
            label=label,
        )

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, PR):
            return NotImplemented
        return self.number < other.number


def get_merge_base(base: Commit, head: Commit) -> str:
    """Get the SHA of the merge base between head and base."""
    url = (
        f"https://api.github.com/repos/{base.repo_owner}/{base.repo_name}/compare/"
        f"{base.repo_owner}:{base.ref}...{head.repo_owner}:{head.ref}?per_page=1"
    )
    code, res = geturl_github(url)
    handle_code(code, url)
    parsed_result = json.loads(res.decode("utf-8"))
    assert isinstance(parsed_result, dict), "Expected response to be a dict."
    if "merge_base_commit" not in parsed_result:
        raise Exception(f"Could not find merge_base_commit in response from '{url}'.")
    merge_base_commit = parsed_result["merge_base_commit"]
    assert isinstance(merge_base_commit, dict), "Expected merge_base_commit to be a dict."
    if "sha" not in merge_base_commit:
        raise Exception(f"Could not find sha in merge_base_commit from '{url}'.")
    sha = merge_base_commit["sha"]
    assert isinstance(sha, str), "Expected sha to be a str."
    return sha


def check_github_token() -> None:
    token = os.getenv("GITHUB_TOKEN", None)
    if token is not None:
        logging.debug("GITHUB_TOKEN is set.")
        if not token.strip():
            logging.warning("GITHUB_TOKEN is empty.")
    else:
        logging.debug("GITHUB_TOKEN is not set.")


def geturl_github(url: str, params: dict[str, object] | None = None) -> tuple[int, bytes]:
    assert "github.com" in url, "Only GitHub URLs are supported."
    url = url.replace("github.com", "api.github.com/repos") if "api.github.com" not in url else url
    url = url.rstrip("/")
    headers = {"Accept": "application/vnd.github.v3+json", "X-GitHub-Api-Version": "2022-11-28"}
    github_token = os.getenv("GITHUB_TOKEN", None)
    if github_token:
        headers["Authorization"] = f"Bearer {github_token}"
    return geturl(url, params=params, headers=headers)


def ubuntu_branches_in_chisel_releases() -> set[UbuntuRelease]:
    code, res = geturl_github(f"{CHISEL_RELEASES_URL}/branches", params={"per_page": 100})
    handle_code(code, CHISEL_RELEASES_URL)
    parsed_result = json.loads(res.decode("utf-8"))
    assert isinstance(parsed_result, list), "Expected response to be a list of branches."
    branches = {branch["name"] for branch in parsed_result if branch["name"].startswith("ubuntu-")}
    ubuntu_releases = set()
    for branch in branches:
        version = branch.split("-", 1)[1]
        codename = _VERSION_TO_CODENAME.get(version, "unknown")
        ubuntu_releases.add(UbuntuRelease(version, codename))
    return ubuntu_releases


def get_all_prs(url: str, per_page: int = 100) -> set[PR]:
    """Fetch all PRs from the remote repository using the GitHub API. The url
    should be the URL of the repository, e.g. www.github.com/canonical/chisel-releases.
    """
    assert per_page > 0, "per_page must be a positive integer."
    url = url.rstrip("/") + "/pulls"

    params = {"state": "open", "per_page": per_page, "page": 1}

    results = []
    while True:
        code, result = geturl_github(url, params=params)
        handle_code(code, url)
        parsed_result = json.loads(result.decode("utf-8"))
        assert isinstance(parsed_result, list), "Expected response to be a list of PRs."
        results.extend(parsed_result)
        if len(parsed_result) < per_page:
            break
        params["page"] += 1  # type: ignore

    # filter down to PRs into branches named "ubuntu-XX.XX"
    results = [pr for pr in results if pr["base"]["ref"].startswith("ubuntu-")]
    # filter out draft PRs
    results = [pr for pr in results if not pr.get("draft", False)]

    return set(PR.from_json(pr) for pr in results)


################################################################################


def get_slices(repo_owner: str, repo_name: str, ref: str) -> set[str]:
    """Get the list of files in the /slices directory in the given ref.
    ref can be a branch name, tag name, or commit SHA.
    """

    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/contents/slices"
    code, res = geturl_github(
        url,
        params={"ref": ref},
    )
    handle_code(code, url)
    parsed_result = json.loads(res.decode("utf-8"))
    assert isinstance(parsed_result, list), "Expected response to be a list of files."

    files = {item["name"] for item in parsed_result if item["type"] == "file"}
    files = {f.removesuffix(".yaml") for f in files if f.endswith(".yaml")}
    return files


def get_merge_bases_by_pr(prs: set[PR], jobs: int | None = 1) -> dict[PR, str]:
    logging.info("Fetching merge bases for %d PRs...", len(prs))
    merge_bases_by_pr: dict[PR, str] = {}

    with CatchTime() as elapsed:
        if jobs == 1:
            # NOTE: it is much nicer to debug/profile without parallelism
            merge_bases_by_pr = {pr: get_merge_base(pr.base, pr.head) for pr in prs}
        else:
            from concurrent.futures import ThreadPoolExecutor

            _prs = list(prs)  # we want list for zipping with results
            with ThreadPoolExecutor(max_workers=jobs) as executor:
                logging.debug("Using a thread pool of size %d.", getattr(executor, "_max_workers", -1))
                results = list(executor.map(lambda pr: get_merge_base(pr.base, pr.head), _prs))
            merge_bases_by_pr = {pr: mb for pr, mb in zip(_prs, results)}

    logging.info("Fetched merge bases for %d PRs in %.2f seconds.", len(prs), elapsed())
    for pr, mb in merge_bases_by_pr.items():
        if pr.base.commit != mb:
            logging.warning(
                "PR #%d: base branch '%s' has advanced since the PR was created/updated. Consider rebasing.",
                pr.number,
                pr.base.ref,
            )

    return merge_bases_by_pr


def get_slices_by_pr(
    prs: set[PR],
    merge_bases_by_pr: dict[PR, str],
    jobs: int | None = 1,
) -> tuple[dict[PR, set[str]], dict[PR, set[str]]]:
    # For each PR, get the list of files in the /slices directory in the base branch
    slices_in_head_by_pr: dict[PR, set[str]] = {}
    slices_in_base_by_pr: dict[PR, set[str]] = {}
    get_slices_base = lambda pr: get_slices(pr.base.repo_owner, pr.base.repo_name, merge_bases_by_pr[pr])
    get_slices_head = lambda pr: get_slices(pr.head.repo_owner, pr.head.repo_name, pr.head.ref)

    with CatchTime() as elapsed:
        if jobs == 1:
            # NOTE: it is much nicer to debug/profile without parallelism
            slices_in_head_by_pr = {pr: get_slices_head(pr) for pr in prs}
            slices_in_base_by_pr = {pr: get_slices_base(pr) for pr in prs}

        else:
            from concurrent.futures import ThreadPoolExecutor

            _prs = list(prs)  # we want list for zipping with results
            with ThreadPoolExecutor(max_workers=jobs) as executor:
                logging.debug("Using a thread pool of size %d.", getattr(executor, "_max_workers", -1))
                results_head = list(executor.map(get_slices_head, _prs))
                results_base = list(executor.map(get_slices_base, _prs))

            slices_in_head_by_pr = {pr: slices for pr, slices in zip(_prs, results_head)}
            slices_in_base_by_pr = {pr: slices for pr, slices in zip(_prs, results_base)}

    total_slices = sum(len(slices) for slices in slices_in_head_by_pr.values())
    total_slices += sum(len(slices) for slices in slices_in_base_by_pr.values())
    logging.info("Fetched %d slices for %d PRs in %.2f seconds.", total_slices, len(prs), elapsed())

    return slices_in_head_by_pr, slices_in_base_by_pr


def group_new_slices_by_pr(
    slices_in_head_by_pr: dict[PR, set[str]],
    slices_in_base_by_pr: dict[PR, set[str]],
) -> dict[PR, frozenset[str]]:
    prs: set[PR] = set(slices_in_head_by_pr.keys())
    if set(slices_in_base_by_pr.keys()) != prs:
        raise ValueError("slices_in_head_by_pr and slices_in_base_by_pr must have the same keys.")
    new_slices_by_pr: dict[PR, frozenset[str]] = {}
    for pr in sorted(prs):
        slices_in_head = slices_in_head_by_pr.get(pr, set())
        slices_in_base = slices_in_base_by_pr.get(pr, set())
        new_slices = slices_in_head - slices_in_base
        removed_sliced = slices_in_base - slices_in_head
        if removed_sliced and logging.getLogger().isEnabledFor(logging.WARNING):
            slices_string = ", ".join(sorted(removed_sliced))
            slices_string = slices_string if len(slices_string) < 100 else slices_string[:97] + "..."
            logging.warning("PR #%d removed %d slices: %s", pr.number, len(removed_sliced), slices_string)
        if new_slices:
            new_slices_by_pr[pr] = frozenset(new_slices)
            if logging.getLogger().isEnabledFor(logging.DEBUG):
                slices_string = ", ".join(sorted(new_slices))
                slices_string = slices_string if len(slices_string) < 100 else slices_string[:97] + "..."
                logging.debug("PR #%d introduces %d new slices: %s", pr.number, len(new_slices), slices_string)
        else:
            logging.debug("PR #%d introduces no new slices.", pr.number)
    return new_slices_by_pr


@dataclass(frozen=False, unsafe_hash=True)
class Comparison:
    """A pair of PRs: one into a given release, and one into a future release."""

    pr: PR
    slices: frozenset[str]
    pr_future: PR
    slices_future: frozenset[str]

    # Slices from the ubuntu release of the base PR that have been
    # discontinued in the ubuntu release of the future PR.
    discontinued_slices: frozenset[str] = field(default_factory=frozenset, init=False)

    @property
    def ubuntu_release(self) -> UbuntuRelease:
        return self.pr.ubuntu_release

    @property
    def future_ubuntu_release(self) -> UbuntuRelease:
        return self.pr_future.ubuntu_release

    def __post_init__(self) -> None:
        if self.pr.ubuntu_release >= self.pr_future.ubuntu_release:
            raise ValueError("pr_future must be into a future release compared to pr.")
        self.slices = frozenset(self.slices)
        self.slices_future = frozenset(self.slices_future)

    def is_forward_ported(self) -> bool:
        return not self.missing_slices()

    def __str__(self) -> str:
        return (
            f"#{self.pr.number}-{self.ubuntu_release.version}.."
            f"#{self.pr_future.number}-{self.future_ubuntu_release.version}"
        )

    def missing_slices(self) -> frozenset[str]:
        missing_slices = self.slices - self.slices_future
        if not missing_slices:
            return frozenset()
        if self.discontinued_slices:
            # some slices were discontinued, so they are missing for a reason
            missing_slices -= self.discontinued_slices
        return frozenset(missing_slices)

    def overlap(self) -> frozenset[str]:
        return self.slices.intersection(self.slices_future)


def get_comparisons(
    prs_by_ubuntu_release: Mapping[UbuntuRelease, frozenset[PR]],
    new_slices_by_pr: Mapping[PR, frozenset[str]],
) -> frozenset[Comparison]:
    prs: set[PR] = set()
    for prs_in_release in prs_by_ubuntu_release.values():
        prs.update(prs_in_release)

    # For each PR we have a mapping from ubuntu release to a set of PRs that
    # forward-port the new slices to that release. An empty set means no
    # forward-port found, a set with None means no new slices to forward-port.
    comparisons: set[Comparison] = set()

    for ubuntu_release, prs_in_release in prs_by_ubuntu_release.items():
        future_releases = [r for r in prs_by_ubuntu_release if r > ubuntu_release]
        if not future_releases:
            logging.debug(
                "No future releases for %s. Skipping all %d PRs into it.", ubuntu_release, len(prs_in_release)
            )
            continue

        for pr in prs_in_release:
            new_slices = new_slices_by_pr.get(pr, frozenset())
            for future_release in future_releases:
                prs_into_future_release = prs_by_ubuntu_release.get(future_release, frozenset())
                if not prs_into_future_release:
                    logging.debug("No PRs into future release %s of PR #%d", future_release, pr.number)
                    # No PRs into this future release
                    continue

                for pr_future in prs_into_future_release:
                    new_slices_in_future = new_slices_by_pr.get(pr_future, frozenset())
                    comparisons.add(
                        Comparison(
                            pr=pr,
                            slices=new_slices,
                            pr_future=pr_future,
                            slices_future=new_slices_in_future,
                        )
                    )
    return frozenset(comparisons)


def get_grouped_comparisons(
    prs_by_ubuntu_release: Mapping[UbuntuRelease, frozenset[PR]],
    new_slices_by_pr: Mapping[PR, frozenset[str]],
) -> Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]]:
    comparisons = get_comparisons(prs_by_ubuntu_release, new_slices_by_pr)

    # For convenience we group the comparisons by the PR in the current release, and then by the future release.
    grouped_comparisons: dict[PR, dict[UbuntuRelease, set[Comparison]]] = {}
    for comparison in comparisons:
        pr = comparison.pr
        future_release = comparison.future_ubuntu_release
        if pr not in grouped_comparisons:
            grouped_comparisons[pr] = {}
        if future_release not in grouped_comparisons[pr]:
            grouped_comparisons[pr][future_release] = set()
        grouped_comparisons[pr][future_release].add(comparison)

    # We may not have all the PRs in the grouped_comparisons, since they may not have had any PRs to compare to.
    # We need to add them with empty dicts.
    for prs_in_release in prs_by_ubuntu_release.values():
        for pr in prs_in_release:
            if pr not in grouped_comparisons:
                grouped_comparisons[pr] = {}

    # For each of the dicts in grouped_comparisons, we want all of the future releases, even if there are no comparisons
    for pr, comparisons_by_future_release in grouped_comparisons.items():
        ubuntu_release = pr.ubuntu_release
        future_releases = [r for r in prs_by_ubuntu_release if r > ubuntu_release]
        for future_release in future_releases:
            if future_release not in comparisons_by_future_release:
                comparisons_by_future_release[future_release] = set()
    return {
        pr: {r: frozenset(comparison) for r, comparison in future_releases.items()}
        for pr, future_releases in grouped_comparisons.items()
    }


def get_packages_by_release(
    releases: set[UbuntuRelease],
    jobs: int | None = 1,
) -> dict[UbuntuRelease, set[str]]:
    package_listings: dict[tuple[UbuntuRelease, str, str], set[str]] = {}

    _components = ("main", "restricted", "universe", "multiverse")
    _repos = ("", "security", "updates", "backports")
    _product = list(product(releases, _components, _repos))

    with CatchTime() as elapsed:
        if jobs == 1:
            for release, component, repo in _product:
                package_listings[(release, component, repo)] = get_package_content(release, component, repo)

        else:
            from concurrent.futures import ThreadPoolExecutor

            with ThreadPoolExecutor(max_workers=jobs) as executor:
                logging.debug("Using a thread pool of size %d.", getattr(executor, "_max_workers", -1))
                results = list(
                    executor.map(lambda args: get_package_content(*args), _product)  # type: ignore
                )
            package_listings = {args: pkgs for args, pkgs in zip(_product, results)}

    logging.info("Fetched packages for %d releases in %.2f seconds.", len(releases), elapsed())

    # Union all components and repos
    packages_by_release: dict[UbuntuRelease, set[str]] = {r: set() for r in releases}
    for (release, _component, _repo), packages in package_listings.items():
        packages_by_release[release].update(packages)

    return packages_by_release


if TYPE_CHECKING:
    import re

_package_re_cache: re.Pattern[str] | None = None  # cache for the compiled regex


def get_package_content(release: UbuntuRelease, component: str, repo: str) -> set[str]:
    if component not in ("main", "restricted", "universe", "multiverse"):
        raise ValueError(
            f"Invalid component: {component}. Must be one of 'main', 'restricted', 'universe', or 'multiverse'."
        )
    if repo not in ("", "security", "updates", "backports"):
        raise ValueError(f"Invalid repo: {repo}. Must be one of '', 'security', 'updates', or 'backports'.")

    logging.debug("Fetching packages for %s, component=%s, repo=%s", release, component, repo or "<none>")

    name = release.codename
    name = f"{name}-{repo}" if repo else name

    package_url = f"https://archive.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64/Packages.gz"
    code, res = geturl(package_url)

    if code != 200:
        # retry with old-releases if not found in archive
        package_url = f"https://old-releases.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64/Packages.gz"
        code, res = geturl(package_url)

    if code != 200:
        raise RuntimeError(f"Failed to download package list from '{package_url}'. HTTP status code: {code}")

    import gzip
    import io
    import re

    with gzip.GzipFile(fileobj=io.BytesIO(res)) as f:
        content = f.read().decode("utf-8")

    global _package_re_cache  # noqa: PLW0603
    if _package_re_cache:
        package_re = _package_re_cache
    else:
        package_re = re.compile(r"^Package:\s*(\S+)", re.MULTILINE)
        _package_re_cache = package_re

    return set(m.group(1) for m in package_re.finditer(content))


# we don't own the apis we call so, during development, its only polite to cache
if os.environ.get("USE_MEMORY", "0") in ("1", "true", "True", "TRUE"):
    from joblib import Memory

    memory = Memory(".memory", verbose=0)
    geturl = memory.cache(geturl)  # type: ignore
    # we don't really need to cache `get_package_content` that much, but
    # the gzip can be a bit slow
    get_package_content = memory.cache(get_package_content)  # type: ignore


def group_prs_by_ubuntu_release(
    prs: set[PR], ubuntu_releases: list[UbuntuRelease]
) -> dict[UbuntuRelease, frozenset[PR]]:
    _prs_by_ubuntu_release: dict[UbuntuRelease, set[PR]] = {ubuntu_release: set() for ubuntu_release in ubuntu_releases}
    _prs = list(sorted(prs))  # we want list for logging
    for pr in _prs:
        ubuntu_release = UbuntuRelease.from_branch_name(pr.base.ref)
        if ubuntu_release not in _prs_by_ubuntu_release:
            prs.discard(pr)
            logging.warning("PR #%d is into unsupported Ubuntu release %s. Skipping.", pr.number, ubuntu_release)
            continue
        _prs_by_ubuntu_release[ubuntu_release].add(pr)
    prs_by_ubuntu_release: dict[UbuntuRelease, frozenset[PR]] = {
        k: frozenset(v) for k, v in _prs_by_ubuntu_release.items()
    }

    # filter out releases with no PRs
    # prs_by_ubuntu_release = {k: v for k, v in prs_by_ubuntu_release.items() if len(v) > 0}

    # Make sure we have all the ubuntu_releases as keys, even if they have no PRs
    for ubuntu_release in ubuntu_releases:
        if ubuntu_release not in prs_by_ubuntu_release:
            prs_by_ubuntu_release[ubuntu_release] = frozenset()

    return prs_by_ubuntu_release


def add_discontinued_slices(
    grouped_comparisons: Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]],
    packages_by_release: Mapping[UbuntuRelease, set[str]],
) -> None:
    # if we have a bunch of PRs with missing forward-ports, they *might* be
    # missing because the package is just not in the newer release.
    # NOTE: we don't need to fetch the packages for all releases, just
    #       for the *future* releases that are missing forward-ports.

    # prs_with_no_forward_ports: dict[PR, list[UbuntuRelease]] = {}
    # for pr, comparisons_by_future in grouped_comparisons.items():
    #     for future_release, comparisons in comparisons_by_future.items():
    #         for comparison in comparisons:
    #             if comparison.missing_slices():
    #                 prs_with_no_forward_ports.setdefault(pr, []).append(future_release)

    # if not prs_with_no_forward_ports:
    #     return

    # releases_to_fetch: set[UbuntuRelease] = set()
    # for future_releases in prs_with_no_forward_ports.values():
    #     for future_release in future_releases:
    #         releases_to_fetch.add(future_release)

    # # Sanity check. If we have gotten got here, we should have at least one release to fetch.
    # assert releases_to_fetch, "Expected at least one release to fetch packages for."
    # packages_by_release = get_packages_by_release(releases_to_fetch, jobs)

    if logging.getLogger().isEnabledFor(logging.DEBUG):
        for release, packages in packages_by_release.items():
            logging.debug("Release %s has %d packages.", release, len(packages))

    for pr, results_by_future in grouped_comparisons.items():
        for future_release, comparisons in results_by_future.items():
            packages = packages_by_release.get(future_release, set())
            if not packages:
                logging.debug(
                    "PR #%d into %s: No packages found for future release %s.",
                    pr.number,
                    pr.base.ref,
                    future_release,
                )
                continue
            _comparison = next(iter(comparisons), None)
            if not _comparison:
                continue
            discontinued_slices = _comparison.slices - packages
            if not discontinued_slices:
                continue
            if logging.getLogger().isEnabledFor(logging.DEBUG):
                slices_string = ", ".join(sorted(discontinued_slices))
                slices_string = slices_string if len(slices_string) < 100 else slices_string[:97] + "..."
                logging.debug(
                    "Adding %d discontinued slices for PR #%d into %s for future release %s: %s",
                    len(discontinued_slices),
                    pr.number,
                    pr.base.ref,
                    future_release,
                    slices_string,
                )

            for comparison in comparisons:
                comparison.discontinued_slices = frozenset(discontinued_slices)


## MAIN ########################################################################


def main(args: argparse.Namespace) -> None:
    ubuntu_releases = currently_supported_ubuntu_releases()
    ubuntu_branches = ubuntu_branches_in_chisel_releases()

    if logging.getLogger().isEnabledFor(logging.DEBUG):
        ubuntu_releases_str = ", ".join(str(r) for r in ubuntu_releases)
        logging.debug(
            "Found %d supported Ubuntu releases in the archives %s", len(ubuntu_releases), ubuntu_releases_str
        )
        ubuntu_branches_str = ", ".join(str(r) for r in sorted(ubuntu_branches))
        logging.debug("Found %d Ubuntu branches in chisel-releases: %s", len(ubuntu_branches), ubuntu_branches_str)
        will_drop = set(ubuntu_releases) - ubuntu_branches
        if will_drop:
            will_drop_str = ", ".join(str(r) for r in sorted(will_drop))
            logging.debug("Will drop %d supported releases without branches: %s", len(will_drop), will_drop_str)

    ubuntu_releases = [r for r in ubuntu_releases if r in ubuntu_branches]

    if ADDITIONAL_VERSIONS_TO_SKIP:
        logging.info("Skipping additional versions: %s", ", ".join(str(r) for r in ADDITIONAL_VERSIONS_TO_SKIP))

    ubuntu_releases = [r for r in ubuntu_releases if r not in ADDITIONAL_VERSIONS_TO_SKIP]

    logging.info(
        "Considering %d supported Ubuntu releases with branches in chisel-releases: %s",
        len(ubuntu_releases),
        ", ".join(str(r) for r in ubuntu_releases),
    )

    prs = get_all_prs(CHISEL_RELEASES_URL)
    logging.info("Found %d open PRs in %s", len(prs), CHISEL_RELEASES_URL)

    prs_by_ubuntu_release = group_prs_by_ubuntu_release(prs, ubuntu_releases)

    merge_bases_by_pr = get_merge_bases_by_pr(prs, args.jobs)
    slices_in_head_by_pr, slices_in_base_by_pr = get_slices_by_pr(prs, merge_bases_by_pr, args.jobs)
    packages_by_release = get_packages_by_release(set(prs_by_ubuntu_release.keys()), args.jobs)

    del prs, merge_bases_by_pr

    # Log some info
    for ubuntu_release, prs_in_release in prs_by_ubuntu_release.items():
        logging.info("Found %d open PRs into %s", len(prs_in_release), ubuntu_release)
        for pr in prs_in_release:
            logging.info(
                "  #%d: %s (%d slices in head, %d slices in merge base)",
                pr.number,
                pr.title,
                len(slices_in_head_by_pr.get(pr, set())),
                len(slices_in_base_by_pr.get(pr, set())),
            )

    new_slices_by_pr = group_new_slices_by_pr(slices_in_head_by_pr, slices_in_base_by_pr)

    del slices_in_head_by_pr, slices_in_base_by_pr

    grouped_comparisons = get_grouped_comparisons(prs_by_ubuntu_release, new_slices_by_pr)

    add_discontinued_slices(grouped_comparisons, packages_by_release)

    # Output
    formatter: JSONOutputFormatter | TextOutputFormatter
    if args.format == "json":
        formatter = JSONOutputFormatter(grouped_comparisons, new_slices_by_pr, add_extra_info=False)
    else:
        formatter = TextOutputFormatter(grouped_comparisons, new_slices_by_pr)

    # Print to stdout. Make sure we work with pipes.
    # https://docs.python.org/3/library/signal.html#note-on-sigpipe
    # spellchecker: ignore WRONLY
    try:
        print(formatter.format())
        sys.stdout.flush()
    except BrokenPipeError:
        # Gracefully handle broken pipe when e.g. piping to head
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(1)


def forward_porting_status(
    pr: PR,
    slices: frozenset[str],
    comparisons_by_future_release: Mapping[UbuntuRelease, Iterable[Comparison]],
) -> bool:
    """Each ubuntu release must have at least one comparison with no missing slices."""

    if not slices:
        return True

    for comparisons in comparisons_by_future_release.values():
        if not any(c.is_forward_ported() for c in comparisons):
            return False
    return True


################################################################################


class JSONOutputFormatter:
    def __init__(
        self,
        grouped_comparisons: Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]],
        new_slices_by_pr: Mapping[PR, frozenset[str]],
        add_extra_info: bool = False,
    ) -> None:
        self.grouped_comparisons = grouped_comparisons
        self.new_slices_by_pr = new_slices_by_pr
        self.add_extra_info = add_extra_info

    @staticmethod
    def pr_to_dict(pr: PR) -> dict[str, Any]:
        return {
            "number": pr.number,
            "title": pr.title,
            "url": pr.url,
            "base": pr.base.ref,
            "head": f"{pr.head.repo_owner}/{pr.head.repo_name}/{pr.head.ref}",
        }

    def format(self) -> str:
        output = []
        for pr, comparisons_by_future_release in sorted(self.grouped_comparisons.items()):
            output_pr: dict = JSONOutputFormatter.pr_to_dict(pr)
            output_pr["forward_ported"] = forward_porting_status(
                pr,
                self.new_slices_by_pr.get(pr, frozenset()),
                comparisons_by_future_release,
            )
            output_pr["label"] = pr.label
            output_pr["forward_ports"] = {}
            if self.add_extra_info:
                output_pr["comparisons"] = {}
                output_pr["discontinued"] = {}
                for i, (future_release, comparisons) in enumerate(comparisons_by_future_release.items()):
                    comparison = next(iter(comparisons))
                    discontinued_slices = sorted(comparison.discontinued_slices)
                    output_pr["discontinued"]["ubuntu-" + future_release.version] = discontinued_slices
                    if i == 0:
                        output_pr["slices"] = sorted(comparison.slices)

            for future_release, comparisons in comparisons_by_future_release.items():
                forward_ports = [c for c in comparisons if not c.missing_slices()]
                forward_port_numbers = sorted([c.pr_future.number for c in forward_ports])
                output_pr["forward_ports"]["ubuntu-" + future_release.version] = forward_port_numbers
                if self.add_extra_info:
                    # Add only the interesting comparisons -- those with some overlap or missing slices
                    cmp = []
                    for c in comparisons:
                        missing = c.missing_slices()
                        overlap = c.overlap()
                        if not missing and not overlap:
                            # no slices missing. this happens when the PR has no new slices, or when
                            # all missing slices were discontinued
                            continue
                        if not c.is_forward_ported() and not overlap:
                            # not an interesting comparison
                            continue
                        element: dict = {"number": c.pr_future.number}
                        if overlap:
                            element["overlap"] = sorted(overlap)
                            if missing:
                                element["missing"] = sorted(missing)
                        cmp.append(element)
                    cmp = sorted(cmp, key=lambda r: r["number"])  # type: ignore
                    output_pr["comparisons"]["ubuntu-" + future_release.version] = cmp

            output.append(output_pr)
        return json.dumps(output, indent=2)


class TextOutputFormatter:
    def __init__(
        self,
        grouped_comparisons: Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]],
        new_slices_by_pr: Mapping[PR, frozenset[str]],
    ) -> None:
        self.grouped_comparisons = grouped_comparisons
        self.new_slices_by_pr = new_slices_by_pr

    def format(self) -> str:
        rows: list[str] = []
        for pr, comparisons_by_future_release in sorted(self.grouped_comparisons.items()):
            forward_ported = forward_porting_status(
                pr,
                self.new_slices_by_pr.get(pr, frozenset()),
                comparisons_by_future_release,
            )
            title = pr.title.replace("\n", "_").replace(" ", "_")
            title = "".join(c if 32 <= ord(c) <= 126 else "?" for c in title)
            if len(title) > 40:
                title = title[:37] + "..."
            user = pr.user.replace("\n", "_").replace(" ", "_")
            if len(user) > 15:
                user = user[:12] + "..."
            fp_numbers = [
                c.pr_future.number
                for comparisons in comparisons_by_future_release.values()
                for c in comparisons
                if c.is_forward_ported()
            ]
            fp_numbers_str = ",".join(str(n) for n in sorted(fp_numbers))
            if not fp_numbers_str:
                fp_numbers_str = "-1"
            rows.append(
                f"{pr.number:<4}  {int(forward_ported)}  {int(pr.label):<1}  "
                f"{pr.base.ref:<13}  {user:<15}  {title:<40}  {fp_numbers_str}"
            )

        return "\n".join(rows)


## BOILERPLATE #################################################################


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check labels on PRs and forward-port if needed.",
        epilog="Example: ./forward-port-missing.py --log-level debug",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.add_argument(
        "--log-level",
        type=str,
        default="info",
        choices=["debug", "info", "warning", "error", "fatal", "critical"],
        help="Set the logging level (default: info).",
    )
    parser.add_argument(
        "--jobs",
        "-j",
        type=int,
        default=1,  # -1 = as many as possible, 1 = no parallelism
        help="Number of parallel jobs to use when fetching PR details. Default is 1 (no parallelism).",
    )
    parser.add_argument(
        "--format",
        "-f",
        type=str,
        default="text",
        choices=["text", "json"],
        help="Output format. One of 'text' or 'json'. Default is 'text'.",
    )

    args = parser.parse_args()
    if args.jobs == 0 or args.jobs < -1:
        parser.error("--jobs must be a positive integer or -1 for unlimited.")
    args.jobs = None if args.jobs == -1 else args.jobs  # None = as many as possible
    return args


def setup_logging(log_level: str) -> None:
    _logger = logging.getLogger()
    handler = logging.StreamHandler()
    fmt = "%(asctime)s %(levelname)s %(message)s"
    datefmt = "%Y-%m-%dT%H:%M:%S"
    formatter: type[logging.Formatter] = logging.Formatter
    # Try to use colorlog for colored output
    try:
        import colorlog  # type: ignore

        fmt = fmt.replace("%(levelname)s", "%(log_color)s%(levelname)s%(reset)s")
        formatter = colorlog.ColoredFormatter  # type: ignore
    except ImportError:
        pass

    handler.setFormatter(formatter(fmt, datefmt))  # type: ignore
    _logger.addHandler(handler)
    log_level = "critical" if log_level.lower() == "fatal" else log_level
    _logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))


## ENTRYPOINT ##################################################################

if __name__ == "__main__":
    args = parse_args()
    setup_logging(args.log_level)
    logging.debug("Parsed args: %s", args)
    check_github_token()

    try:
        main(args)

    except NotImplementedError as e:
        logging.error("Not implemented: %s", e)
        sys.exit(99)

    except Exception as e:
        e_str = str(e)
        e_str = e_str or "An unknown error occurred."
        logging.critical(e_str, exc_info=True)
        sys.exit(1)
