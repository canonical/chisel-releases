#!/usr/bin/env python3
"""
Download data for forward-port-missing check.
This script will use the `GITHUB_TOKEN` variable if set.
"""
# spell-checker: ignore Marcin Konowalczyk lczyk
# spell-checker: words levelname
# mypy: disable-error-code="unused-ignore"

from __future__ import annotations

import argparse
import gzip
import io
import json
import logging
import os
import re
import sys
import time
from collections.abc import Iterator, Mapping
from contextlib import contextmanager
from dataclasses import dataclass, field
from functools import total_ordering
from html.parser import HTMLParser
from itertools import product
from pathlib import Path
from typing import TYPE_CHECKING, Callable, Protocol, TypeVar

if TYPE_CHECKING:
    # python 3.9 compatibility
    from typing_extensions import TypeAlias
else:
    TypeAlias = object


__version__ = "0.1.0"
__author__ = "Marcin Konowalczyk"

__changelog__ = [
    ("0.1.0", "split into two scripts", "@lczyk"),
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


_UbuntuReleaseState: TypeAlias = tuple[str, str]
_UbuntuReleaseStateLen = 2


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

    def __getstate__(self) -> _UbuntuReleaseState:
        return (self.version, self.codename)

    def __setstate__(self, state: _UbuntuReleaseState) -> None:
        assert len(state) == _UbuntuReleaseStateLen, "Invalid state length."
        for i, field_name in enumerate(self.__dataclass_fields__):
            object.__setattr__(self, field_name, state[i])


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


_ADDITIONAL_VERSIONS_TO_SKIP: set[UbuntuRelease] = {
    UbuntuRelease("24.10", "oracular"),  # EOL
}

_CODENAME_TO_VERSION = {r.codename: r.version for r in KNOWN_RELEASES}
_VERSION_TO_CODENAME = {r.version: r.codename for r in KNOWN_RELEASES}

ARCHIVE_URL = os.environ.get("ARCHIVE_URL", "https://archive.ubuntu.com/ubuntu/dists")
OLD_ARCHIVE_URL = os.environ.get("OLD_ARCHIVE_URL", "https://old-releases.ubuntu.com/ubuntu/dists")
CHISEL_RELEASES_URL = os.environ.get("CHISEL_RELEASES_URL", "https://github.com/canonical/chisel-releases")

FORWARD_PORT_MISSING_LABEL = "forward port missing"

## LIB #########################################################################


# geturl from https://github.com/lczyk/geturl 0.4.5
def _geturl(
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


def _handle_code(code: int, url: str) -> None:
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
def catch_time() -> Iterator[Callable[[], float]]:
    """measure elapsed time of a code block
    Adapted from: https://stackoverflow.com/a/69156219/2531987
    CC BY-SA 4.0 https://creativecommons.org/licenses/by-sa/4.0/
    """
    t1 = t2 = time.perf_counter()
    yield lambda: t2 - t1
    t2 = time.perf_counter()


## IMPL ########################################################################


# spell-checker: ignore devel
class _DistsParser(HTMLParser):
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
    url = f"{ARCHIVE_URL}/{codename}/Release"
    code, res = _geturl(url)
    _handle_code(code, url)
    content = res.decode("utf-8")
    for line in content.splitlines():
        if line.startswith("Version:"):
            version = line.split(":", 1)[1].strip()
            return version
    raise Exception(f"Could not find version for codename '{codename}'.")


def _get_version(codename: str) -> str:
    if codename in _CODENAME_TO_VERSION:
        return _CODENAME_TO_VERSION[codename]
    return _fallback_get_version(codename)


def _currently_supported_ubuntu_releases() -> list[UbuntuRelease]:
    code, res = _geturl(ARCHIVE_URL)
    _handle_code(code, ARCHIVE_URL)
    parser = _DistsParser()
    parser.feed(res.decode("utf-8"))
    out = [(_get_version(codename), codename) for codename in parser.dists]
    out.sort()  # sort by version
    return [UbuntuRelease(version=v, codename=c) for v, c in out]


################################################################################

_T = TypeVar("_T")


class _TypeConversionDict(dict[str, object]):
    def get_path(self, path: str, t: type[_T]) -> _T:
        """Get a value from a nested dictionary using a dot-separated path."""
        keys = path.split(".")
        _missing = object()
        value: object = _missing
        d: object = self
        for i, key in enumerate(keys):
            if not isinstance(d, dict):
                raise KeyError(f"Key '{key}' not found in path '{path}'.")
            if i < len(keys) - 1:
                d = d.get(key, {})  # type: ignore
            else:
                value = d.get(key, _missing)  # type: ignore
        if value is _missing:
            raise KeyError(f"Key '{path}' not found.")
        if not isinstance(value, t):
            raise TypeError(f"Expected type '{t.__name__}' for key '{path}', got '{type(value).__name__}'.")  # type: ignore
        return value


_CommitState: TypeAlias = tuple[str, str, str, str, str]
_CommitStateLen = 5


@dataclass(frozen=True, unsafe_hash=True)
class Commit:
    ref: str  # Branch name
    repo_name: str  # Name of the repository
    repo_owner: str  # Owner of the repository
    repo_url: str = field(repr=False)  # URL of the repository
    sha: str = field(repr=False)  # SHA of the commit

    @classmethod
    def from_github_json(cls, data: dict[str, object]) -> Commit:
        d = _TypeConversionDict(data)
        return cls(
            sha=d.get_path("sha", str),
            ref=d.get_path("ref", str),
            repo_name=d.get_path("repo.name", str),
            repo_url=d.get_path("repo.html_url", str),
            repo_owner=d.get_path("repo.owner.login", str),
        )

    def __getstate__(self) -> _CommitState:
        return (self.ref, self.repo_name, self.repo_owner, self.repo_url, self.sha)

    def __setstate__(self, state: _CommitState) -> None:
        assert len(state) == _CommitStateLen, "Invalid state length."
        for i, field_name in enumerate(self.__dataclass_fields__):
            object.__setattr__(self, field_name, state[i])


_PRState: TypeAlias = tuple[int, str, str, _CommitState, _CommitState, bool, str, _UbuntuReleaseState]
_PRStateLen = 8


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

    _ubuntu_release: UbuntuRelease | None = field(default=None, init=False, repr=False, compare=False, hash=False)

    def __post_init__(self) -> None:
        # Check that base ref parses to a valid UbuntuRelease and cache it.
        ubuntu_release = UbuntuRelease.from_branch_name(self.base.ref)
        object.__setattr__(self, "_ubuntu_release", ubuntu_release)

    @property
    def ubuntu_release(self) -> UbuntuRelease:
        # This should always be set in __post_init__
        assert self._ubuntu_release is not None, "Ubuntu release not set."
        return self._ubuntu_release

    @classmethod
    def from_github_json(cls, data: dict[str, object]) -> PR:
        d = _TypeConversionDict(data)
        head = Commit.from_github_json(d.get_path("head", dict))  # type: ignore
        base = Commit.from_github_json(d.get_path("base", dict))  # type: ignore

        labels = d.get_path("labels", list)
        label = any(isinstance(label, dict) and label.get("name") == FORWARD_PORT_MISSING_LABEL for label in labels)
        return cls(
            url=d.get_path("html_url", str),
            number=d.get_path("number", int),
            title=d.get_path("title", str),
            user=d.get_path("user.login", str),
            head=head,
            base=base,
            label=label,
        )

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, PR):
            return NotImplemented
        return self.number < other.number

    def __getstate__(self) -> _PRState:
        return tuple(
            getattr(self, field)
            if field not in ("head", "base", "_ubuntu_release")
            else getattr(self, field).__getstate__()
            for field in self.__dataclass_fields__
        )

    def __setstate__(self, state: _PRState) -> None:
        assert len(state) == _PRStateLen, "Invalid state length."
        obj: object
        for i, field_name in enumerate(self.__dataclass_fields__):
            if field_name in ("head", "base"):
                obj = Commit.__new__(Commit)
                obj.__setstate__(state[i])  # type: ignore
                object.__setattr__(self, field_name, obj)
            elif field_name == "_ubuntu_release":
                obj = UbuntuRelease.__new__(UbuntuRelease)
                obj.__setstate__(state[i])  # type: ignore
                object.__setattr__(self, field_name, obj)
            else:
                object.__setattr__(self, field_name, state[i])


def _get_merge_base(base: Commit, head: Commit) -> str:
    """Get the SHA of the merge base between head and base."""
    url = (
        f"https://api.github.com/repos/{base.repo_owner}/{base.repo_name}/compare/"
        f"{base.repo_owner}:{base.ref}...{head.repo_owner}:{head.ref}?per_page=1"
    )
    code, res = _geturl_github(url)
    _handle_code(code, url)
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


def _check_github_token() -> None:
    token = os.getenv("GITHUB_TOKEN", None)
    if token is not None:
        logging.debug("GITHUB_TOKEN is set.")
        if not token.strip():
            logging.warning("GITHUB_TOKEN is empty.")
    else:
        logging.debug("GITHUB_TOKEN is not set.")


def _geturl_github(url: str, params: dict[str, object] | None = None) -> tuple[int, bytes]:
    assert "github.com" in url, "Only GitHub URLs are supported."
    url = url.replace("github.com", "api.github.com/repos") if "api.github.com" not in url else url
    url = url.rstrip("/")
    headers = {"Accept": "application/vnd.github.v3+json", "X-GitHub-Api-Version": "2022-11-28"}
    github_token = os.getenv("GITHUB_TOKEN", None)
    if github_token:
        headers["Authorization"] = f"Bearer {github_token}"
    return _geturl(url, params=params, headers=headers)


def _ubuntu_branches_in_chisel_releases() -> set[UbuntuRelease]:
    code, res = _geturl_github(f"{CHISEL_RELEASES_URL}/branches", params={"per_page": 100})
    _handle_code(code, CHISEL_RELEASES_URL)
    parsed_result = json.loads(res.decode("utf-8"))
    assert isinstance(parsed_result, list), "Expected response to be a list of branches."
    branches = {branch["name"] for branch in parsed_result if branch["name"].startswith("ubuntu-")}
    ubuntu_releases = set()
    for branch in branches:
        version = branch.split("-", 1)[1]
        codename = _VERSION_TO_CODENAME.get(version, "unknown")
        ubuntu_releases.add(UbuntuRelease(version, codename))
    return ubuntu_releases


def _get_all_prs(url: str, per_page: int = 100) -> frozenset[PR]:
    """Fetch all PRs from the remote repository using the GitHub API. The url
    should be the URL of the repository, e.g. www.github.com/canonical/chisel-releases.
    """
    assert per_page > 0, "per_page must be a positive integer."
    url = url.rstrip("/") + "/pulls"

    params = {"state": "open", "per_page": per_page, "page": 1}

    results = []
    while True:
        code, result = _geturl_github(url, params=params)
        _handle_code(code, url)
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

    return frozenset(PR.from_github_json(pr) for pr in results)


################################################################################


def _get_slices(repo_owner: str, repo_name: str, ref: str) -> set[str]:
    """Get the list of files in the /slices directory in the given ref.
    ref can be a branch name, tag name, or commit SHA.
    """

    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/contents/slices"
    code, res = _geturl_github(
        url,
        params={"ref": ref},
    )
    _handle_code(code, url)
    parsed_result = json.loads(res.decode("utf-8"))
    assert isinstance(parsed_result, list), "Expected response to be a list of files."

    files = {item["name"] for item in parsed_result if item["type"] == "file"}
    files = {f.removesuffix(".yaml") for f in files if f.endswith(".yaml")}
    return files


def _get_merge_bases_by_pr(prs: frozenset[PR], jobs: int | None = 1) -> dict[PR, str]:
    logging.info("Fetching merge bases for %d PRs...", len(prs))
    merge_bases_by_pr: dict[PR, str] = {}

    with catch_time() as elapsed:
        if jobs == 1:
            # NOTE: it is much nicer to debug/profile without parallelism
            merge_bases_by_pr = {pr: _get_merge_base(pr.base, pr.head) for pr in prs}
        else:
            from concurrent.futures import ThreadPoolExecutor

            _prs = list(prs)  # we want list for zipping with results
            with ThreadPoolExecutor(max_workers=jobs) as executor:
                logging.debug("Using a thread pool of size %d.", getattr(executor, "_max_workers", -1))
                results = list(executor.map(lambda pr: _get_merge_base(pr.base, pr.head), _prs))
            merge_bases_by_pr = {pr: mb for pr, mb in zip(_prs, results)}

    logging.info("Fetched merge bases for %d PRs in %.2f seconds.", len(prs), elapsed())
    for pr, mb in merge_bases_by_pr.items():
        if pr.base.sha != mb:
            logging.warning(
                "PR #%d: base branch '%s' has advanced since the PR was created/updated. Consider rebasing.",
                pr.number,
                pr.base.ref,
            )

    return merge_bases_by_pr


def _get_slices_by_pr(
    prs: frozenset[PR],
    merge_bases_by_pr: dict[PR, str],
    jobs: int | None = 1,
) -> tuple[dict[PR, frozenset[str]], dict[PR, frozenset[str]]]:
    logging.info("Fetching slices for %d PRs...", len(prs))
    # For each PR, get the list of files in the /slices directory in the base branch
    slices_in_head_by_pr: dict[PR, set[str]] = {}
    slices_in_base_by_pr: dict[PR, set[str]] = {}
    get_slices_base = lambda pr: _get_slices(pr.base.repo_owner, pr.base.repo_name, merge_bases_by_pr[pr])
    get_slices_head = lambda pr: _get_slices(pr.head.repo_owner, pr.head.repo_name, pr.head.ref)

    with catch_time() as elapsed:
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

    # freeze
    _slices_in_head_by_pr = {pr: frozenset(slices) for pr, slices in slices_in_head_by_pr.items()}
    _slices_in_base_by_pr = {pr: frozenset(slices) for pr, slices in slices_in_base_by_pr.items()}

    return _slices_in_head_by_pr, _slices_in_base_by_pr


def _get_packages_by_release(
    releases: list[UbuntuRelease],
    jobs: int | None = 1,
) -> dict[UbuntuRelease, set[str]]:
    logging.info("Fetching packages for %d releases...", len(releases))
    package_listings: dict[tuple[UbuntuRelease, str, str], set[str]] = {}

    _components = ("main", "restricted", "universe", "multiverse")
    _repos = ("", "security", "updates", "backports")
    _product = list(product(releases, _components, _repos))

    with catch_time() as elapsed:
        if jobs == 1:
            for release, component, repo in _product:
                package_listings[(release, component, repo)] = _get_package_content(release, component, repo)

        else:
            from concurrent.futures import ThreadPoolExecutor

            with ThreadPoolExecutor(max_workers=jobs) as executor:
                logging.debug("Using a thread pool of size %d.", getattr(executor, "_max_workers", -1))
                results = list(
                    executor.map(lambda args: _get_package_content(*args), _product)  # type: ignore
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


def _get_package_content(release: UbuntuRelease, component: str, repo: str) -> set[str]:
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
    logging.debug("Downloading package list from '%s'...", package_url)
    headers = {
        "Host": "archive.ubuntu.com",
        "User-Agent": f"forward-port-missing-script/{__version__}",
        "Accept-Encoding": "gzip",
        "Referer": f"https://archive.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64",
        "Priority": "u=0",
    }
    code, res = _geturl(package_url, headers=headers)

    if code != 200:
        logging.debug(
            "Failed to download package list from '%s'. HTTP status code: %d. Retrying with old-releases.",
            package_url,
            code,
        )
        # retry with old-releases if not found in archive
        package_url = f"https://old-releases.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64/Packages.gz"
        headers["Referer"] = f"https://old-releases.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64"
        headers["Host"] = "old-releases.ubuntu.com"
        code, res = _geturl(package_url, headers=headers)

    logging.debug("Downloaded package list from '%s'. HTTP status code: %d.", package_url, code)
    if code != 200:
        raise RuntimeError(f"Failed to download package list from '{package_url}'. HTTP status code: {code}")

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
    _geturl = memory.cache(_geturl)  # type: ignore
    # we don't really need to cache `get_package_content` that much, but
    # the gzip can be a bit slow
    _get_package_content = memory.cache(_get_package_content)  # type: ignore


def _group_prs_by_ubuntu_release(
    prs: frozenset[PR], ubuntu_releases: list[UbuntuRelease]
) -> dict[UbuntuRelease, frozenset[PR]]:
    _prs_by_ubuntu_release: dict[UbuntuRelease, set[PR]] = {ubuntu_release: set() for ubuntu_release in ubuntu_releases}
    _prs = list(sorted(prs))  # we want list for logging
    for pr in _prs:
        if pr.ubuntu_release not in _prs_by_ubuntu_release:
            logging.warning("PR #%d is into unsupported Ubuntu release %s. Skipping.", pr.number, pr.ubuntu_release)
            continue
        _prs_by_ubuntu_release[pr.ubuntu_release].add(pr)
    prs_by_ubuntu_release: dict[UbuntuRelease, frozenset[PR]] = {
        k: frozenset(v) for k, v in _prs_by_ubuntu_release.items()
    }

    # Make sure we have all the ubuntu_releases as keys, even if they have no PRs
    for ubuntu_release in ubuntu_releases:
        if ubuntu_release not in prs_by_ubuntu_release:
            prs_by_ubuntu_release[ubuntu_release] = frozenset()

    return prs_by_ubuntu_release


################################################################################


class Saver(Protocol):
    def __init__(
        self,
        prs: frozenset[PR],
        slices_in_head_by_pr: Mapping[PR, frozenset[str]],
        slices_in_base_by_pr: Mapping[PR, frozenset[str]],
        packages_by_release: Mapping[UbuntuRelease, set[str]],
    ) -> None: ...

    def save(self, output: Path, force: bool = False) -> None: ...


def _check_output_file(output: Path, force: bool) -> None:
    if output.exists() and not force:
        while True:
            answer = input(f"Output file '{output}' already exists. Overwrite? [y/N]: ").strip().lower()
            if answer in ("y", "yes"):
                break
            elif answer in ("n", "no", ""):
                logging.info("Not overwriting existing file '%s'. Exiting.", output)
                sys.exit(0)
            else:
                print("Please answer 'y' or 'n'.")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()


class PickleSaver:
    def __init__(
        self,
        prs: frozenset[PR],
        slices_in_head_by_pr: Mapping[PR, frozenset[str]],
        slices_in_base_by_pr: Mapping[PR, frozenset[str]],
        packages_by_release: Mapping[UbuntuRelease, set[str]],
        *,
        compress: bool = True,
        debug: bool = False,
    ) -> None:
        self.prs = prs
        self.slices_in_head_by_pr = slices_in_head_by_pr
        self.slices_in_base_by_pr = slices_in_base_by_pr
        self.packages_by_release = packages_by_release
        self.compress = compress
        self.debug = debug

    def save(self, output: Path, force: bool = False) -> None:
        _check_output_file(output, force)
        logging.info("Saving data to '%s'...", output)
        import pickle

        # Convert to primitive types for pickling
        data: dict[str, object] = {}
        data["prs"] = frozenset(pr.__getstate__() for pr in self.prs)
        data["slices_in_head_by_pr"] = {pr.__getstate__(): frozenset(v) for pr, v in self.slices_in_head_by_pr.items()}
        data["slices_in_base_by_pr"] = {pr.__getstate__(): frozenset(v) for pr, v in self.slices_in_base_by_pr.items()}
        data["packages_by_release"] = {k.__getstate__(): set(v) for k, v in self.packages_by_release.items()}

        with output.open("wb") as f:
            if self.compress:
                import zlib

                f.write(zlib.compress(pickle.dumps(data)))
            else:
                pickle.dump(data, f)

        logging.info("Saved data to '%s'.", output)
        file_size = output.stat().st_size
        logging.info("Output file size: %.2f MiB", file_size / (1024 * 1024))

        # DEBUG: load the file back and check it
        if self.debug:
            if self.compress:
                with output.open("rb") as f:
                    loaded_data = pickle.loads(zlib.decompress(f.read()))
            else:
                with output.open("rb") as f:
                    loaded_data = pickle.load(f)
            assert isinstance(loaded_data, dict), "Expected loaded data to be a dict."
            assert set(loaded_data.keys()) == set(data.keys()), "Loaded data keys do not match saved data keys."
            logging.debug("Successfully loaded data back from '%s'.", output)


if TYPE_CHECKING:
    _pickle_saver: Saver = PickleSaver.__new__(PickleSaver)


class SQLiteSaver:
    def __init__(
        self,
        prs: frozenset[PR],
        slices_in_head_by_pr: Mapping[PR, frozenset[str]],
        slices_in_base_by_pr: Mapping[PR, frozenset[str]],
        packages_by_release: Mapping[UbuntuRelease, set[str]],
    ) -> None:
        self.prs = prs
        self.slices_in_head_by_pr = slices_in_head_by_pr
        self.slices_in_base_by_pr = slices_in_base_by_pr
        self.packages_by_release = packages_by_release

    def save(self, output: Path, force: bool = False) -> None:
        raise NotImplementedError("SQLiteSaver.save is not implemented yet.")


if TYPE_CHECKING:
    _sqlite_saver: Saver = SQLiteSaver.__new__(SQLiteSaver)

## MAIN ########################################################################


def main(args: argparse.Namespace) -> None:
    ubuntu_releases = _currently_supported_ubuntu_releases()
    ubuntu_branches = _ubuntu_branches_in_chisel_releases()

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

    if _ADDITIONAL_VERSIONS_TO_SKIP:
        logging.info("Skipping additional versions: %s", ", ".join(str(r) for r in _ADDITIONAL_VERSIONS_TO_SKIP))

    ubuntu_releases = [r for r in ubuntu_releases if r not in _ADDITIONAL_VERSIONS_TO_SKIP]

    logging.info(
        "Considering %d supported Ubuntu releases with branches in chisel-releases: %s",
        len(ubuntu_releases),
        ", ".join(str(r) for r in ubuntu_releases),
    )

    prs = _get_all_prs(CHISEL_RELEASES_URL)
    logging.info("Found %d open PRs in %s", len(prs), CHISEL_RELEASES_URL)

    merge_bases_by_pr = _get_merge_bases_by_pr(prs, args.jobs)
    slices_in_head_by_pr, slices_in_base_by_pr = _get_slices_by_pr(prs, merge_bases_by_pr, args.jobs)
    packages_by_release = _get_packages_by_release(ubuntu_releases, args.jobs)

    # # Log some info
    if logging.getLogger().isEnabledFor(logging.INFO):
        prs_by_ubuntu_release = _group_prs_by_ubuntu_release(prs, ubuntu_releases)
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

    # Save to file
    saver: Saver
    if args.format == "sqlite":
        saver = SQLiteSaver(
            prs,
            slices_in_head_by_pr,
            slices_in_base_by_pr,
            packages_by_release,
        )

    elif args.format in ("pickle", "pickle.gz"):
        saver = PickleSaver(
            prs,
            slices_in_head_by_pr,
            slices_in_base_by_pr,
            packages_by_release,
            compress=args.format == "pickle.gz",
        )
    else:
        raise ValueError(f"Unknown format: {args.format}")

    saver.save(args.output, force=args.force)


## BOILERPLATE #################################################################


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check labels on PRs and forward-port if needed.",
        epilog="Example: ./forward-port-missing.py --log-level debug",
    )
    parser.add_argument(
        "output",
        type=str,
        help=(
            "Output file to write the results to. The extension determines the format: .sqlite or .pickle or .pickle.gz"
        ),
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="Force overwrite of the output file if it exists.",
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

    args = parser.parse_args()
    if args.jobs == 0 or args.jobs < -1:
        parser.error("--jobs must be a positive integer or -1 for unlimited.")
    args.jobs = None if args.jobs == -1 else args.jobs  # None = as many as possible

    args.output = Path(args.output).absolute()
    suffix = "".join(args.output.suffixes)
    if suffix not in (".sqlite", ".pickle", ".pickle.gz"):
        parser.error("Output file must have .sqlite, .pickle, or .pickle.gz extension.")
    args.format = suffix.lstrip(".")

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
    _check_github_token()

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
